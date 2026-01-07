//
//  ModelSecurityValidator.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//

import Foundation
import CryptoKit

/// Validates model files for security before loading
/// CRITICAL SECURITY: Only allows SafeTensors format, blocks pickle/arbitrary code execution
///
/// **Security Policy:**
/// - ✅ SafeTensors (.safetensors) - SAFE: Pure tensor data, no code execution
/// - ❌ Pickle (.pkl, .bin with pickle) - UNSAFE: Can execute arbitrary Python code
/// - ❌ PyTorch (.pt, .pth) - UNSAFE: Uses pickle internally
/// - ❌ Arbitrary Python scripts - UNSAFE: Code execution risk
///
/// **Author:** Jordan Koch
actor ModelSecurityValidator {
    static let shared = ModelSecurityValidator()

    /// Trusted model sources (official repositories only)
    private let trustedSources = [
        "huggingface.co",
        "hf.co",
        "github.com/apple/ml-explore",  // Apple's MLX models
        "github.com/lucasnewman/f5-tts-mlx",
        "github.com/Blaizzy/mlx-audio"
    ]

    /// Safe file extensions
    private let safeExtensions = [
        "safetensors",  // SafeTensors format - pure tensor data
        "json",         // Configuration files
        "txt",          // Text data
        "wav",          // Audio files
        "mp3"           // Audio files
    ]

    /// Dangerous file extensions (BLOCKED)
    private let dangerousExtensions = [
        "pkl",    // Pickle - can execute code
        "pickle", // Pickle - can execute code
        "bin",    // Binary (often pickle)
        "pt",     // PyTorch - uses pickle
        "pth",    // PyTorch - uses pickle
        "py",     // Python script - code execution
        "pyc"     // Compiled Python - code execution
    ]

    private init() {}

    // MARK: - Validation

    /// Validates a model file is safe to load
    /// - Parameters:
    ///   - path: Path to model file
    ///   - sourceURL: Optional URL where model was downloaded from
    /// - Returns: ValidationResult with security assessment
    func validateModel(path: String, sourceURL: String? = nil) async -> ValidationResult {
        var issues: [SecurityIssue] = []
        var warnings: [String] = []

        // 1. Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            issues.append(.fileNotFound(path))
            return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
        }

        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        // 2. Check file extension
        if dangerousExtensions.contains(ext) {
            issues.append(.dangerousFormat(ext, reason: "Format can execute arbitrary code"))
            await logSecurityEvent("❌ BLOCKED: Dangerous format '\(ext)' at \(path)", level: .critical)
            return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
        }

        if !safeExtensions.contains(ext) {
            warnings.append("Unknown file extension '\(ext)' - proceeding with caution")
            await logSecurityEvent("⚠️ Unknown file extension: \(ext)", level: .warning)
        }

        // 3. Verify SafeTensors header if applicable
        if ext == "safetensors" {
            let isValid = await validateSafeTensorsFile(path: path)
            if !isValid {
                issues.append(.corruptedFile("Invalid SafeTensors header"))
                return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
            }
        }

        // 4. Check source URL is trusted
        if let sourceURL = sourceURL {
            if !isTrustedSource(sourceURL) {
                warnings.append("Model from untrusted source: \(sourceURL)")
                await logSecurityEvent("⚠️ Untrusted source: \(sourceURL)", level: .warning)
            }
        }

        // 5. Check for suspicious content (binary scan)
        if ext == "safetensors" || ext == "json" {
            if await containsSuspiciousPatterns(path: path) {
                issues.append(.suspiciousContent("File contains suspicious patterns"))
                return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
            }
        }

        // 6. Verify file size is reasonable
        if let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 {
            if size > 50_000_000_000 {  // 50GB
                warnings.append("Unusually large model file: \(formatBytes(size))")
            }
        }

        await logSecurityEvent("✅ SAFE: Model validated: \(path)", level: .info)

        return ValidationResult(
            isSafe: true,
            issues: issues,
            warnings: warnings,
            modelPath: path,
            format: ext
        )
    }

    /// Validates SafeTensors file header
    private func validateSafeTensorsFile(path: String) async -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return false
        }

        defer { try? fileHandle.close() }

        // Read first 8 bytes (header size)
        guard let headerSizeData = try? fileHandle.read(upToCount: 8),
              headerSizeData.count == 8 else {
            return false
        }

        // SafeTensors format starts with 8-byte little-endian integer (header size)
        let headerSize = headerSizeData.withUnsafeBytes { $0.load(as: UInt64.self) }

        // Sanity check: header should be < 10MB
        guard headerSize < 10_000_000 else {
            await logSecurityEvent("❌ Invalid SafeTensors: header size \(headerSize) too large", level: .error)
            return false
        }

        return true
    }

    /// Checks if file contains suspicious patterns
    private func containsSuspiciousPatterns(path: String) async -> Bool {
        // Check for pickle opcodes or Python bytecode in first 1KB
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 1024) else {
            return false
        }

        defer { try? fileHandle.close() }

        // Pickle magic bytes
        let pickleOpcodes: [UInt8] = [
            0x80, 0x02,  // Pickle protocol 2
            0x80, 0x03,  // Pickle protocol 3
            0x80, 0x04,  // Pickle protocol 4
            0x80, 0x05   // Pickle protocol 5
        ]

        // Check for pickle signatures
        for i in 0..<(data.count - 1) {
            if data[i] == 0x80 && (2...5).contains(data[i + 1]) {
                await logSecurityEvent("❌ PICKLE DETECTED in file: \(path)", level: .critical)
                return true
            }
        }

        return false
    }

    /// Checks if source URL is from trusted repository
    private func isTrustedSource(_ urlString: String) -> Bool {
        let lowerURL = urlString.lowercased()
        return trustedSources.contains { lowerURL.contains($0) }
    }

    // MARK: - Python Script Validation

    /// Validates Python script is safe to execute
    /// IMPORTANT: Should be used sparingly - prefer no Python execution
    func validatePythonScript(path: String) async -> ValidationResult {
        var issues: [SecurityIssue] = []
        var warnings: [String] = []

        guard let script = try? String(contentsOfFile: path) else {
            issues.append(.fileNotFound(path))
            return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
        }

        // Check for dangerous operations
        let dangerousPatterns = [
            "exec(",
            "eval(",
            "compile(",
            "__import__",
            "pickle.load",
            "torch.load",
            "subprocess",
            "os.system",
            "os.popen",
            "rm -rf",
            "wget",
            "curl"
        ]

        for pattern in dangerousPatterns {
            if script.contains(pattern) {
                issues.append(.dangerousCode("Script contains dangerous operation: \(pattern)"))
                await logSecurityEvent("❌ BLOCKED: Python script contains '\(pattern)'", level: .critical)
            }
        }

        if !issues.isEmpty {
            return ValidationResult(isSafe: false, issues: issues, warnings: warnings)
        }

        // Warn about imports
        if script.contains("import ") {
            warnings.append("Script imports external modules - verify they are safe")
        }

        return ValidationResult(isSafe: true, issues: issues, warnings: warnings)
    }

    // MARK: - Logging

    private func logSecurityEvent(_ message: String, level: SecurityLogLevel) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [SECURITY] [\(level.rawValue)] \(message)"

        // Log to console
        print(logMessage)

        // Log to file
        let logPath = NSHomeDirectory() + "/Library/Logs/MLXCode/security.log"
        let logDir = (logPath as NSString).deletingLastPathComponent

        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        if let data = (logMessage + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Models

struct ValidationResult {
    let isSafe: Bool
    let issues: [SecurityIssue]
    let warnings: [String]
    let modelPath: String?
    let format: String?

    init(isSafe: Bool, issues: [SecurityIssue], warnings: [String], modelPath: String? = nil, format: String? = nil) {
        self.isSafe = isSafe
        self.issues = issues
        self.warnings = warnings
        self.modelPath = modelPath
        self.format = format
    }

    var summary: String {
        if isSafe {
            var msg = "✅ Model is SAFE to load"
            if !warnings.isEmpty {
                msg += "\n⚠️ Warnings: \(warnings.joined(separator: "; "))"
            }
            return msg
        } else {
            return "❌ Model is UNSAFE: \(issues.map { $0.description }.joined(separator: "; "))"
        }
    }
}

enum SecurityIssue {
    case fileNotFound(String)
    case dangerousFormat(String, reason: String)
    case corruptedFile(String)
    case suspiciousContent(String)
    case dangerousCode(String)
    case untrustedSource(String)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .dangerousFormat(let format, let reason):
            return "Dangerous format '\(format)': \(reason)"
        case .corruptedFile(let reason):
            return "Corrupted file: \(reason)"
        case .suspiciousContent(let reason):
            return "Suspicious content: \(reason)"
        case .dangerousCode(let pattern):
            return "Dangerous code pattern: \(pattern)"
        case .untrustedSource(let url):
            return "Untrusted source: \(url)"
        }
    }
}

enum SecurityLogLevel: String {
    case critical = "CRITICAL"
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
}
