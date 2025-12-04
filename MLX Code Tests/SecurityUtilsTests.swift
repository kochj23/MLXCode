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

    // MARK: - Path Validation Tests

    func testPathTraversalDetection() {
        let maliciousPath = "/Users/test/../../../etc/passwd"
        let isValid = SecurityUtils.validatePath(maliciousPath)

        XCTAssertFalse(isValid, "Path traversal should be detected and rejected")
    }

    func testValidPathAcceptance() {
        let validPath = "/Users/kochj/Desktop/xcode/project.swift"
        let isValid = SecurityUtils.validatePath(validPath)

        XCTAssertTrue(isValid, "Valid path should be accepted")
    }

    func testSymlinkDetection() {
        // Test that symlinks are not followed
        let symlinkPath = "/tmp/../var/log/system.log"
        let isValid = SecurityUtils.validatePath(symlinkPath)

        XCTAssertFalse(isValid, "Symlink path traversal should be rejected")
    }

    // MARK: - Input Validation Tests

    func testInputLengthValidation() {
        let shortInput = "Valid input"
        let longInput = String(repeating: "a", count: 100_001) // Exceeds max

        XCTAssertTrue(SecurityUtils.validateInput(shortInput), "Short input should be valid")
        XCTAssertFalse(SecurityUtils.validateInput(longInput), "Excessively long input should be invalid")
    }

    func testSpecialCharacterValidation() {
        let safeInput = "Hello World 123"
        let unsafeInput = "rm -rf /; echo 'pwned'"

        XCTAssertTrue(SecurityUtils.validateInput(safeInput), "Safe input should be valid")
        XCTAssertTrue(SecurityUtils.validateInput(unsafeInput), "Input validation should allow shell characters (they are escaped)")
    }

    // MARK: - Sanitization Tests

    func testSQLInjectionPrevention() {
        let sqlInjection = "'; DROP TABLE users; --"
        let sanitized = SecurityUtils.sanitizeSQL(sqlInjection)

        XCTAssertFalse(sanitized.contains("DROP TABLE"), "SQL injection should be sanitized")
        XCTAssertTrue(sanitized.contains("''"), "Single quotes should be escaped")
    }

    func testHTMLEscaping() {
        let htmlInput = "<script>alert('XSS')</script>"
        let escaped = SecurityUtils.escapeHTML(htmlInput)

        XCTAssertFalse(escaped.contains("<script>"), "HTML tags should be escaped")
        XCTAssertTrue(escaped.contains("&lt;"), "< should be escaped to &lt;")
        XCTAssertTrue(escaped.contains("&gt;"), "> should be escaped to &gt;")
    }

    func testPathSanitization() {
        let unsafePath = "/Users/../../etc/passwd"
        let sanitized = SecurityUtils.sanitizePath(unsafePath)

        XCTAssertFalse(sanitized.contains(".."), "Path traversal sequences should be removed")
    }

    // MARK: - Command Injection Tests

    func testShellMetacharacterEscaping() {
        let dangerousCommand = "file.txt; rm -rf /"
        let escaped = SecurityUtils.escapeShellArgument(dangerousCommand)

        XCTAssertFalse(escaped.contains(";"), "Semicolons should be escaped or quoted")
        XCTAssertTrue(escaped.hasPrefix("'") || escaped.contains("\\"), "String should be quoted or escaped")
    }

    // MARK: - Regex Validation Tests

    func testEmailValidation() {
        let validEmails = ["test@example.com", "user.name@domain.co.uk", "user+tag@example.org"]
        let invalidEmails = ["invalid", "test@", "@domain.com", "test..user@example.com"]

        for email in validEmails {
            XCTAssertTrue(SecurityUtils.isValidEmail(email), "\(email) should be valid")
        }

        for email in invalidEmails {
            XCTAssertFalse(SecurityUtils.isValidEmail(email), "\(email) should be invalid")
        }
    }

    func testURLValidation() {
        let validURLs = ["https://example.com", "http://test.org/path", "https://sub.domain.com:8080/"]
        let invalidURLs = ["not a url", "ftp://invalid", "javascript:alert(1)", "file:///etc/passwd"]

        for url in validURLs {
            XCTAssertTrue(SecurityUtils.isValidURL(url), "\(url) should be valid")
        }

        for url in invalidURLs {
            XCTAssertFalse(SecurityUtils.isValidURL(url), "\(url) should be invalid")
        }
    }

    // MARK: - Integer Validation Tests

    func testIntegerRangeValidation() {
        XCTAssertTrue(SecurityUtils.isValidInteger(50, min: 0, max: 100), "50 should be in range 0-100")
        XCTAssertFalse(SecurityUtils.isValidInteger(150, min: 0, max: 100), "150 should be out of range")
        XCTAssertFalse(SecurityUtils.isValidInteger(-10, min: 0, max: 100), "-10 should be out of range")
    }

    // MARK: - Performance Tests

    func testValidationPerformance() {
        let input = String(repeating: "a", count: 10_000)

        measure {
            for _ in 0..<1000 {
                _ = SecurityUtils.validateInput(input)
            }
        }
    }
}
