//
//  SecurityUtilsTests.swift
//  MLX Code Tests
//
//  Unit tests for SecurityUtils: path validation, command validation,
//  sanitization, email/URL validation, and helper functions.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class SecurityUtilsTests: XCTestCase {

    // MARK: - File Path Validation

    func testValidPathAccepted() {
        let validPath = "/Users/testuser/projects/project.swift"
        XCTAssertTrue(SecurityUtils.validateFilePath(validPath), "Valid absolute path should be accepted")
    }

    func testEmptyPathRejected() {
        XCTAssertFalse(SecurityUtils.validateFilePath(""), "Empty path should be rejected")
        XCTAssertFalse(SecurityUtils.validateFilePath("   "), "Whitespace-only path should be rejected")
    }

    func testExcessivelyLongPathRejected() {
        let longPath = "/" + String(repeating: "a", count: 5000)
        XCTAssertFalse(SecurityUtils.validateFilePath(longPath), "Path exceeding 4096 bytes should be rejected")
    }

    // MARK: - Command Validation

    func testSafeCommandAccepted() {
        XCTAssertTrue(SecurityUtils.validateCommand("ls"), "Simple command should be accepted")
        XCTAssertTrue(SecurityUtils.validateCommand("git status"), "Git command should be accepted")
        XCTAssertTrue(SecurityUtils.validateCommand("swift build -c release"), "Build command should be accepted")
    }

    func testEmptyCommandRejected() {
        XCTAssertFalse(SecurityUtils.validateCommand(""), "Empty command should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("   "), "Whitespace-only command should be rejected")
    }

    func testCommandWithMetacharsRejected() {
        XCTAssertFalse(SecurityUtils.validateCommand("ls; rm -rf /"), "Semicolon injection should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("cat file | sh"), "Pipe should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("echo $PATH"), "Dollar sign should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("echo `whoami`"), "Backtick should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("echo $(id)"), "Dollar-paren should be rejected")
    }

    // MARK: - Email Validation

    func testValidEmailAccepted() {
        XCTAssertTrue(SecurityUtils.validateEmail("test@example.com"))
        XCTAssertTrue(SecurityUtils.validateEmail("user.name@domain.co.uk"))
        XCTAssertTrue(SecurityUtils.validateEmail("user+tag@example.org"))
    }

    func testInvalidEmailRejected() {
        XCTAssertFalse(SecurityUtils.validateEmail("notanemail"))
        XCTAssertFalse(SecurityUtils.validateEmail("@domain.com"))
        XCTAssertFalse(SecurityUtils.validateEmail("test@"))
    }

    // MARK: - URL Validation

    func testValidURLAccepted() {
        XCTAssertTrue(SecurityUtils.validateURL("https://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("http://test.org/path"))
    }

    func testUnsafeProtocolRejected() {
        XCTAssertFalse(SecurityUtils.validateURL("javascript:alert(1)"))
        XCTAssertFalse(SecurityUtils.validateURL("ftp://example.com"))
    }

    func testInvalidURLRejected() {
        XCTAssertFalse(SecurityUtils.validateURL("not a url"))
    }

    // MARK: - Port Validation

    func testValidPortAccepted() {
        XCTAssertTrue(SecurityUtils.validatePort(80))
        XCTAssertTrue(SecurityUtils.validatePort(443))
        XCTAssertTrue(SecurityUtils.validatePort(65535))
    }

    func testInvalidPortRejected() {
        XCTAssertFalse(SecurityUtils.validatePort(0))
        XCTAssertFalse(SecurityUtils.validatePort(65536))
        XCTAssertFalse(SecurityUtils.validatePort(-1))
    }

    // MARK: - Sanitization

    func testSQLSanitization() {
        let injection = "'; DROP TABLE users; --"
        let sanitized = SecurityUtils.sanitizeSQL(injection)
        XCTAssertTrue(sanitized.contains("''"), "Single quotes should be escaped")
        XCTAssertFalse(sanitized.contains("\0"), "Null bytes should be removed")
    }

    func testHTMLSanitization() {
        let input = "<script>alert('XSS')</script>"
        let sanitized = SecurityUtils.sanitizeHTML(input)
        XCTAssertFalse(sanitized.contains("<script>"), "HTML tags should be escaped")
        XCTAssertTrue(sanitized.contains("&lt;"), "< should be escaped to &lt;")
        XCTAssertTrue(sanitized.contains("&gt;"), "> should be escaped to &gt;")
    }

    func testShellArgumentSanitization() {
        let input = "file.txt; rm -rf /"
        let sanitized = SecurityUtils.sanitizeShellArgument(input)
        XCTAssertFalse(sanitized.contains(";"), "Semicolons should be removed")
    }

    func testFilePathSanitization() {
        let input = "path\\to\\file"
        let sanitized = SecurityUtils.sanitizeFilePath(input)
        XCTAssertFalse(sanitized.contains("\\"), "Backslashes should be normalized")
    }

    func testUserInputSanitization() {
        let input = "Hello\0World  \t\t  Test"
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertFalse(sanitized.contains("\0"), "Null bytes should be removed")
    }

    // MARK: - String Validation

    func testAlphanumericValidation() {
        XCTAssertTrue(SecurityUtils.isAlphanumeric("abc123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("abc 123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("abc!"))
    }

    func testLengthValidation() {
        XCTAssertTrue(SecurityUtils.validateLength("hello", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("toolongstring", min: 1, max: 5))
    }

    // MARK: - Performance

    func testValidationPerformance() {
        let input = String(repeating: "a", count: 10_000)
        measure {
            for _ in 0..<1000 {
                _ = SecurityUtils.validateCommand(input)
            }
        }
    }
}
