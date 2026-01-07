//
//  CommandValidator.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//

import Foundation

/// CRITICAL SECURITY: Validates all commands before execution
/// Prevents command injection, arbitrary code execution, and privilege escalation
///
/// **Security Policy:**
/// - All bash/shell commands MUST be validated
/// - All Python commands MUST be validated
/// - Dangerous patterns are blocked
/// - All executions are logged for audit
///
/// **Author:** Jordan Koch
enum CommandValidator {

    // MARK: - Bash Command Validation

    /// Validates bash command is safe to execute
    /// - Parameter command: Command to validate
    /// - Returns: Validated command
    /// - Throws: SecurityError if command is unsafe
    static func validateBashCommand(_ command: String) throws -> String {
        // 1. Length validation
        guard command.count > 0 && command.count < 10_000 else {
            throw SecurityError.commandLength(command.count)
        }

        // 2. Check for dangerous characters
        guard SecurityUtils.validateCommand(command) else {
            throw SecurityError.dangerousCharacters("Command contains shell metacharacters")
        }

        // 3. Check for dangerous patterns
        let dangerousPatterns = [
            "rm -rf /",
            ":(){ :|:& };:",  // Fork bomb
            "chmod 777",
            "sudo",
            "su ",
            "> /dev/",
            "curl.*|.*sh",
            "wget.*|.*sh",
            "eval",
            "exec"
        ]

        let lowerCommand = command.lowercased()
        for pattern in dangerousPatterns {
            if lowerCommand.contains(pattern.lowercased()) {
                logSecurityEvent("🔴 BLOCKED dangerous pattern: \(pattern) in command", level: .critical)
                throw SecurityError.dangerousPattern(pattern)
            }
        }

        // 4. Log for audit trail
        logSecurityEvent("✅ Validated bash command: \(command.prefix(100))", level: .info)

        return command
    }

    /// Validates bash command with whitelist (most restrictive)
    /// - Parameters:
    ///   - command: Command to validate
    ///   - allowedCommands: Whitelist of allowed command names
    /// - Returns: Validated command
    /// - Throws: SecurityError if command not in whitelist
    static func validateBashCommandWhitelist(_ command: String, allowedCommands: [String]) throws -> String {
        // Extract first word (command name)
        let components = command.components(separatedBy: .whitespaces)
        guard let firstWord = components.first, !firstWord.isEmpty else {
            throw SecurityError.emptyCommand
        }

        // Check whitelist
        guard allowedCommands.contains(firstWord) else {
            logSecurityEvent("🔴 BLOCKED non-whitelisted command: \(firstWord)", level: .critical)
            throw SecurityError.commandNotWhitelisted(firstWord)
        }

        // Still validate for injection
        return try validateBashCommand(command)
    }

    // MARK: - Python Command Validation

    /// Validates Python code is safe to execute
    /// - Parameter code: Python code to validate
    /// - Returns: Validated code
    /// - Throws: SecurityError if code is unsafe
    static func validatePythonCommand(_ code: String) throws -> String {
        // 1. Length validation
        guard code.count > 0 && code.count < 50_000 else {
            throw SecurityError.codeLength(code.count)
        }

        // 2. Block dangerous imports
        let dangerousImports = [
            "import os",
            "import subprocess",
            "import sys",
            "import pickle",
            "import _pickle",
            "import marshal",
            "import shelve",
            "from os import",
            "from subprocess import",
            "from sys import",
            "__import__"
        ]

        for dangerous in dangerousImports {
            if code.contains(dangerous) {
                logSecurityEvent("🔴 BLOCKED dangerous Python import: \(dangerous)", level: .critical)
                throw SecurityError.dangerousImport(dangerous)
            }
        }

        // 3. Block dangerous functions
        let dangerousFunctions = [
            "exec(",
            "eval(",
            "compile(",
            "pickle.load(",
            "pickle.loads(",
            "torch.load(",
            "open(",  // File access
            "input(",  // User input
            "raw_input("
        ]

        for dangerous in dangerousFunctions {
            if code.contains(dangerous) {
                logSecurityEvent("🔴 BLOCKED dangerous Python function: \(dangerous)", level: .critical)
                throw SecurityError.dangerousFunction(dangerous)
            }
        }

        // 4. Block system manipulation
        if code.contains("os.") || code.contains("sys.") || code.contains("subprocess.") {
            logSecurityEvent("🔴 BLOCKED system manipulation in Python code", level: .critical)
            throw SecurityError.systemManipulation
        }

        // 5. Log for audit
        logSecurityEvent("✅ Validated Python code: \(code.prefix(100))", level: .info)

        return code
    }

    // MARK: - Script Path Validation

    /// Validates Python script file is safe to execute
    /// - Parameter scriptPath: Path to Python script
    /// - Returns: Validated path
    /// - Throws: SecurityError if script is unsafe
    static func validatePythonScript(at scriptPath: String) async throws -> String {
        // 1. Validate path
        guard SecurityUtils.validateFilePath(scriptPath) else {
            throw SecurityError.invalidPath(scriptPath)
        }

        let expandedPath = (scriptPath as NSString).expandingTildeInPath

        // 2. Verify file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw SecurityError.fileNotFound(expandedPath)
        }

