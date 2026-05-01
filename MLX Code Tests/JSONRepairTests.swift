//
//  JSONRepairTests.swift
//  MLX Code Tests
//
//  Tests for tool-call JSON parsing and auto-repair logic.
//  Local LLMs frequently produce malformed JSON; the repair
//  pipeline in ToolRegistry must handle these gracefully.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class JSONRepairTests: XCTestCase {

    private var registry: ToolRegistry!

    override func setUp() {
        super.setUp()
        registry = ToolRegistry.shared
    }

    // MARK: - Well-Formed JSON (Baseline)

    func testValidJSONParsesCorrectly() {
        let json = #"{"name": "bash", "args": {"command": "ls -la"}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Valid JSON should parse successfully")
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "ls -la")
    }

    func testValidJSONWithParametersKey() {
        let json = #"{"name": "grep", "parameters": {"pattern": "TODO", "path": "."}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "JSON with 'parameters' key should parse")
        XCTAssertEqual(result?.name, "grep")
        XCTAssertEqual(result?.parameters["pattern"] as? String, "TODO")
    }

    func testValidJSONWithNoArgs() {
        let json = #"{"name": "help"}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "JSON with no args should parse")
        XCTAssertEqual(result?.name, "help")
        XCTAssertTrue(result?.parameters.isEmpty ?? false, "Parameters should be empty")
    }

    func testValidJSONWithEmptyArgs() {
        let json = #"{"name": "help", "args": {}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "JSON with empty args should parse")
        XCTAssertEqual(result?.name, "help")
        XCTAssertTrue(result?.parameters.isEmpty ?? false)
    }

    func testValidJSONWithIntegerArg() {
        let json = #"{"name": "grep", "args": {"pattern": "error", "max_results": 10}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "grep")
        // Int values are converted to String by parseToolCallJSON
        XCTAssertEqual(result?.parameters["max_results"] as? String, "10")
    }

    func testValidJSONWithBooleanArg() {
        let json = #"{"name": "grep", "args": {"pattern": "TODO", "case_sensitive": true}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.parameters["case_sensitive"] as? String, "true")
    }

    // MARK: - Single Quotes (Common LLM Mistake)

    func testSingleQuotedKeysAndValues() {
        let json = "{'name': 'bash', 'args': {'command': 'echo hello'}}"
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Single-quoted JSON should be repaired and parsed")
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "echo hello")
    }

    func testMixedSingleAndDoubleQuotes() {
        let json = #"{"name": 'file_operations', "args": {'operation': "read", 'path': "main.swift"}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Mixed quotes should be repaired")
        XCTAssertEqual(result?.name, "file_operations")
        XCTAssertEqual(result?.parameters["operation"] as? String, "read")
        XCTAssertEqual(result?.parameters["path"] as? String, "main.swift")
    }

    // MARK: - Trailing Commas

    func testTrailingCommaInArgs() {
        let json = #"{"name": "bash", "args": {"command": "pwd",}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Trailing comma before } should be repaired")
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "pwd")
    }

    func testTrailingCommaAtTopLevel() {
        let json = #"{"name": "bash", "args": {"command": "ls"},}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Trailing comma at top level should be repaired")
        XCTAssertEqual(result?.name, "bash")
    }

    func testMultipleTrailingCommas() {
        let json = #"{"name": "grep", "args": {"pattern": "TODO", "path": ".",},}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Multiple trailing commas should be repaired")
        XCTAssertEqual(result?.name, "grep")
    }

    func testTrailingCommaWithWhitespace() {
        let json = """
        {"name": "bash", "args": {"command": "ls" ,  }}
        """
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Trailing comma with whitespace should be repaired")
        XCTAssertEqual(result?.name, "bash")
    }

    // MARK: - Combined Repair (Single Quotes + Trailing Commas)

    func testSingleQuotesAndTrailingCommas() {
        let json = "{'name': 'bash', 'args': {'command': 'whoami',},}"
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Combined single quotes and trailing commas should be repaired")
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "whoami")
    }

    // MARK: - Whitespace and Formatting Issues

    func testExcessiveWhitespace() {
        let json = """
        {
            "name"  :  "bash" ,
            "args"  :  {
                "command"  :  "ls"
            }
        }
        """
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Excessive whitespace should be handled")
        XCTAssertEqual(result?.name, "bash")
    }

    func testLeadingAndTrailingWhitespace() {
        let json = "   \n\t{\"name\": \"bash\", \"args\": {\"command\": \"pwd\"}}  \n  "
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Leading/trailing whitespace should be trimmed")
        XCTAssertEqual(result?.name, "bash")
    }

    // MARK: - Missing Name Field

    func testMissingNameField() {
        let json = #"{"args": {"command": "ls"}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNil(result, "JSON without 'name' field should fail gracefully")
    }

    func testEmptyNameField() {
        let json = #"{"name": "", "args": {"command": "ls"}}"#
        let result = registry.parseToolCallJSON(json)

        // Empty string is still a string, so it parses but name is empty
        // Behavior depends on implementation -- either nil or empty name
        if let result = result {
            XCTAssertEqual(result.name, "", "Empty name should be preserved as-is")
        }
        // Both nil and empty-name results are acceptable
    }

    // MARK: - Completely Invalid Input

    func testEmptyString() {
        let result = registry.parseToolCallJSON("")

        XCTAssertNil(result, "Empty string should return nil")
    }

    func testPlainTextInput() {
        let result = registry.parseToolCallJSON("This is not JSON at all")

        XCTAssertNil(result, "Plain text should return nil")
    }

    func testRandomGarbage() {
        let result = registry.parseToolCallJSON("}{{{][]][")

        XCTAssertNil(result, "Random brackets should return nil")
    }

    func testJSONArray() {
        let result = registry.parseToolCallJSON("[1, 2, 3]")

        XCTAssertNil(result, "JSON array should return nil (expected object)")
    }

    // MARK: - Edge Cases with String Content

    func testArgsContainingJSONInValue() {
        // Model wants to write a JSON file -- the value itself contains JSON
        let json = #"{"name": "file_operations", "args": {"operation": "write", "path": "config.json", "content": "{\"key\": \"value\"}"}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "JSON within a string value should parse")
        XCTAssertEqual(result?.name, "file_operations")
        XCTAssertEqual(result?.parameters["operation"] as? String, "write")
    }

    func testArgsContainingNewlines() {
        let json = #"{"name": "file_operations", "args": {"operation": "write", "path": "test.swift", "content": "import Foundation\nprint(\"hello\")"}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Newlines in string values should parse")
        XCTAssertEqual(result?.name, "file_operations")
    }

    func testArgsContainingEscapedQuotes() {
        let json = #"{"name": "bash", "args": {"command": "echo \"hello world\""}}"#
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Escaped quotes in values should parse")
        XCTAssertEqual(result?.name, "bash")
    }

    // MARK: - Legacy Format Fallback

    func testLegacyFormatFallback() {
        // When JSON parse fails completely, it should fall back to legacy tool_name(key=value) parsing
        let legacy = #"bash(command="ls -la")"#
        let result = registry.parseToolCallJSON(legacy)

        XCTAssertNotNil(result, "Legacy format should be parsed as fallback")
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "ls -la")
    }

    func testLegacyFormatWithMultipleParams() {
        let legacy = #"grep(pattern="TODO", path=".", file_pattern="*.swift")"#
        let result = registry.parseToolCallJSON(legacy)

        XCTAssertNotNil(result, "Legacy format with multiple params should parse")
        XCTAssertEqual(result?.name, "grep")
        XCTAssertEqual(result?.parameters["pattern"] as? String, "TODO")
    }

    // MARK: - Multiline Tool Calls (Common from LLMs)

    func testMultilineJSON() {
        let json = """
        {
          "name": "file_operations",
          "args": {
            "operation": "read",
            "path": "/Users/test/main.swift"
          }
        }
        """
        let result = registry.parseToolCallJSON(json)

        XCTAssertNotNil(result, "Multiline JSON should parse")
        XCTAssertEqual(result?.name, "file_operations")
        XCTAssertEqual(result?.parameters["operation"] as? String, "read")
    }

    // MARK: - Performance

    func testRepairPerformanceWithManyTrailingCommas() {
        // Create JSON with many trailing commas to test regex performance
        var json = #"{"name": "bash", "args": {"command": "ls""#
        for _ in 0..<50 {
            json += ","
        }
        json += "}}"

        measure {
            for _ in 0..<100 {
                _ = registry.parseToolCallJSON(json)
            }
        }
    }
}
