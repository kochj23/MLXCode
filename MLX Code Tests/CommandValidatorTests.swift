//
//  CommandValidatorTests.swift
//  MLX Code Tests
//
//  Adversarial tests for command validation: injection attempts,
//  Unicode tricks, nested commands, environment variable expansion,
//  and dangerous pattern matching.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class CommandValidatorTests: XCTestCase {

    // MARK: - Bash Command: Safe Commands

    func testSafeCommandsPass() throws {
        let safeCommands = [
            "ls",
            "pwd",
            "cat file.txt",
            "swift build",
            "xcodebuild -project MyApp.xcodeproj -scheme MyApp",
            "git status",
            "git log --oneline",
            "grep -r pattern .",
            "find . -name test.swift",
            "mkdir new_directory",
            "cp source.swift dest.swift",
            "mv old.swift new.swift",
            "wc -l file.swift",
            "head -20 file.swift",
            "tail -20 file.swift",
            "diff file1.swift file2.swift",
            "sort file.txt",
            "which swift",
        ]

        for command in safeCommands {
            XCTAssertNoThrow(
                try CommandValidator.validateBashCommand(command),
                "Safe command should pass: \(command)"
            )
        }
    }

    // MARK: - Bash Command: Length Validation

    func testEmptyCommandRejected() {
        XCTAssertThrowsError(try CommandValidator.validateBashCommand("")) { error in
            guard case SecurityError.commandLength = error else {
                XCTFail("Expected commandLength error, got: \(error)")
                return
            }
        }
    }

    func testWhitespaceOnlyCommandRejected() {
        // Whitespace-only should fail the SecurityUtils.validateCommand check
        // because trimmed it's empty
        XCTAssertThrowsError(try CommandValidator.validateBashCommand("   ")) { error in
            guard let secError = error as? SecurityError else {
                XCTFail("Expected SecurityError, got: \(error)")
                return
            }
            // Could be commandLength(3) or dangerousCharacters depending on implementation
            switch secError {
            case .commandLength, .dangerousCharacters:
                break // both acceptable
            default:
                XCTFail("Unexpected SecurityError variant: \(secError)")
            }
        }
    }

    func testExcessivelyLongCommandRejected() {
        let longCommand = String(repeating: "a", count: 10_001)
        XCTAssertThrowsError(try CommandValidator.validateBashCommand(longCommand)) { error in
            guard case SecurityError.commandLength = error else {
                XCTFail("Expected commandLength error")
                return
            }
        }
    }

    func testCommandAtExactMaxLength() {
        let command = String(repeating: "a", count: 9_999)
        XCTAssertNoThrow(try CommandValidator.validateBashCommand(command),
            "Command at 9999 chars should pass")
    }

    // MARK: - Shell Metacharacter Injection

    func testSemicolonInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("ls; rm -rf /"),
            "Semicolon injection should be blocked"
        )
    }

    func testPipeInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("cat file | sh"),
            "Pipe injection should be blocked"
        )
    }

    func testAmpersandInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("harmless && rm -rf /"),
            "Ampersand chaining should be blocked"
        )
    }

    func testBacktickInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("echo `whoami`"),
            "Backtick command substitution should be blocked"
        )
    }

    func testDollarParenSubstitution() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("echo $(id)"),
            "Dollar-paren command substitution should be blocked"
        )
    }

    func testDollarBraceExpansion() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("echo ${HOME}"),
            "Dollar-brace variable expansion should be blocked"
        )
    }

    func testDollarSignEnvironmentVariable() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("echo $PATH"),
            "Dollar sign environment variable should be blocked"
        )
    }

    func testRedirectionOperators() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("echo data > /etc/passwd"),
            "Output redirection should be blocked"
        )

        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("cat < /etc/shadow"),
            "Input redirection should be blocked"
        )
    }

    func testParenthesesSubshell() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("(rm -rf /)"),
            "Parentheses (subshell) should be blocked"
        )
    }

    func testNewlineInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("ls\nrm -rf /"),
            "Newline injection should be blocked"
        )
    }

    func testCarriageReturnInjection() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("ls\rrm -rf /"),
            "Carriage return injection should be blocked"
        )
    }

    // MARK: - Dangerous Pattern Detection (Regex)

    func testRmRfBlocked() {
        // rm -rf should be caught by the dangerous pattern regex
        // but first it'll be caught by metachar filter due to the dash
        // Actually "rm -rf /" has no shell metachars if we consider it plain text
        // But "rm -rf" itself should be caught by the \brm\s+-rf\b pattern
        // The problem: SecurityUtils.validateCommand checks for metachars first
        // "rm -rf /tmp" has no metachars (no ;|&$`<>()newline)
        // So it should pass metachar check but fail pattern check
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("rm -rf /tmp"),
            "rm -rf should be blocked by dangerous pattern"
        ) { error in
            guard case SecurityError.dangerousPattern(let desc) = error else {
                XCTFail("Expected dangerousPattern error, got: \(error)")
                return
            }
            XCTAssertEqual(desc, "rm -rf", "Should identify rm -rf pattern")
        }
    }

    func testSudoBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("sudo ls"),
            "sudo should be blocked"
        ) { error in
            guard case SecurityError.dangerousPattern(let desc) = error else {
                XCTFail("Expected dangerousPattern error, got: \(error)")
                return
            }
            XCTAssertEqual(desc, "sudo")
        }
    }

    func testSuBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("su root"),
            "su should be blocked"
        ) { error in
            guard case SecurityError.dangerousPattern(let desc) = error else {
                XCTFail("Expected dangerousPattern error, got: \(error)")
                return
            }
            XCTAssertEqual(desc, "su")
        }
    }

    func testChmod777Blocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("chmod 777 /tmp/test"),
            "chmod 777 should be blocked"
        ) { error in
            guard case SecurityError.dangerousPattern = error else {
                XCTFail("Expected dangerousPattern error")
                return
            }
        }
    }

    func testEvalBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("eval some_command"),
            "eval should be blocked"
        ) { error in
            guard case SecurityError.dangerousPattern(let desc) = error else {
                XCTFail("Expected dangerousPattern error, got: \(error)")
                return
            }
            XCTAssertEqual(desc, "eval")
        }
    }

    func testExecBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("exec /bin/sh"),
            "exec should be blocked"
        ) { error in
            guard case SecurityError.dangerousPattern(let desc) = error else {
                XCTFail("Expected dangerousPattern error, got: \(error)")
                return
            }
            XCTAssertEqual(desc, "exec")
        }
    }

    // MARK: - Word Boundary Bypass Attempts

    func testRmRfWithoutWordBoundary() {
        // "removal" contains "rm" but is not the rm command
        XCTAssertNoThrow(
            try CommandValidator.validateBashCommand("echo removal"),
            "'removal' should NOT be blocked since 'rm' is not at word boundary"
        )
    }

    func testSudoInsideWordNotBlocked() {
        // "pseudo" contains "sudo" but should not match \bsudo\b
        XCTAssertNoThrow(
            try CommandValidator.validateBashCommand("echo pseudo"),
            "'pseudo' should NOT be blocked since 'sudo' is not at word boundary"
        )
    }

    func testEvalInsideWordNotBlocked() {
        // "evaluate" starts with "eval" -- depends on regex word boundary
        // \beval\b should NOT match "evaluate" because the 'u' follows
        XCTAssertNoThrow(
            try CommandValidator.validateBashCommand("echo evaluate"),
            "'evaluate' should NOT be blocked since 'eval' is not at word boundary"
        )
    }

    func testExecInsideWordNotBlocked() {
        // "executable" starts with "exec" -- \bexec\b should NOT match
        XCTAssertNoThrow(
            try CommandValidator.validateBashCommand("echo executable"),
            "'executable' should NOT be blocked since 'exec' is not at word boundary"
        )
    }

    // MARK: - Whitelist Validation

    func testWhitelistAllowsMatchingCommands() throws {
        let allowedCommands = ["ls", "pwd", "cat", "git"]
        let result = try CommandValidator.validateBashCommandWhitelist("ls", allowedCommands: allowedCommands)
        XCTAssertEqual(result, "ls")
    }

    func testWhitelistBlocksNonMatchingCommands() {
        let allowedCommands = ["ls", "pwd", "cat"]
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommandWhitelist("rm stuff", allowedCommands: allowedCommands)
        ) { error in
            guard case SecurityError.commandNotWhitelisted(let cmd) = error else {
                XCTFail("Expected commandNotWhitelisted error, got: \(error)")
                return
            }
            XCTAssertEqual(cmd, "rm")
        }
    }

    func testWhitelistEmptyCommand() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommandWhitelist("", allowedCommands: ["ls"])
        ) { error in
            // Could be emptyCommand or commandLength depending on order
            guard error is SecurityError else {
                XCTFail("Expected SecurityError")
                return
            }
        }
    }

    // MARK: - Python Command Validation

    func testSafePythonPasses() throws {
        let safeCode = """
        import numpy as np
        data = np.array([1, 2, 3])
        result = np.mean(data)
        print(result)
        """
        XCTAssertNoThrow(try CommandValidator.validatePythonCommand(safeCode))
    }

    func testDangerousPythonImportOs() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("import os\nos.system('rm -rf /')"),
            "import os should be blocked"
        ) { error in
            guard case SecurityError.dangerousImport = error else {
                XCTFail("Expected dangerousImport error, got: \(error)")
                return
            }
        }
    }

    func testDangerousPythonImportSubprocess() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("import subprocess\nsubprocess.call(['rm', '-rf', '/'])"),
            "import subprocess should be blocked"
        )
    }

    func testDangerousPythonPickle() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("import pickle\npickle.loads(data)"),
            "pickle should be blocked"
        )
    }

    func testDangerousPythonDunderImport() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("__import__('os').system('whoami')"),
            "__import__ should be blocked"
        )
    }

    func testDangerousPythonEval() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("result = eval('1+1')"),
            "eval() should be blocked"
        )
    }

    func testDangerousPythonExec() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("exec('import os')"),
            "exec() should be blocked"
        )
    }

    func testDangerousPythonOpen() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("f = open('/etc/passwd', 'r')"),
            "open() should be blocked"
        )
    }

    func testPythonCommentedImportAllowed() {
        // Imports in comments should be allowed
        let code = """
        # import os  -- this is just a comment
        # import subprocess
        import numpy as np
        data = np.array([1, 2, 3])
        """
        XCTAssertNoThrow(try CommandValidator.validatePythonCommand(code),
            "Commented-out dangerous imports should not be blocked")
    }

    func testPythonFromOsImportBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("from os import path"),
            "from os import should be blocked"
        )
    }

    func testPythonFromSubprocessImportBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("from subprocess import run"),
            "from subprocess import should be blocked"
        )
    }

    func testPythonOsDotAccessBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("os.environ['HOME']"),
            "os. access should be blocked"
        )
    }

    func testPythonSysDotAccessBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("sys.exit(1)"),
            "sys. access should be blocked"
        )
    }

    func testPythonEmptyCodeRejected() {
        XCTAssertThrowsError(try CommandValidator.validatePythonCommand("")) { error in
            guard case SecurityError.codeLength = error else {
                XCTFail("Expected codeLength error")
                return
            }
        }
    }

    func testPythonExcessivelyLongCodeRejected() {
        let longCode = String(repeating: "x = 1\n", count: 10000)
        XCTAssertThrowsError(try CommandValidator.validatePythonCommand(longCode)) { error in
            guard case SecurityError.codeLength = error else {
                XCTFail("Expected codeLength error")
                return
            }
        }
    }

    func testPythonTorchLoadBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("model = torch.load('model.pt')"),
            "torch.load() should be blocked (arbitrary code execution via pickle)"
        )
    }

    func testPythonCompileBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("code = compile('print(1)', '<string>', 'exec')"),
            "compile() should be blocked"
        )
    }

    func testPythonInputBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validatePythonCommand("name = input('Enter name: ')"),
            "input() should be blocked (blocks execution, potential injection)"
        )
    }

    // MARK: - URL Validation (SSRF Prevention)

    func testSafeURLsPass() throws {
        let safeURLs = [
            "https://github.com/kochj23/MLXCode",
            "https://api.github.com/repos",
            "https://example.com/path?query=value",
        ]

        for url in safeURLs {
            XCTAssertNoThrow(
                try CommandValidator.validateSafeURL(url),
                "Safe URL should pass: \(url)"
            )
        }
    }

    func testPrivateIPBlockedSSRF() {
        let privateIPs = [
            "https://10.0.0.1/admin",
            "https://192.168.1.1/router",
            "https://172.16.0.1/internal",
            "https://127.0.0.1/localhost",
            "https://169.254.1.1/metadata",
        ]

        for url in privateIPs {
            XCTAssertThrowsError(
                try CommandValidator.validateSafeURL(url),
                "Private IP should be blocked: \(url)"
            )
        }
    }

    func testLocalhostBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateSafeURL("https://localhost/secret"),
            "localhost should be blocked"
        )
    }

    func testInvalidURLRejected() {
        XCTAssertThrowsError(
            try CommandValidator.validateSafeURL("not a url at all"),
            "Invalid URL should be rejected"
        )
    }

    // MARK: - Adversarial Inputs: Case Variation

    func testSudoUppercaseStillBlocked() {
        // The regex uses caseInsensitive option
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("SUDO ls"),
            "SUDO (uppercase) should still be blocked"
        )
    }

    func testSudoMixedCaseStillBlocked() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("SuDo ls"),
            "SuDo (mixed case) should still be blocked"
        )
    }

    // MARK: - Adversarial: Padding / Obfuscation

    func testRmRfWithExtraSpaces() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("rm  -rf   /tmp"),
            "rm  -rf with extra spaces should still match \\brm\\s+-rf\\b"
        )
    }

    func testRmRfWithTab() {
        XCTAssertThrowsError(
            try CommandValidator.validateBashCommand("rm\t-rf /tmp"),
            "rm<tab>-rf should still match \\brm\\s+-rf\\b"
        )
    }

    // MARK: - SecurityUtils Direct Tests

    func testValidateCommandRejectsMetachars() {
        let metachars: [String] = [
            "cmd; evil",
            "cmd | evil",
            "cmd & evil",
            "cmd $ evil",
            "cmd ` evil",
            "cmd ( evil",
            "cmd ) evil",
            "cmd < evil",
            "cmd > evil",
        ]

        for cmd in metachars {
            XCTAssertFalse(SecurityUtils.validateCommand(cmd),
                "Metachar should be rejected: \(cmd)")
        }
    }

    func testValidateCommandAcceptsCleanInput() {
        let cleanCommands = [
            "ls",
            "git status",
            "swift build -c release",
            "xcodebuild -scheme MyApp",
            "cat file.txt",
            "grep -r pattern .",
        ]

        for cmd in cleanCommands {
            XCTAssertTrue(SecurityUtils.validateCommand(cmd),
                "Clean command should be accepted: \(cmd)")
        }
    }

    func testValidateCommandRejectsEmpty() {
        XCTAssertFalse(SecurityUtils.validateCommand(""),
            "Empty command should be rejected")
        XCTAssertFalse(SecurityUtils.validateCommand("   "),
            "Whitespace-only command should be rejected")
    }

    // MARK: - Error Type Verification

    func testSecurityErrorDescriptionsAreHelpful() {
        let errors: [SecurityError] = [
            .commandLength(999),
            .codeLength(60000),
            .dangerousCharacters("test"),
            .dangerousPattern("rm -rf"),
            .dangerousImport("import os"),
            .dangerousFunction("eval()"),
            .systemManipulation,
            .commandNotWhitelisted("curl"),
            .emptyCommand,
            .invalidPath("/bad"),
            .fileNotFound("/missing"),
            .invalidFileType("not .py"),
            .unsafeScript("danger"),
            .invalidURL("bad url"),
            .privateIPBlocked("10.0.0.1"),
            .localhostBlocked,
        ]

        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error should have a description: \(error)")
            XCTAssertFalse(description!.isEmpty, "Error description should not be empty: \(error)")
        }
    }

    // MARK: - Performance

    func testValidationPerformance() {
        let command = "git log --oneline --graph"
        measure {
            for _ in 0..<1000 {
                _ = try? CommandValidator.validateBashCommand(command)
            }
        }
    }

    func testPythonValidationPerformance() {
        let code = """
        import numpy as np
        import mlx.core as mx
        data = np.random.randn(100, 100)
        result = mx.array(data)
        print(result.shape)
        """
        measure {
            for _ in 0..<1000 {
                _ = try? CommandValidator.validatePythonCommand(code)
            }
        }
    }
}
