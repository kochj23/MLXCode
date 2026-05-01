//
//  BuildErrorParserTests.swift
//  MLX Code Tests
//
//  Unit tests for BuildErrorParser: parsing xcodebuild output,
//  categorization, suggestions, and summary generation.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class BuildErrorParserTests: XCTestCase {

    // MARK: - Error Parsing

    func testParseSwiftError() {
        let output = "/path/to/File.swift:42:10: error: cannot find 'foo' in scope"
        let issues = BuildErrorParser.parse(output)

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .error)
        XCTAssertEqual(issues.first?.filePath, "/path/to/File.swift")
        XCTAssertEqual(issues.first?.line, 42)
        XCTAssertEqual(issues.first?.column, 10)
        XCTAssertTrue(issues.first?.message.contains("cannot find") ?? false)
    }

    func testParseSwiftWarning() {
        let output = "/path/to/File.swift:10:5: warning: variable 'x' was never used"
        let issues = BuildErrorParser.parse(output)

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .warning)
        XCTAssertEqual(issues.first?.line, 10)
    }

    func testParseNote() {
        let output = "/path/to/File.swift:10:5: note: did you mean 'bar'?"
        let issues = BuildErrorParser.parse(output)

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .note)
    }

    func testParseMultipleIssues() {
        let output = """
        /A.swift:1:1: error: missing return
        /B.swift:5:3: warning: unused variable
        /C.swift:10:1: error: type mismatch
        """
        let issues = BuildErrorParser.parse(output)

        XCTAssertEqual(issues.filter { $0.severity == .error }.count, 2)
        XCTAssertEqual(issues.filter { $0.severity == .warning }.count, 1)
    }

    func testParseEmptyOutput() {
        let issues = BuildErrorParser.parse("")
        XCTAssertTrue(issues.isEmpty, "Empty output should produce no issues")
    }

    func testParseCleanBuildOutput() {
        let output = """
        Build settings from command line:
            TOOLCHAIN_DIR = /Applications/Xcode.app/Contents/Developer
        ** BUILD SUCCEEDED **
        """
        let issues = BuildErrorParser.parse(output)
        XCTAssertTrue(issues.isEmpty, "Clean build output should produce no issues")
    }

    // MARK: - Suggestions

    func testSuggestionForCannotFindInScope() {
        let output = "/A.swift:1:1: error: cannot find 'MyType' in scope"
        let issues = BuildErrorParser.parse(output)
        XCTAssertNotNil(issues.first?.suggestion, "Should suggest a fix for 'cannot find in scope'")
    }

    func testSuggestionForProtocolConformance() {
        let output = "/A.swift:1:1: error: type 'Foo' does not conform to protocol 'Bar'"
        let issues = BuildErrorParser.parse(output)
        XCTAssertNotNil(issues.first?.suggestion)
        XCTAssertTrue(issues.first!.suggestion!.contains("protocol"), "Suggestion should mention protocol")
    }

    func testSuggestionForUnusedVariable() {
        let output = "/A.swift:1:1: warning: variable 'x' was never used"
        let issues = BuildErrorParser.parse(output)
        XCTAssertNotNil(issues.first?.suggestion)
    }

    func testSuggestionForMissingReturn() {
        let output = "/A.swift:1:1: error: missing return in function"
        let issues = BuildErrorParser.parse(output)
        XCTAssertNotNil(issues.first?.suggestion)
    }

    func testSuggestionForNoSuchModule() {
        let output = "/A.swift:1:1: error: no such module 'MyFramework'"
        let issues = BuildErrorParser.parse(output)
        XCTAssertNotNil(issues.first?.suggestion)
    }

    // MARK: - Categorization

    func testCategorizationLinkerError() {
        let issue = BuildIssue(
            id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
            message: "undefined symbol: _main", notes: [], suggestion: nil
        )
        let categorized = BuildErrorParser.categorize([issue])
        XCTAssertNotNil(categorized[.linker])
    }

    func testCategorizationTypeError() {
        let issue = BuildIssue(
            id: UUID(), severity: .error, filePath: "/A.swift", line: 1, column: 1,
            message: "cannot convert value of type 'Int' to 'String'", notes: [], suggestion: nil
        )
        let categorized = BuildErrorParser.categorize([issue])
        XCTAssertNotNil(categorized[.type])
    }

    func testCategorizationUnusedWarning() {
        let issue = BuildIssue(
            id: UUID(), severity: .warning, filePath: "/A.swift", line: 1, column: 1,
            message: "variable 'x' was never used", notes: [], suggestion: nil
        )
        let categorized = BuildErrorParser.categorize([issue])
        XCTAssertNotNil(categorized[.unused])
    }

    // MARK: - Summary

    func testSummaryWithNoIssues() {
        let summary = BuildErrorParser.generateSummary([])
        XCTAssertTrue(summary.contains("succeeded"), "No issues should show success")
    }

    func testSummaryWithErrors() {
        let issues = [
            BuildIssue(id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
                       message: "err", notes: [], suggestion: nil)
        ]
        let summary = BuildErrorParser.generateSummary(issues)
        XCTAssertTrue(summary.contains("1 error"))
    }

    func testSummaryWithMixedIssues() {
        let issues = [
            BuildIssue(id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
                       message: "err", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .warning, filePath: nil, line: nil, column: nil,
                       message: "warn", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .warning, filePath: nil, line: nil, column: nil,
                       message: "warn2", notes: [], suggestion: nil),
        ]
        let summary = BuildErrorParser.generateSummary(issues)
        XCTAssertTrue(summary.contains("1 error"))
        XCTAssertTrue(summary.contains("2 warnings"))
    }

    // MARK: - BuildIssue Helpers

    func testLocationString() {
        let issue = BuildIssue(
            id: UUID(), severity: .error, filePath: "/path/to/File.swift",
            line: 42, column: 10, message: "err", notes: [], suggestion: nil
        )
        XCTAssertEqual(issue.location, "File.swift:42:10")
    }

    func testLocationStringNoFile() {
        let issue = BuildIssue(
            id: UUID(), severity: .error, filePath: nil,
            line: nil, column: nil, message: "err", notes: [], suggestion: nil
        )
        XCTAssertEqual(issue.location, "")
    }

    func testIssueIcon() {
        XCTAssertEqual(
            BuildIssue(id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
                       message: "", notes: [], suggestion: nil).icon,
            "⛔"
        )
        XCTAssertEqual(
            BuildIssue(id: UUID(), severity: .warning, filePath: nil, line: nil, column: nil,
                       message: "", notes: [], suggestion: nil).icon,
            "⚠️"
        )
    }

    // MARK: - Array Extensions

    func testArrayExtensionCounts() {
        let issues = [
            BuildIssue(id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
                       message: "e1", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .error, filePath: nil, line: nil, column: nil,
                       message: "e2", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .warning, filePath: nil, line: nil, column: nil,
                       message: "w1", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .note, filePath: nil, line: nil, column: nil,
                       message: "n1", notes: [], suggestion: nil),
        ]
        XCTAssertEqual(issues.errorCount, 2)
        XCTAssertEqual(issues.warningCount, 1)
        XCTAssertEqual(issues.noteCount, 1)
        XCTAssertTrue(issues.hasErrors)
        XCTAssertTrue(issues.hasWarnings)
    }

    func testGroupByFile() {
        let issues = [
            BuildIssue(id: UUID(), severity: .error, filePath: "/A.swift", line: 1, column: 1,
                       message: "err", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .error, filePath: "/A.swift", line: 2, column: 1,
                       message: "err2", notes: [], suggestion: nil),
            BuildIssue(id: UUID(), severity: .warning, filePath: "/B.swift", line: 1, column: 1,
                       message: "warn", notes: [], suggestion: nil),
        ]
        let grouped = issues.groupedByFile()
        XCTAssertEqual(grouped["/A.swift"]?.count, 2)
        XCTAssertEqual(grouped["/B.swift"]?.count, 1)
    }
}
