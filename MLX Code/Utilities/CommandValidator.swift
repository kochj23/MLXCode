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

        // 2. FIRST: Check for dangerous characters via SecurityUtils (short-circuits on ;|&$`<> etc.)
        // This MUST run before pattern matching since it catches shell metacharacters that enable injection
        guard SecurityUtils.validateCommand(command) else {
            logSecurityEvent("BLOCKED command with dangerous characters", level: .critical)
            throw SecurityError.dangerousCharacters("Command contains shell metacharacters")
        }

        // 3. SECOND: Check for dangerous patterns using proper regex matching
        // Each tuple: (regex pattern, human-readable description)
        let dangerousPatterns: [(pattern: String, description: String)] = [
            (#"\brm\s+-rf\b"#, "rm -rf"),
            (#":\(\)\s*\{.*\}.*;"#, "fork bomb"),
            (#"\bchmod\s+777\b"#, "chmod 777"),
            (#"\bsudo\b"#, "sudo"),
            (#"\bsu\b"#, "su"),
            (#">\s*/dev/"#, "> /dev/"),
            (#"\bcurl\b.*\|\s*\bsh\b"#, "curl pipe to sh"),
            (#"\bwget\b.*\|\s*\bsh\b"#, "wget pipe to sh"),
            (#"\beval\b"#, "eval"),
            (#"\bexec\b"#, "exec")
        ]

        let lowerCommand = command.lowercased()
        for (regexPattern, description) in dangerousPatterns {
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]),
               regex.firstMatch(in: lowerCommand, range: NSRange(lowerCommand.startIndex..., in: lowerCommand)) != nil {
                logSecurityEvent("BLOCKED dangerous pattern: \(description) in command", level: .critical)
                throw SecurityError.dangerousPattern(description)
            }
        }

        // 4. Log for audit trail
        logSecurityEvent("Validated bash command: \(command.prefix(100))", level: .info)

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
            logSecurityEvent("BLOCKED non-whitelisted command: \(firstWord)", level: .critical)
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

        // 2. Block dangerous imports using regex (skip comment lines)
        // Each tuple: (regex pattern, human-readable description)
        let dangerousImportPatterns: [(pattern: String, description: String)] = [
            (#"(?:^|\n)\s*import\s+os\b"#, "import os"),
            (#"(?:^|\n)\s*import\s+subprocess\b"#, "import subprocess"),
            (#"(?:^|\n)\s*import\s+sys\b"#, "import sys"),
            (#"(?:^|\n)\s*import\s+pickle\b"#, "import pickle"),
            (#"(?:^|\n)\s*import\s+_pickle\b"#, "import _pickle"),
            (#"(?:^|\n)\s*import\s+marshal\b"#, "import marshal"),
            (#"(?:^|\n)\s*import\s+shelve\b"#, "import shelve"),
            (#"(?:^|\n)\s*from\s+os\s+import\b"#, "from os import"),
            (#"(?:^|\n)\s*from\s+subprocess\s+import\b"#, "from subprocess import"),
            (#"(?:^|\n)\s*from\s+sys\s+import\b"#, "from sys import"),
            (#"\b__import__\b"#, "__import__")
        ]

        // Filter out comment lines before checking
        let codeLines = code.components(separatedBy: "\n")
        let uncommentedCode = codeLines
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")

        for (regexPattern, description) in dangerousImportPatterns {
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
               regex.firstMatch(in: uncommentedCode, range: NSRange(uncommentedCode.startIndex..., in: uncommentedCode)) != nil {
                logSecurityEvent("BLOCKED dangerous Python import: \(description)", level: .critical)
                throw SecurityError.dangerousImport(description)
            }
        }

        // 3. Block dangerous functions using regex (consistent with import validation above)
        // Each tuple: (regex pattern, human-readable description)
        let dangerousFunctionPatterns: [(pattern: String, description: String)] = [
            (#"\bexec\s*\("#, "exec()"),
            (#"\beval\s*\("#, "eval()"),
            (#"\bcompile\s*\("#, "compile()"),
            (#"\bpickle\.loads?\s*\("#, "pickle.load(s)"),
            (#"\btorch\.load\s*\("#, "torch.load()"),
            (#"\bopen\s*\("#, "open()"),
            (#"\binput\s*\("#, "input()"),
            (#"\braw_input\s*\("#, "raw_input()")
        ]

        for (regexPattern, description) in dangerousFunctionPatterns {
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
               regex.firstMatch(in: uncommentedCode, range: NSRange(uncommentedCode.startIndex..., in: uncommentedCode)) != nil {
                logSecurityEvent("BLOCKED dangerous Python function: \(description)", level: .critical)
                throw SecurityError.dangerousFunction(description)
            }
        }

        // 4. Block system manipulation using regex for consistency
        let systemPatterns: [(pattern: String, description: String)] = [
            (#"\bos\."#, "os module access"),
            (#"\bsys\."#, "sys module access"),
            (#"\bsubprocess\."#, "subprocess module access")
        ]

        for (regexPattern, description) in systemPatterns {
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
               regex.firstMatch(in: uncommentedCode, range: NSRange(uncommentedCode.startIndex..., in: uncommentedCode)) != nil {
                logSecurityEvent("BLOCKED system manipulation: \(description)", level: .critical)
                throw SecurityError.systemManipulation
            }
        }

        // 5. Log for audit
        logSecurityEvent("Validated Python code: \(code.prefix(100))", level: .info)

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

        // 2b. Verify file is readable (handles permission errors explicitly)
        guard FileManager.default.isReadableFile(atPath: expandedPath) else {
            logSecurityEvent("Permission denied reading script: \(expandedPath)", level: .error)
            throw SecurityError.invalidPath("Permission denied: cannot read \(expandedPath)")
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
        logSecurityEvent("Validated Python script: \(expandedPath)", level: .info)

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
                logSecurityEvent("BLOCKED private IP access: \(host)", level: .critical)
                throw SecurityError.privateIPBlocked(host)
            }
        }

        // 3. Block localhost variations
        let localhostPatterns = ["localhost", "local", "127.0.0.1", "0.0.0.0", "::1"]
        if localhostPatterns.contains(host.lowercased()) {
            logSecurityEvent("BLOCKED localhost access: \(host)", level: .critical)
            throw SecurityError.localhostBlocked
        }

        // 4. Check for suspicious ports
        if let port = url.port {
            // Block common internal service ports
            let suspiciousPorts = [22, 23, 25, 3306, 5432, 6379, 27017, 9200]
            if suspiciousPorts.contains(port) {
                logSecurityEvent("Suspicious port \(port)", level: .warning)
            }
        }

        logSecurityEvent("Validated URL: \(urlString)", level: .info)
        return url
    }

    // MARK: - Logging

    /// Serial queue for async file I/O to avoid blocking the calling thread
    private static let logQueue = DispatchQueue(label: "com.mlxcode.commandvalidator.log")

    private static func logSecurityEvent(_ message: String, level: SecurityLogLevel) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [CommandValidator] [\(level.rawValue)] \(message)"

        // Delegate to SecureLogger for structured logging (non-blocking fire-and-forget)
        Task {
            switch level {
            case .critical:
                await SecureLogger.shared.critical(logMessage, category: "CommandValidator")
            case .error:
                await SecureLogger.shared.error(logMessage, category: "CommandValidator")
            case .warning:
                await SecureLogger.shared.warning(logMessage, category: "CommandValidator")
            case .info:
                await SecureLogger.shared.info(logMessage, category: "CommandValidator")
            }
        }

        // Also write to security log file asynchronously (avoids blocking the caller)
        let logPath = NSHomeDirectory() + "/Library/Logs/MLXCode/security.log"
        if let data = (logMessage + "\n").data(using: .utf8) {
            logQueue.async {
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
