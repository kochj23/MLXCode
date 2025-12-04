//
//  SecurityUtils.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Utility class for input validation and sanitization
/// Implements secure coding best practices to prevent injection attacks
enum SecurityUtils {

    // MARK: - Input Validation

    /// Validates a file path to prevent directory traversal attacks
    /// - Parameter path: The file path to validate
    /// - Returns: True if the path is safe
    static func validateFilePath(_ path: String) -> Bool {
        // Check for empty path
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Expand tilde and resolve symlinks
        let expandedPath = (path as NSString).expandingTildeInPath
        let resolvedPath = (expandedPath as NSString).resolvingSymlinksInPath

        // Check for directory traversal patterns
        let dangerousPatterns = [
            "../",
            "..\\",
            "%2e%2e/",
            "%2e%2e\\",
            "~/"
        ]

        let lowercasedPath = resolvedPath.lowercased()
        for pattern in dangerousPatterns {
            if lowercasedPath.contains(pattern.lowercased()) {
                return false
            }
        }

        // Check path length (prevent buffer overflow)
        guard resolvedPath.utf8.count < 4096 else {
            return false
        }

        return true
    }

    /// Validates a command string to prevent command injection
    /// - Parameter command: The command to validate
    /// - Returns: True if the command appears safe
    static func validateCommand(_ command: String) -> Bool {
        // Check for empty command
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Check for command injection characters
        let dangerousChars: Set<Character> = [";", "|", "&", "$", "`", "(", ")", "<", ">", "\n", "\r"]

        for char in command {
            if dangerousChars.contains(char) {
                return false
            }
        }

        // Check for command substitution
        if command.contains("$(") || command.contains("${") {
            return false
        }

        return true
    }

    /// Validates an email address
    /// - Parameter email: The email to validate
    /// - Returns: True if the email format is valid
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Validates a URL
    /// - Parameter urlString: The URL string to validate
    /// - Returns: True if the URL is valid and uses safe protocols
    static func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        // Only allow safe protocols
        let safeProtocols = ["http", "https", "file"]
        guard let scheme = url.scheme?.lowercased(),
              safeProtocols.contains(scheme) else {
            return false
        }

