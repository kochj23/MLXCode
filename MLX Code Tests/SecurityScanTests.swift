//
//  SecurityScanTests.swift
//  MLX Code Tests
//
//  Security tests: no hardcoded API keys in source, Keychain usage
//  validation, no UserDefaults for secrets, no unsafe C functions,
//  input sanitization coverage, and SSRF prevention.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class SecurityScanTests: XCTestCase {

    // MARK: - No Hardcoded API Keys in Source

    /// Scans all Swift source files for patterns that look like hardcoded API keys.
    /// This catches accidental commits of real secrets.
    func testNoHardcodedAPIKeysInSource() throws {
        let projectRoot = "/Volumes/Data/xcode/MLX Code/MLX Code"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: projectRoot) else {
            // If running on CI without the project directory, skip gracefully
            throw XCTSkip("Project source directory not available")
        }

        let enumerator = fileManager.enumerator(atPath: projectRoot)
        var violations: [String] = []

        // Patterns that indicate real API keys (not regex patterns or test data)
        let keyPatterns: [(pattern: String, description: String)] = [
            ("sk-[A-Za-z0-9]{20,}", "OpenAI/Anthropic API key"),
            ("AKIA[0-9A-Z]{16}", "AWS Access Key"),
            ("ghp_[A-Za-z0-9]{36}", "GitHub PAT"),
            ("xox[bpoas]-[A-Za-z0-9-]{10,}", "Slack token"),
        ]

        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            // Skip test files -- they may contain patterns as test data
            guard !file.contains("Tests") else { continue }

            let fullPath = (projectRoot as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }

            for (pattern, description) in keyPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                    // Check if it's in a comment or string pattern (not an actual key)
                    // Simple heuristic: if the line contains "pattern" or "regex" or "example", skip
                    let lines = content.components(separatedBy: .newlines)
                    for (lineNum, line) in lines.enumerated() {
                        let lower = line.lowercased()
                        if lower.contains("pattern") || lower.contains("regex") ||
                           lower.contains("example") || lower.contains("test") ||
                           lower.contains("//") && lower.range(of: pattern, options: .regularExpression) == nil {
                            continue
                        }
                        if line.range(of: pattern, options: .regularExpression) != nil {
                            violations.append("\(file):\(lineNum + 1) - Potential \(description)")
                        }
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found potential hardcoded API keys:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - Keychain Usage Validation

    /// Verifies that secrets are stored via KeychainManager (SecItem*), not UserDefaults.
    /// Scans non-test Swift files for patterns like UserDefaults.set(...apiKey...).
    func testSecretsNotInUserDefaults() throws {
        let projectRoot = "/Volumes/Data/xcode/MLX Code/MLX Code"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: projectRoot) else {
            throw XCTSkip("Project source directory not available")
        }

        let enumerator = fileManager.enumerator(atPath: projectRoot)
        var violations: [String] = []

        // Words that suggest a secret is being stored
        let secretKeywords = [
            "apikey", "api_key", "apiKey",
            "secret", "password", "token",
            "credential", "bearer",
        ]

        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            guard !file.contains("Tests") else { continue }
            // KeychainManager.swift itself uses UserDefaults for migration -- that's expected
            guard !file.contains("KeychainManager") else { continue }

            let fullPath = (projectRoot as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for (lineNum, line) in lines.enumerated() {
                let lower = line.lowercased()
                // Check for UserDefaults.standard.set or userDefaults.set with secret keywords
                if (lower.contains("userdefaults") && lower.contains(".set")) ||
                   (lower.contains("userdefaults") && lower.contains("forkey")) {
                    for keyword in secretKeywords {
                        if lower.contains(keyword) {
                            violations.append("\(file):\(lineNum + 1) - Possible secret '\(keyword)' stored in UserDefaults")
                        }
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found secrets potentially stored in UserDefaults instead of Keychain:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - No Unsafe C Functions

    /// Scans source for unsafe C functions that can cause buffer overflows.
    func testNoUnsafeCFunctions() throws {
        let projectRoot = "/Volumes/Data/xcode/MLX Code/MLX Code"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: projectRoot) else {
            throw XCTSkip("Project source directory not available")
        }

        let enumerator = fileManager.enumerator(atPath: projectRoot)
        var violations: [String] = []

        // Unsafe C functions per CLAUDE.md memory security rules
        let unsafeFunctions = ["strcpy(", "strcat(", "sprintf(", "gets("]

        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".swift") || file.hasSuffix(".m") || file.hasSuffix(".h") else { continue }

            let fullPath = (projectRoot as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for (lineNum, line) in lines.enumerated() {
                // Skip comments
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }

                for fn in unsafeFunctions {
                    if line.contains(fn) {
                        violations.append("\(file):\(lineNum + 1) - Unsafe C function: \(fn)")
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found unsafe C functions:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - Input Sanitization for User Prompts

    func testSanitizeUserInputRemovesNullBytes() {
        let input = "Hello\0World"
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertFalse(sanitized.contains("\0"), "Null bytes should be removed")
    }

    func testSanitizeUserInputNormalizesWhitespace() {
        let input = "Hello    \t\t  World"
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertFalse(sanitized.contains("  "), "Multiple spaces should be normalized")
    }

    func testSanitizeUserInputTrimsWhitespace() {
        let input = "  Hello World  "
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertEqual(sanitized, "Hello World")
    }

    func testSanitizeHTMLEscapesScriptTags() {
        let input = "<script>alert('xss')</script>"
        let sanitized = SecurityUtils.sanitizeHTML(input)
        XCTAssertFalse(sanitized.contains("<script>"), "Script tags should be escaped")
        XCTAssertTrue(sanitized.contains("&lt;"), "< should be escaped")
        XCTAssertTrue(sanitized.contains("&gt;"), "> should be escaped")
    }

    func testSanitizeHTMLEscapesQuotes() {
        let input = #"He said "hello""#
        let sanitized = SecurityUtils.sanitizeHTML(input)
        XCTAssertTrue(sanitized.contains("&quot;"), "Double quotes should be escaped")
    }

    func testSanitizeShellArgumentRemovesMetachars() {
        let input = "file.txt; rm -rf /"
        let sanitized = SecurityUtils.sanitizeShellArgument(input)
        XCTAssertFalse(sanitized.contains(";"), "Semicolons should be removed")
        XCTAssertFalse(sanitized.contains("|"), "Pipes should be removed")
    }

    func testSanitizeFilePathRemovesDoubleSlashes() {
        let input = "/path//to///file"
        let sanitized = SecurityUtils.sanitizeFilePath(input)
        XCTAssertFalse(sanitized.contains("//"), "Double slashes should be collapsed")
    }

    func testSanitizeFilePathNormalizesBackslashes() {
        let input = "path\\to\\file"
        let sanitized = SecurityUtils.sanitizeFilePath(input)
        XCTAssertFalse(sanitized.contains("\\"), "Backslashes should be converted to forward slashes")
    }

    // MARK: - SSRF Prevention

    func testSSRFBlocksPrivateIPs() {
        let privateURLs = [
            "https://10.0.0.1/admin",
            "https://192.168.1.1/",
            "https://172.16.0.1/internal",
        ]
        for url in privateURLs {
            XCTAssertThrowsError(try CommandValidator.validateSafeURL(url),
                "Private IP should be blocked: \(url)")
        }
    }

    func testSSRFBlocksLocalhost() {
        XCTAssertThrowsError(try CommandValidator.validateSafeURL("https://localhost/admin"))
        XCTAssertThrowsError(try CommandValidator.validateSafeURL("https://127.0.0.1/admin"))
    }

    func testSSRFAllowsPublicURLs() {
        XCTAssertNoThrow(try CommandValidator.validateSafeURL("https://github.com"))
        XCTAssertNoThrow(try CommandValidator.validateSafeURL("https://huggingface.co/models"))
    }

    // MARK: - URL Validation

    func testURLRejectsUnsafeProtocols() {
        XCTAssertFalse(SecurityUtils.validateURL("javascript:alert(1)"), "javascript: should be rejected")
        XCTAssertFalse(SecurityUtils.validateURL("data:text/html,<script>"), "data: should be rejected")
        XCTAssertFalse(SecurityUtils.validateURL("ftp://example.com"), "ftp: should be rejected")
    }

    func testURLAcceptsSafeProtocols() {
        XCTAssertTrue(SecurityUtils.validateURL("https://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("http://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("file:///path/to/file"))
    }

    // MARK: - Password Strength

    func testStrongPasswordPasses() {
        XCTAssertTrue(SecurityUtils.validatePasswordStrength("Str0ng!Pass"))
    }

    func testWeakPasswordFails() {
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("short"), "Too short")
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("alllowercase1!"), "No uppercase")
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("ALLUPPERCASE1!"), "No lowercase")
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("NoDigits!!here"), "No digits")
        XCTAssertFalse(SecurityUtils.validatePasswordStrength("NoSpecial1here"), "No special chars")
    }

    // MARK: - Secure Random Generation

    func testSecureRandomStringGeneration() {
        let random = SecurityUtils.generateSecureRandomString(length: 32)
        XCTAssertNotNil(random, "Should generate a random string")
        XCTAssertFalse(random!.isEmpty, "Random string should not be empty")
    }

    func testSecureTokenGeneration() {
        let token = SecurityUtils.generateSecureToken(byteCount: 32)
        XCTAssertNotNil(token, "Should generate a secure token")
        XCTAssertEqual(token!.count, 64, "32 bytes should produce 64 hex chars")
    }

    func testSecureTokensAreUnique() {
        let t1 = SecurityUtils.generateSecureToken()
        let t2 = SecurityUtils.generateSecureToken()
        XCTAssertNotEqual(t1, t2, "Two generated tokens should be different")
    }

    // MARK: - Validation Helpers

    func testValidateEmailAcceptsValid() {
        XCTAssertTrue(SecurityUtils.validateEmail("test@example.com"))
        XCTAssertTrue(SecurityUtils.validateEmail("user+tag@domain.co.uk"))
    }

    func testValidateEmailRejectsInvalid() {
        XCTAssertFalse(SecurityUtils.validateEmail("notanemail"))
        XCTAssertFalse(SecurityUtils.validateEmail("@domain.com"))
        XCTAssertFalse(SecurityUtils.validateEmail("test@"))
    }

    func testValidatePort() {
        XCTAssertTrue(SecurityUtils.validatePort(80))
        XCTAssertTrue(SecurityUtils.validatePort(443))
        XCTAssertTrue(SecurityUtils.validatePort(37422))
        XCTAssertTrue(SecurityUtils.validatePort(65535))
        XCTAssertFalse(SecurityUtils.validatePort(0))
        XCTAssertFalse(SecurityUtils.validatePort(65536))
        XCTAssertFalse(SecurityUtils.validatePort(-1))
    }

    func testValidateLength() {
        XCTAssertTrue(SecurityUtils.validateLength("hello", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("toolong", min: 1, max: 3))
    }

    func testTruncation() {
        let result = SecurityUtils.truncate("Hello World", to: 8)
        XCTAssertEqual(result, "Hello...")
        XCTAssertLessThanOrEqual(result.count, 8)
    }

    func testTruncationShortString() {
        let result = SecurityUtils.truncate("Hi", to: 10)
        XCTAssertEqual(result, "Hi", "Short strings should not be truncated")
    }

    func testIsAlphanumeric() {
        XCTAssertTrue(SecurityUtils.isAlphanumeric("abc123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("abc 123"))
        XCTAssertFalse(SecurityUtils.isAlphanumeric("abc!123"))
    }
}
