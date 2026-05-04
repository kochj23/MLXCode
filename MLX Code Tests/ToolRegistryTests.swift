//
//  ToolRegistryTests.swift
//  MLX Code Tests
//
//  Integration tests for ToolRegistry: tool registration, lookup,
//  JSON/legacy tool call parsing, execution history, and tool descriptions.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class ToolRegistryTests: XCTestCase {

    private var registry: ToolRegistry!

    override func setUp() {
        super.setUp()
        registry = ToolRegistry.shared
    }

    // MARK: - Registration

    func testBuiltInToolsRegistered() {
        let tools = registry.getAllTools()
        XCTAssertGreaterThan(tools.count, 5,
            "ToolRegistry should register multiple built-in tools at init")
    }

    func testExpectedToolsExist() {
        let expectedNames = ["bash", "file_operations", "grep", "glob", "xcode"]
        for name in expectedNames {
            XCTAssertNotNil(registry.getTool(name),
                "Built-in tool '\(name)' should be registered")
        }
    }

    func testGetToolReturnsNilForUnknown() {
        XCTAssertNil(registry.getTool("nonexistent_tool_xyz"),
            "Unknown tool name should return nil")
    }

    // MARK: - Tool Descriptions for LLM

    func testGenerateToolDescriptionsNotEmpty() {
        let descriptions = registry.generateToolDescriptions()
        XCTAssertFalse(descriptions.isEmpty, "Tool descriptions should not be empty")
        XCTAssertTrue(descriptions.contains("Available Tools"),
            "Description should contain header")
    }

    func testToolDescriptionsIncludeAllTools() {
        let descriptions = registry.generateToolDescriptions()
        let tools = registry.getAllTools()
        for tool in tools {
            XCTAssertTrue(descriptions.contains(tool.name),
                "Descriptions should mention tool: \(tool.name)")
        }
    }

    // MARK: - Execution History

    func testInitialHistoryEmpty() {
        registry.clearHistory()
        XCTAssertTrue(registry.executionHistory.isEmpty,
            "Execution history should be empty after clearing")
    }

    func testRecentExecutionsRespectsCount() {
        registry.clearHistory()
        let recent = registry.getRecentExecutions(count: 5)
        XCTAssertEqual(recent.count, 0, "No recent executions when history is empty")
    }

    // MARK: - JSON Tool Call Parsing (Delegation)

    func testParseToolCallJSONBasic() {
        let json = #"{"name": "bash", "args": {"command": "ls"}}"#
        let result = registry.parseToolCallJSON(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "bash")
        XCTAssertEqual(result?.parameters["command"] as? String, "ls")
    }

    func testParseToolCallJSONInvalidReturnsNil() {
        XCTAssertNil(registry.parseToolCallJSON("garbage text {{{"),
            "Invalid JSON with no legacy format should return nil")
    }

    // MARK: - ToolResult Helpers

    func testToolResultSuccess() {
        let result = ToolResult.success("output text", metadata: ["key": "value"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output as? String, "output text")
        XCTAssertNil(result.error)
        XCTAssertEqual(result.metadata["key"] as? String, "value")
    }

    func testToolResultFailure() {
        let result = ToolResult.failure("something went wrong")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "something went wrong")
    }

    func testToolResultToJSON() {
        let result = ToolResult.success("hello")
        let json = result.toJSON()
        XCTAssertFalse(json.isEmpty, "JSON output should not be empty")
        XCTAssertTrue(json.contains("success"), "JSON should contain success key")
    }

    // MARK: - ToolError Descriptions

    func testToolErrorDescriptions() {
        let errors: [ToolError] = [
            .missingParameter("command"),
            .invalidParameterType("count", expected: "Int"),
            .executionFailed("timeout"),
            .notFound("my_tool"),
            .permissionDenied("/etc/passwd"),
            .invalidPath("/bad\0path"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                "ToolError should have a description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - ToolContext

    func testToolContextDefaults() {
        let context = ToolContext(settings: AppSettings.shared)
        XCTAssertFalse(context.workingDirectory.isEmpty,
            "Default working directory should not be empty")
        XCTAssertTrue(context.conversationHistory.isEmpty)
        XCTAssertNil(context.projectPath)
    }

    func testToolContextWithParameters() {
        let messages = [Message.user("Hello"), Message.assistant("Hi")]
        let context = ToolContext(
            workingDirectory: "/tmp",
            conversationHistory: messages,
            projectPath: "/Volumes/Data/xcode/MLX Code",
            settings: AppSettings.shared
        )
        XCTAssertEqual(context.workingDirectory, "/tmp")
        XCTAssertEqual(context.conversationHistory.count, 2)
        XCTAssertEqual(context.projectPath, "/Volumes/Data/xcode/MLX Code")
    }

    // MARK: - ToolExecutionSummary

    func testToolExecutionSummaryFormatting() {
        let summary = ToolExecutionSummary(
            toolName: "bash",
            parameters: ["command": "ls"],
            success: true,
            duration: 0.123,
            timestamp: Date(),
            error: nil
        )
        XCTAssertEqual(summary.durationMs, 123)
        XCTAssertTrue(summary.summary.contains("bash"))
        XCTAssertTrue(summary.summary.contains("123ms"))
        XCTAssertTrue(summary.detailedSummary.contains("Parameters"))
    }

    func testToolExecutionSummaryFailure() {
        let summary = ToolExecutionSummary(
            toolName: "bash",
            parameters: [:],
            success: false,
            duration: 0.5,
            timestamp: Date(),
            error: "command not found"
        )
        XCTAssertTrue(summary.detailedSummary.contains("command not found"))
    }
}
