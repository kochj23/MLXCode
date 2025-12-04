//
//  SecurityUtilsTests.swift
//  MLX Code Tests
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import XCTest
@testable import MLX_Code

/// Unit tests for SecurityUtils
final class SecurityUtilsTests: XCTestCase {

    // MARK: - File Path Validation Tests

    func testValidateValidFilePath() {
        XCTAssertTrue(SecurityUtils.validateFilePath("/usr/bin/python3"))
        XCTAssertTrue(SecurityUtils.validateFilePath("/tmp/test.txt"))
        XCTAssertTrue(SecurityUtils.validateFilePath("Documents/file.pdf"))
    }

    func testValidateInvalidFilePath() {
        // Empty path
        XCTAssertFalse(SecurityUtils.validateFilePath(""))
        XCTAssertFalse(SecurityUtils.validateFilePath("   "))
    }

    func testValidatePathWithDirectoryTraversal() {
        XCTAssertFalse(SecurityUtils.validateFilePath("../etc/passwd"))
        XCTAssertFalse(SecurityUtils.validateFilePath("../../sensitive"))
        XCTAssertFalse(SecurityUtils.validateFilePath("/path/../../../etc/hosts"))
    }

    func testValidatePathWithEncodedTraversal() {
        XCTAssertFalse(SecurityUtils.validateFilePath("%2e%2e/etc/passwd"))
        XCTAssertFalse(SecurityUtils.validateFilePath("%2e%2e\\windows\\system32"))
    }

    func testValidateVeryLongPath() {
        let longPath = String(repeating: "a", count: 5000)
        XCTAssertFalse(SecurityUtils.validateFilePath(longPath))
    }

    // MARK: - Command Validation Tests

    func testValidateValidCommand() {
        XCTAssertTrue(SecurityUtils.validateCommand("ls -la"))
        XCTAssertTrue(SecurityUtils.validateCommand("python3 script.py"))
        XCTAssertTrue(SecurityUtils.validateCommand("echo hello"))
    }

    func testValidateInvalidCommand() {
        // Empty command
        XCTAssertFalse(SecurityUtils.validateCommand(""))
        XCTAssertFalse(SecurityUtils.validateCommand("   "))
    }

    func testValidateCommandWithInjection() {
        XCTAssertFalse(SecurityUtils.validateCommand("ls; rm -rf /"))
        XCTAssertFalse(SecurityUtils.validateCommand("cat file | grep secret"))
        XCTAssertFalse(SecurityUtils.validateCommand("echo test && rm file"))
        XCTAssertFalse(SecurityUtils.validateCommand("ls > /dev/null"))
        XCTAssertFalse(SecurityUtils.validateCommand("cat < /etc/passwd"))
    }

    func testValidateCommandWithSubstitution() {
        XCTAssertFalse(SecurityUtils.validateCommand("echo $(whoami)"))
        XCTAssertFalse(SecurityUtils.validateCommand("cat ${HOME}/.ssh/id_rsa"))
        XCTAssertFalse(SecurityUtils.validateCommand("ls `pwd`"))
    }

    // MARK: - Email Validation Tests

    func testValidateValidEmail() {
        XCTAssertTrue(SecurityUtils.validateEmail("user@example.com"))
        XCTAssertTrue(SecurityUtils.validateEmail("test.user@domain.co.uk"))
        XCTAssertTrue(SecurityUtils.validateEmail("name+tag@company.org"))
        XCTAssertTrue(SecurityUtils.validateEmail("user123@sub.domain.com"))
    }

    func testValidateInvalidEmail() {
        XCTAssertFalse(SecurityUtils.validateEmail(""))
        XCTAssertFalse(SecurityUtils.validateEmail("notanemail"))
        XCTAssertFalse(SecurityUtils.validateEmail("@domain.com"))
        XCTAssertFalse(SecurityUtils.validateEmail("user@"))
        XCTAssertFalse(SecurityUtils.validateEmail("user @domain.com"))
        XCTAssertFalse(SecurityUtils.validateEmail("user@domain"))
    }

    // MARK: - URL Validation Tests