        // 3. Verify it's a Python file
        guard expandedPath.hasSuffix(".py") else {
            throw SecurityError.invalidFileType("Only .py files allowed")
        }

        // 4. Use ModelSecurityValidator to check script content
        let validation = await ModelSecurityValidator.shared.validatePythonScript(path: expandedPath)

        guard validation.isSafe else {
            throw SecurityError.unsafeScript(validation.issues.map { $0.description }.joined(separator: "; "))
        }

        // 5. Log validation
        logSecurityEvent("✅ Validated Python script: \(expandedPath)", level: .info)

        return expandedPath
    }

    // MARK: - URL Validation (SSRF Prevention)

    /// Validates URL is safe (prevents SSRF attacks)
    /// - Parameter urlString: URL to validate
    /// - Returns: Validated URL
    /// - Throws: SecurityError if URL is unsafe
    static func validateSafeURL(_ urlString: String) throws -> URL {
        // 1. Basic URL validation
        guard SecurityUtils.validateURL(urlString) else {
            throw SecurityError.invalidURL(urlString)
        }

        guard let url = URL(string: urlString), let host = url.host else {
            throw SecurityError.invalidURL("No host in URL")
        }

        // 2. Block private IP ranges (SSRF prevention)
        let privateIPPatterns = [
            "^10\\.",
            "^192\\.168\\.",
            "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",
            "^127\\.",
            "^169\\.254\\.",
            "^::1$",
            "^fe80:",
            "^fc00:",
            "^fd00:"
        ]

        for pattern in privateIPPatterns {
            if host.range(of: pattern, options: .regularExpression) != nil {
                logSecurityEvent("🔴 BLOCKED private IP access: \(host)", level: .critical)
                throw SecurityError.privateIPBlocked(host)
            }
        }

        // 3. Block localhost variations
        let localhostPatterns = ["localhost", "local", "127.0.0.1", "0.0.0.0", "::1"]
        if localhostPatterns.contains(host.lowercased()) {
            logSecurityEvent("🔴 BLOCKED localhost access: \(host)", level: .critical)
            throw SecurityError.localhostBlocked
        }

        // 4. Check for suspicious ports
        if let port = url.port {
            // Block common internal service ports
            let suspiciousPorts = [22, 23, 25, 3306, 5432, 6379, 27017, 9200]
            if suspiciousPorts.contains(port) {
                logSecurityEvent("⚠️ WARNING: Suspicious port \(port)", level: .warning)
            }
        }

        logSecurityEvent("✅ Validated URL: \(urlString)", level: .info)
        return url
    }

    // MARK: - Logging

    private static func logSecurityEvent(_ message: String, level: SecurityLogLevel) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [CommandValidator] [\(level.rawValue)] \(message)"

        print(logMessage)

        // Also log to security log file
        let logPath = NSHomeDirectory() + "/Library/Logs/MLXCode/security.log"
        if let data = (logMessage + "\n").data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            } else {
                // Create file if doesn't exist
                let logDir = (logPath as NSString).deletingLastPathComponent
                try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
}

// MARK: - Errors

enum SecurityError: LocalizedError {
    case commandLength(Int)
    case codeLength(Int)
    case dangerousCharacters(String)
    case dangerousPattern(String)
    case dangerousImport(String)
    case dangerousFunction(String)
    case systemManipulation
    case commandNotWhitelisted(String)
    case emptyCommand
    case invalidPath(String)
    case fileNotFound(String)
    case invalidFileType(String)
    case unsafeScript(String)
    case invalidURL(String)
    case privateIPBlocked(String)
    case localhostBlocked

    var errorDescription: String? {
        switch self {
        case .commandLength(let len):
            return "Command too long: \(len) characters (max: 10,000)"
        case .codeLength(let len):
            return "Code too long: \(len) characters (max: 50,000)"
        case .dangerousCharacters(let msg):
            return "Dangerous characters detected: \(msg)"
        case .dangerousPattern(let pattern):
            return "Dangerous pattern detected: \(pattern)"
        case .dangerousImport(let imp):
            return "Dangerous Python import blocked: \(imp)"
        case .dangerousFunction(let fn):
            return "Dangerous function blocked: \(fn)"
        case .systemManipulation:
            return "System manipulation attempt blocked"
        case .commandNotWhitelisted(let cmd):
            return "Command not in whitelist: \(cmd)"
        case .emptyCommand:
            return "Empty command not allowed"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidFileType(let msg):
            return "Invalid file type: \(msg)"
        case .unsafeScript(let msg):
            return "Unsafe Python script: \(msg)"
        case .invalidURL(let msg):
            return "Invalid URL: \(msg)"
        case .privateIPBlocked(let ip):
            return "Private IP address blocked (SSRF prevention): \(ip)"
        case .localhostBlocked:
            return "Localhost access blocked (SSRF prevention)"
        }
    }
}