        return true
    }

    /// Validates a port number
    /// - Parameter port: The port number to validate
    /// - Returns: True if the port is in valid range
    static func validatePort(_ port: Int) -> Bool {
        return port >= 1 && port <= 65535
    }

    /// Validates a string length
    /// - Parameters:
    ///   - string: The string to validate
    ///   - minLength: Minimum allowed length
    ///   - maxLength: Maximum allowed length
    /// - Returns: True if the string length is within bounds
    static func validateLength(_ string: String, min minLength: Int = 0, max maxLength: Int) -> Bool {
        let length = string.count
        return length >= minLength && length <= maxLength
    }

    // MARK: - Input Sanitization

    /// Sanitizes a string for safe file path usage
    /// - Parameter path: The path to sanitize
    /// - Returns: Sanitized path string
    static func sanitizeFilePath(_ path: String) -> String {
        var sanitized = path

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        // Remove control characters
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined()

        // Normalize path separators
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "/")

        // Remove multiple consecutive slashes
        while sanitized.contains("//") {
            sanitized = sanitized.replacingOccurrences(of: "//", with: "/")
        }

        // Remove leading/trailing whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
    }

    /// Sanitizes a string for safe SQL usage (always prefer parameterized queries)
    /// - Parameter string: The string to sanitize
    /// - Returns: Sanitized string
    static func sanitizeSQL(_ string: String) -> String {
        // Escape single quotes
        var sanitized = string.replacingOccurrences(of: "'", with: "''")

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        return sanitized
    }

    /// Sanitizes a string for safe HTML output (prevent XSS)
    /// - Parameter string: The string to sanitize
    /// - Returns: Sanitized string with HTML entities escaped
    static func sanitizeHTML(_ string: String) -> String {
        var sanitized = string

        // Escape HTML entities
        let replacements: [String: String] = [
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&#x27;",
            "/": "&#x2F;"
        ]

        for (char, entity) in replacements {
            sanitized = sanitized.replacingOccurrences(of: char, with: entity)
        }

        return sanitized
    }

    /// Sanitizes a string by removing or escaping shell metacharacters
    /// - Parameter string: The string to sanitize
    /// - Returns: Sanitized string safe for shell execution
    static func sanitizeShellArgument(_ string: String) -> String {
        // Remove dangerous characters
        let dangerousChars = CharacterSet(charactersIn: ";|&$`<>()\n\r")
        return string.components(separatedBy: dangerousChars).joined()
    }

    /// Sanitizes user input for general text fields
    /// - Parameter string: The string to sanitize
    /// - Returns: Sanitized string
    static func sanitizeUserInput(_ string: String) -> String {
        var sanitized = string

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        // Remove or replace control characters (except common whitespace)
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined(separator: " ")

        // Normalize whitespace
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
    }

    // MARK: - String Validation

    /// Validates that a string contains only alphanumeric characters
    /// - Parameter string: The string to validate
    /// - Returns: True if the string is alphanumeric
    static func isAlphanumeric(_ string: String) -> Bool {
        let alphanumericSet = CharacterSet.alphanumerics
        return string.unicodeScalars.allSatisfy { alphanumericSet.contains($0) }
    }

    /// Validates that a string contains only alphanumeric characters and allowed symbols
    /// - Parameters:
    ///   - string: The string to validate
    ///   - allowedSymbols: Set of allowed symbol characters
    /// - Returns: True if the string is valid
    static func isAlphanumericWithSymbols(_ string: String, allowedSymbols: Set<Character>) -> Bool {
        let alphanumericSet = CharacterSet.alphanumerics

        for char in string {
            let isAlphanumeric = char.unicodeScalars.allSatisfy { alphanumericSet.contains($0) }
            if !isAlphanumeric && !allowedSymbols.contains(char) {
                return false
            }
        }

        return true
    }

    // MARK: - Rate Limiting Helper

    /// Simple rate limiter for preventing abuse
    actor RateLimiter {
        private var requests: [String: [Date]] = [:]
        private let maxRequests: Int
        private let timeWindow: TimeInterval

        init(maxRequests: Int, timeWindow: TimeInterval) {
            self.maxRequests = maxRequests
            self.timeWindow = timeWindow
        }

        /// Checks if a request should be allowed
        /// - Parameter identifier: Unique identifier for the requester (e.g., IP, user ID)
        /// - Returns: True if the request should be allowed
        func shouldAllowRequest(for identifier: String) -> Bool {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)

            // Get existing requests for this identifier
            var timestamps = requests[identifier, default: []]

            // Remove old timestamps
            timestamps = timestamps.filter { $0 > cutoff }

            // Check if limit exceeded
            guard timestamps.count < maxRequests else {
                return false
            }

            // Add current timestamp
            timestamps.append(now)
            requests[identifier] = timestamps

            return true
        }

        /// Clears rate limit data for an identifier
        /// - Parameter identifier: The identifier to clear
        func clearRateLimit(for identifier: String) {
            requests[identifier] = nil
        }
    }

    // MARK: - Password Strength Validation

    /// Validates password strength
    /// - Parameters:
    ///   - password: The password to validate
    ///   - minLength: Minimum required length
    /// - Returns: True if the password meets strength requirements
    static func validatePasswordStrength(_ password: String, minLength: Int = 8) -> Bool {
        // Check minimum length
        guard password.count >= minLength else {
            return false
        }

        // Check for at least one uppercase letter
        let uppercaseRegex = ".*[A-Z]+.*"
        guard password.range(of: uppercaseRegex, options: .regularExpression) != nil else {
            return false
        }

        // Check for at least one lowercase letter
        let lowercaseRegex = ".*[a-z]+.*"
        guard password.range(of: lowercaseRegex, options: .regularExpression) != nil else {
            return false
        }

        // Check for at least one digit
        let digitRegex = ".*[0-9]+.*"
        guard password.range(of: digitRegex, options: .regularExpression) != nil else {
            return false
        }

        // Check for at least one special character
        let specialCharRegex = ".*[!@#$%^&*(),.?\":{}|<>]+.*"
        guard password.range(of: specialCharRegex, options: .regularExpression) != nil else {
            return false
        }

        return true
    }

    // MARK: - Safe String Truncation

    /// Safely truncates a string to a maximum length
    /// - Parameters:
    ///   - string: The string to truncate
    ///   - maxLength: Maximum allowed length
    ///   - suffix: Optional suffix to append (e.g., "...")
    /// - Returns: Truncated string
    static func truncate(_ string: String, to maxLength: Int, suffix: String = "...") -> String {
        guard string.count > maxLength else {
            return string
        }

        let truncatedLength = maxLength - suffix.count
        guard truncatedLength > 0 else {
            return String(string.prefix(maxLength))
        }

        let truncated = String(string.prefix(truncatedLength))
        return truncated + suffix
    }
}

// MARK: - Secure Random Generation

extension SecurityUtils {
    /// Generates a secure random string
    /// - Parameter length: Length of the random string
    /// - Returns: A cryptographically secure random string
    static func generateSecureRandomString(length: Int) -> String? {
        var bytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        guard result == errSecSuccess else {
            return nil
        }

        return Data(bytes).base64EncodedString()
    }

    /// Generates a secure random token
    /// - Parameter byteCount: Number of random bytes to generate
    /// - Returns: A hex-encoded secure random token
    static func generateSecureToken(byteCount: Int = 32) -> String? {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)

        guard result == errSecSuccess else {
            return nil
        }

        return bytes.map { String(format: "%02hhx", $0) }.joined()
    }
}