    func testValidateValidURL() {
        XCTAssertTrue(SecurityUtils.validateURL("https://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("http://localhost:8080"))
        XCTAssertTrue(SecurityUtils.validateURL("file:///path/to/file"))
        XCTAssertTrue(SecurityUtils.validateURL("https://sub.domain.com/path?query=value"))
    }

    func testValidateInvalidURL() {
        XCTAssertFalse(SecurityUtils.validateURL(""))
        XCTAssertFalse(SecurityUtils.validateURL("not a url"))
        XCTAssertFalse(SecurityUtils.validateURL("ftp://invalid.com")) // FTP not allowed
        XCTAssertFalse(SecurityUtils.validateURL("javascript:alert(1)")) // Dangerous protocol
        XCTAssertFalse(SecurityUtils.validateURL("data:text/html,<script>alert(1)</script>"))
    }

    // MARK: - Port Validation Tests

    func testValidateValidPort() {
        XCTAssertTrue(SecurityUtils.validatePort(80))
        XCTAssertTrue(SecurityUtils.validatePort(443))
        XCTAssertTrue(SecurityUtils.validatePort(8080))
        XCTAssertTrue(SecurityUtils.validatePort(3000))
        XCTAssertTrue(SecurityUtils.validatePort(65535))
    }

    func testValidateInvalidPort() {
        XCTAssertFalse(SecurityUtils.validatePort(0))
        XCTAssertFalse(SecurityUtils.validatePort(-1))
        XCTAssertFalse(SecurityUtils.validatePort(65536))
        XCTAssertFalse(SecurityUtils.validatePort(100000))
    }

    // MARK: - String Length Validation Tests

    func testValidateLength() {
        XCTAssertTrue(SecurityUtils.validateLength("hello", max: 10))
        XCTAssertTrue(SecurityUtils.validateLength("test", min: 3, max: 10))
        XCTAssertTrue(SecurityUtils.validateLength("a", min: 1, max: 1))
    }

    func testValidateLengthTooShort() {
        XCTAssertFalse(SecurityUtils.validateLength("ab", min: 3, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("", min: 1, max: 10))
    }

    func testValidateLengthTooLong() {
        XCTAssertFalse(SecurityUtils.validateLength("toolongstring", max: 5))
        XCTAssertFalse(SecurityUtils.validateLength("abcdefghij", min: 0, max: 5))
    }

    // MARK: - File Path Sanitization Tests

    func testSanitizeFilePath() {
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("/path/to/file"), "/path/to/file")
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("  /path  "), "/path")
    }

    func testSanitizeFilePathRemovesNullBytes() {
        let pathWithNull = "/path\0to/file"
        XCTAssertEqual(SecurityUtils.sanitizeFilePath(pathWithNull), "/pathto/file")
    }

    func testSanitizeFilePathNormalizesSlashes() {
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("path\\to\\file"), "path/to/file")
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("path//to///file"), "path/to/file")
    }

    // MARK: - SQL Sanitization Tests

    func testSanitizeSQL() {
        XCTAssertEqual(SecurityUtils.sanitizeSQL("O'Brien"), "O''Brien")
        XCTAssertEqual(SecurityUtils.sanitizeSQL("It's"), "It''s")
        XCTAssertEqual(SecurityUtils.sanitizeSQL("normal"), "normal")
    }

    func testSanitizeSQLRemovesNullBytes() {
        let sqlWithNull = "SELECT\0*"
        XCTAssertEqual(SecurityUtils.sanitizeSQL(sqlWithNull), "SELECT*")
    }

    // MARK: - HTML Sanitization Tests

    func testSanitizeHTML() {
        XCTAssertEqual(SecurityUtils.sanitizeHTML("<script>alert(1)</script>"),
                      "&lt;script&gt;alert(1)&lt;&#x2F;script&gt;")
        XCTAssertEqual(SecurityUtils.sanitizeHTML("Hello & goodbye"),
                      "Hello &amp; goodbye")
        XCTAssertEqual(SecurityUtils.sanitizeHTML("Quote: \"test\""),
                      "Quote: &quot;test&quot;")
        XCTAssertEqual(SecurityUtils.sanitizeHTML("Tag: <div>"),
                      "Tag: &lt;div&gt;")
    }

    // MARK: - Shell Argument Sanitization Tests

    func testSanitizeShellArgument() {
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("safe_argument"), "safe_argument")
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("file.txt"), "file.txt")
    }

    func testSanitizeShellArgumentRemovesDangerousChars() {
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("test; rm -rf /"), "test rm -rf ")
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("test | grep"), "test  grep")
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("test && echo"), "test  echo")
        XCTAssertEqual(SecurityUtils.sanitizeShellArgument("test$(whoami)"), "testwhoami")
    }

    // MARK: - User Input Sanitization Tests

    func testSanitizeUserInput() {
        XCTAssertEqual(SecurityUtils.sanitizeUserInput("Hello World"), "Hello World")
        XCTAssertEqual(SecurityUtils.sanitizeUserInput("  spaces  "), "spaces")
    }

    func testSanitizeUserInputRemovesNullBytes() {
        let inputWithNull = "Hello\0World"
        XCTAssertEqual(SecurityUtils.sanitizeUserInput(inputWithNull), "HelloWorld")
    }

    func testSanitizeUserInputNormalizesWhitespace() {
        XCTAssertEqual(SecurityUtils.sanitizeUserInput("Hello    World"), "Hello World")
        XCTAssertEqual(SecurityUtils.sanitizeUserInput("Multiple\n\nNewlines"), "Multiple Newlines")
    }

    // MARK: - Alphanumeric Validation Tests

    func testIsAlphanumeric() {
        XCTAssertTrue(SecurityUtils.isAlphanumeric("abc123"))
        XCTAssertTrue(SecurityUtils.isAlphanumeric("ABC"))
        XCTAssertTrue(SecurityUtils.isAlphanumeric("123"))
        XCTAssertTrue(SecurityUtils.isAlphanumeric("Test123"))
    }

    func testIsNotAlphanumeric() {
        XCTAssertFalse(SecurityUtils.isAlphanumeric("test-123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("hello world"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("test@123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric(""))
    }

    func testIsAlphanumericWithSymbols() {
        let allowedSymbols: Set<Character> = ["-", "_", "."]

        XCTAssertTrue(SecurityUtils.isAlphanumericWithSymbols("test-file_name.txt", allowedSymbols: allowedSymbols))
        XCTAssertTrue(SecurityUtils.isAlphanumericWithSymbols("user_123", allowedSymbols: allowedSymbols))
        XCTAssertTrue(SecurityUtils.isAlphanumericWithSymbols("file.name", allowedSymbols: allowedSymbols))
    }

    func testIsNotAlphanumericWithSymbols() {
        let allowedSymbols: Set<Character> = ["-", "_"]

        XCTAssertFalse(SecurityUtils.isAlphanumericWithSymbols("test@file", allowedSymbols: allowedSymbols))
        XCTAssertFalse(SecurityUtils.isAlphanumericWithSymbols("file name", allowedSymbols: allowedSymbols))
        XCTAssertFalse(SecurityUtils.isAlphanumericWithSymbols("test#123", allowedSymbols: allowedSymbols))
    }

    // MARK: - Password Strength Validation Tests

    func testValidateStrongPassword() {
        XCTAssertTrue(SecurityUtils.validatePasswordStrength("Strong123!"))
        XCTAssertTrue(SecurityUtils.validatePasswordStrength("MyP@ssw0rd"))
        XCTAssertTrue(SecurityUtils.validatePasswordStrength("Secure#2024"))
    }

    func testValidateWeakPassword() {
        // Too short
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("Short1!"))

        // No uppercase
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("password123!"))

        // No lowercase
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("PASSWORD123!"))

        // No digit
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("Password!"))

        // No special character
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("Password123"))
    }

    func testValidatePasswordWithCustomMinLength() {
        XCTAssertTrue(SecurityUtils.validatePasswordStrength("Str0ng!", minLength: 7))
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("Str0ng!", minLength: 10))
    }

    // MARK: - String Truncation Tests

    func testTruncateShortString() {
        let result = SecurityUtils.truncate("Hello", to: 10)
        XCTAssertEqual(result, "Hello")
    }

    func testTruncateLongString() {
        let result = SecurityUtils.truncate("Hello World", to: 8)
        XCTAssertEqual(result, "Hello...")
    }

    func testTruncateWithCustomSuffix() {
        let result = SecurityUtils.truncate("Hello World", to: 8, suffix: ">>")
        XCTAssertEqual(result, "Hello >>")
    }

    func testTruncateVeryShortMaxLength() {
        let result = SecurityUtils.truncate("Hello", to: 3)
        XCTAssertEqual(result, "Hel")
    }

    // MARK: - Secure Random Generation Tests

    func testGenerateSecureRandomString() {
        let random1 = SecurityUtils.generateSecureRandomString(length: 16)
        let random2 = SecurityUtils.generateSecureRandomString(length: 16)

        XCTAssertNotNil(random1)
        XCTAssertNotNil(random2)
        XCTAssertNotEqual(random1, random2) // Should be different
    }

    func testGenerateSecureToken() {
        let token1 = SecurityUtils.generateSecureToken(byteCount: 32)
        let token2 = SecurityUtils.generateSecureToken(byteCount: 32)

        XCTAssertNotNil(token1)
        XCTAssertNotNil(token2)
        XCTAssertNotEqual(token1, token2) // Should be different

        // Token should be hex-encoded (64 chars for 32 bytes)
        XCTAssertEqual(token1?.count, 64)
    }

    func testGenerateSecureTokenDifferentLengths() {
        let token16 = SecurityUtils.generateSecureToken(byteCount: 16)
        let token32 = SecurityUtils.generateSecureToken(byteCount: 32)

        XCTAssertEqual(token16?.count, 32) // 16 bytes = 32 hex chars
        XCTAssertEqual(token32?.count, 64) // 32 bytes = 64 hex chars
    }

    // MARK: - Rate Limiter Tests

    func testRateLimiterAllowsRequests() async {
        let rateLimiter = SecurityUtils.RateLimiter(maxRequests: 5, timeWindow: 60.0)

        let allowed1 = await rateLimiter.shouldAllowRequest(for: "user1")
        let allowed2 = await rateLimiter.shouldAllowRequest(for: "user1")

        XCTAssertTrue(allowed1)
        XCTAssertTrue(allowed2)
    }

    func testRateLimiterBlocksExcessiveRequests() async {
        let rateLimiter = SecurityUtils.RateLimiter(maxRequests: 3, timeWindow: 60.0)

        // Make 3 allowed requests
        for _ in 1...3 {
            let allowed = await rateLimiter.shouldAllowRequest(for: "user1")
            XCTAssertTrue(allowed)
        }

        // 4th request should be blocked
        let blocked = await rateLimiter.shouldAllowRequest(for: "user1")
        XCTAssertFalse(blocked)
    }

    func testRateLimiterSeparatesUsers() async {
        let rateLimiter = SecurityUtils.RateLimiter(maxRequests: 2, timeWindow: 60.0)

        // User 1 makes 2 requests
        _ = await rateLimiter.shouldAllowRequest(for: "user1")
        _ = await rateLimiter.shouldAllowRequest(for: "user1")

        // User 2 should still be allowed
        let allowed = await rateLimiter.shouldAllowRequest(for: "user2")
        XCTAssertTrue(allowed)
    }

    func testRateLimiterClearRateLimit() async {
        let rateLimiter = SecurityUtils.RateLimiter(maxRequests: 2, timeWindow: 60.0)

        // Make 2 requests
        _ = await rateLimiter.shouldAllowRequest(for: "user1")
        _ = await rateLimiter.shouldAllowRequest(for: "user1")

        // Should be blocked
        var blocked = await rateLimiter.shouldAllowRequest(for: "user1")
        XCTAssertFalse(blocked)

        // Clear rate limit
        await rateLimiter.clearRateLimit(for: "user1")

        // Should be allowed again
        let allowed = await rateLimiter.shouldAllowRequest(for: "user1")
        XCTAssertTrue(allowed)
    }

    // MARK: - Edge Cases Tests

    func testEmptyStringHandling() {
        XCTAssertEqual(SecurityUtils.sanitizeUserInput(""), "")
        XCTAssertEqual(SecurityUtils.sanitizeHTML(""), "")
        XCTAssertEqual(SecurityUtils.sanitizeSQL(""), "")
        XCTAssertEqual(SecurityUtils.sanitizeFilePath(""), "")
    }

    func testUnicodeHandling() {
        let unicode = "Hello 世界 🌍"
        let sanitized = SecurityUtils.sanitizeUserInput(unicode)
        XCTAssertEqual(sanitized, unicode)
    }

    func testVeryLongStringHandling() {
        let longString = String(repeating: "a", count: 10000)
        let truncated = SecurityUtils.truncate(longString, to: 100)
        XCTAssertEqual(truncated.count, 100)
    }
}
