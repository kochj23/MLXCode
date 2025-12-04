//
//  SecureLogger.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import os.log

/// Secure logging utility that sanitizes sensitive information before logging
/// Prevents accidental exposure of API keys, passwords, tokens, and PII
actor SecureLogger {
    /// Shared singleton instance
    static let shared = SecureLogger()

    /// OSLog subsystem
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.mlxcode"

    /// Log levels
    enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .critical:
                return .fault
            }
        }
    }

    /// Current minimum log level
    private var minimumLogLevel: LogLevel = .debug

    /// Patterns to redact from logs
    private let sensitivePatterns: [(pattern: String, replacement: String)] = [
        // API Keys
        ("sk-[a-zA-Z0-9]{32,}", "[API_KEY_REDACTED]"),
        ("pk-[a-zA-Z0-9]{32,}", "[PUBLIC_KEY_REDACTED]"),

        // Generic tokens and secrets
        ("['\"]?token['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "token=[TOKEN_REDACTED]"),
        ("['\"]?secret['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "secret=[SECRET_REDACTED]"),
        ("['\"]?api_key['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "api_key=[KEY_REDACTED]"),

        // Password patterns
        ("['\"]?password['\"]?\\s*[:=]\\s*['\"]?[^'\"\\s]{6,}", "password=[PASSWORD_REDACTED]"),
        ("['\"]?passwd['\"]?\\s*[:=]\\s*['\"]?[^'\"\\s]{6,}", "passwd=[PASSWORD_REDACTED]"),

        // Email addresses (PII)
        ("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "[EMAIL_REDACTED]"),

        // Phone numbers (PII)
        ("\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b", "[PHONE_REDACTED]"),

        // Credit card patterns
        ("\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b", "[CARD_REDACTED]"),

        // JWT tokens
        ("eyJ[a-zA-Z0-9_-]*\\.eyJ[a-zA-Z0-9_-]*\\.[a-zA-Z0-9_-]*", "[JWT_REDACTED]"),

        // Private keys
        ("-----BEGIN\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----[\\s\\S]*?-----END\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----", "[PRIVATE_KEY_REDACTED]")
    ]

    /// Maximum log message length before truncation
    private let maxLogLength = 1000

    private init() {}

    // MARK: - Public Logging Methods

    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Log category (default: "General")
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func debug(
        _ message: String,
        category: String = "General",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Logs an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Log category (default: "General")
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func info(
        _ message: String,
        category: String = "General",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Logs a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Log category (default: "General")
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func warning(
        _ message: String,
        category: String = "General",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Logs an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Log category (default: "General")
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func error(
        _ message: String,
        category: String = "General",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Logs a critical message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Log category (default: "General")
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func critical(
        _ message: String,
        category: String = "General",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Configuration

    /// Sets the minimum log level
    /// - Parameter level: The minimum level to log
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }

    // MARK: - Private Methods

    /// Main logging function with sanitization
    private func log(
        _ message: String,
        level: LogLevel,
        category: String,
        file: String,
        function: String,
        line: Int
    ) {
        // Check if we should log this level
        guard level >= minimumLogLevel else {
            return
        }

        // Sanitize the message
        let sanitized = sanitize(message)

        // Create logger for category
        let logger = Logger(subsystem: subsystem, category: category)

        // Extract file name from path
        let fileName = (file as NSString).lastPathComponent

        // Format the log message
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(sanitized)"

        // Log using OSLog
        logger.log(level: level.osLogType, "\(formattedMessage)")
    }

    /// Sanitizes a message by redacting sensitive information
    /// - Parameter message: The original message
    /// - Returns: Sanitized message with sensitive data redacted
    private func sanitize(_ message: String) -> String {
        var sanitized = message

        // Apply all sensitive patterns
        for (pattern, replacement) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(sanitized.startIndex..., in: sanitized)
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }

        // Truncate if too long
        if sanitized.count > maxLogLength {
            sanitized = String(sanitized.prefix(maxLogLength)) + "... [TRUNCATED]"
        }

        return sanitized
    }
}

// MARK: - Convenience Extensions

extension SecureLogger {
    /// Logs an error with additional context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context
    ///   - category: Log category
    ///   - file: Source file
    ///   - function: Source function
    ///   - line: Source line
    func logError(
        _ error: Error,
        context: String? = nil,
        category: String = "Error",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "Error: \(type(of: error))"

        if let context = context {
            message += " - Context: \(context)"
        }

        // Add localized description (sanitized)
        message += " - \(error.localizedDescription)"

        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Global Convenience Functions

/// Global debug log function
func logDebug(
    _ message: String,
    category: String = "General",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await SecureLogger.shared.debug(message, category: category, file: file, function: function, line: line)
    }
}

/// Global info log function
func logInfo(
    _ message: String,
    category: String = "General",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await SecureLogger.shared.info(message, category: category, file: file, function: function, line: line)
    }
}

/// Global warning log function
func logWarning(
    _ message: String,
    category: String = "General",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await SecureLogger.shared.warning(message, category: category, file: file, function: function, line: line)
    }
}

/// Global error log function
func logError(
    _ message: String,
    category: String = "General",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await SecureLogger.shared.error(message, category: category, file: file, function: function, line: line)
    }
}

/// Global critical log function
func logCritical(
    _ message: String,
    category: String = "General",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await SecureLogger.shared.critical(message, category: category, file: file, function: function, line: line)
    }
}
