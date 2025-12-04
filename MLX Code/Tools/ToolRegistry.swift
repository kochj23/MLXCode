//
//  ToolRegistry.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Central registry and dispatcher for all tools
@MainActor
class ToolRegistry: ObservableObject {
    /// Shared instance
    static let shared = ToolRegistry()

    /// Registered tools
    private var tools: [String: Tool] = [:]

    /// Memory system
    let memory = MemorySystem.shared

    /// Tool execution history
    @Published var executionHistory: [ToolExecutionSummary] = []

    private init() {
        registerBuiltInTools()
    }

    // MARK: - Tool Registration

    /// Register built-in tools
    private func registerBuiltInTools() {
        // Core tools
        register(FileOperationsTool())
        register(BashTool())
        register(GrepTool())
        register(GlobTool())
        register(XcodeTool())

        // Advanced development tools (Batch 1)
        register(ErrorDiagnosisTool())
        register(TestGenerationTool())
        register(CodeNavigationTool())
        register(GitIntegrationTool())
        register(RefactoringTool())
        register(DocumentationTool())
        register(DependencyManagementTool())
        register(SimulatorManagementTool())
        register(AssetManagementTool())
        register(SchemeManagementTool())

        // Claude Code Advanced Features (Batch 2)
        register(MCPServerTool())
        register(DiffPreviewTool())
        register(ContextMemoryTool())
        register(DebuggerTool())
        register(CodeReviewTool())
        register(CodeCompletionTool())
        register(TemplateGenerationTool())
        register(TaskPlanningTool())
        register(WorkspaceAnalysisTool())
        register(CollaborationTool())
        register(ProfilingTool())
        register(RegressionTestingTool())
        register(SecurityScanningTool())
        register(CICDTool())
        register(NL2CodeTool())

        // Help System
        register(HelpTool())

        logInfo("Registered \(tools.count) built-in tools", category: "ToolRegistry")
    }

    /// Register a tool
    func register(_ tool: Tool) {
        tools[tool.name] = tool
        logInfo("Registered tool: \(tool.name)", category: "ToolRegistry")
    }

    /// Unregister a tool
    func unregister(_ toolName: String) {
        tools.removeValue(forKey: toolName)
        logInfo("Unregistered tool: \(toolName)", category: "ToolRegistry")
    }

    /// Get all registered tools
    func getAllTools() -> [Tool] {
        return Array(tools.values)
    }

    /// Get tool by name
    func getTool(_ name: String) -> Tool? {
        return tools[name]
    }

    // MARK: - Tool Execution

    /// Execute a tool by name
    func executeTool(
        name: String,
        parameters: [String: Any],
        context: ToolContext
    ) async throws -> ToolResult {
        guard let tool = tools[name] else {
            throw ToolError.notFound("Tool not found: \(name)")
        }

        logInfo("Executing tool: \(name)", category: "ToolRegistry")

        let startTime = Date()

        do {
            // Execute tool
            let result = try await tool.execute(parameters: parameters, context: context)

            // Record execution
            let duration = Date().timeIntervalSince(startTime)
            recordExecution(
                toolName: name,
                parameters: parameters,
                result: result,
                duration: duration
            )

            return result

        } catch {
            // Record failed execution
            let duration = Date().timeIntervalSince(startTime)
            let failureResult = ToolResult.failure(error.localizedDescription)

            recordExecution(
                toolName: name,
                parameters: parameters,
                result: failureResult,
                duration: duration
            )

            throw error
        }
    }

    /// Parse and execute tool call from LLM output
    func parseAndExecuteToolCall(
        _ toolCallText: String,
        context: ToolContext
    ) async throws -> ToolResult {
        // Parse tool call format: tool_name(param1=value1, param2=value2)
        guard let (toolName, parameters) = parseToolCall(toolCallText) else {
            throw ToolError.executionFailed("Invalid tool call format: \(toolCallText)")
        }

        return try await executeTool(name: toolName, parameters: parameters, context: context)
    }

    // MARK: - Tool Call Parsing

    /// Parse tool call string into name and parameters
    private func parseToolCall(_ text: String) -> (name: String, parameters: [String: Any])? {
        // Format: tool_name(param1=value1, param2="value2")
        let pattern = #"(\w+)\((.*?)\)"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        // Extract tool name
        guard let nameRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let toolName = String(text[nameRange])

        // Extract parameters
        var parameters: [String: Any] = [:]

        if let paramsRange = Range(match.range(at: 2), in: text) {
            let paramsText = String(text[paramsRange])

            // Parse key=value pairs
            let paramPairs = paramsText.components(separatedBy: ",")
            for pair in paramPairs {
                let trimmed = pair.trimmingCharacters(in: .whitespaces)
                let components = trimmed.components(separatedBy: "=")

                if components.count == 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                    var value = components[1].trimmingCharacters(in: .whitespaces)

                    // Remove quotes
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }

                    parameters[key] = value
                }
            }
        }

        return (toolName, parameters)
    }

    // MARK: - Execution History

    /// Record tool execution
    private func recordExecution(
        toolName: String,
        parameters: [String: Any],
        result: ToolResult,
        duration: TimeInterval
    ) {
        let summary = ToolExecutionSummary(
            toolName: toolName,
            parameters: parameters,
            success: result.success,
            duration: duration,
            timestamp: Date(),
            error: result.error
        )

        executionHistory.append(summary)

        // Keep only last 100 executions
        if executionHistory.count > 100 {
            executionHistory.removeFirst()
        }

        // Also record in memory system
        memory.recordToolExecution(toolName, parameters: parameters, result: result, duration: duration)
    }

    /// Get recent executions
    func getRecentExecutions(count: Int = 10) -> [ToolExecutionSummary] {
        return Array(executionHistory.suffix(count))
    }

    /// Clear execution history
    func clearHistory() {
        executionHistory.removeAll()
        logInfo("Cleared tool execution history", category: "ToolRegistry")
    }

    // MARK: - Tool Descriptions for LLM

    /// Generate tool descriptions for LLM prompt
    func generateToolDescriptions() -> String {
        var descriptions: [String] = []

        descriptions.append("# Available Tools\n")
        descriptions.append("You have access to the following tools to help with coding tasks:\n")

        for tool in tools.values.sorted(by: { $0.name < $1.name }) {
            descriptions.append("\n## \(tool.name)")
            descriptions.append(tool.description)
            descriptions.append("\nParameters:")

            for (paramName, paramDef) in tool.parameters.properties.sorted(by: { $0.key < $1.key }) {
                let required = tool.parameters.required.contains(paramName) ? " (required)" : ""
                descriptions.append("  - \(paramName)\(required): \(paramDef.description)")
            }

            descriptions.append("\nExample usage:")
            descriptions.append("  \(tool.name)(...)")
        }

        return descriptions.joined(separator: "\n")
    }

    /// Generate tool usage examples
    func generateToolExamples() -> String {
        var examples: [String] = []

        examples.append("\n# Tool Usage Examples\n")

        // File operations example
        examples.append("""
        ## Reading a file:
        To read a Swift file:
        file_operations(operation=read, path="ContentView.swift")

        ## Writing a file:
        To create or update a file:
        file_operations(operation=write, path="NewView.swift", content="import SwiftUI\\n\\nstruct NewView: View { }")

        ## Editing a file:
        To replace text in a file:
        file_operations(operation=edit, path="ViewModel.swift", old_string="oldFunction", new_string="newFunction")
        """)

        // Bash example
        examples.append("""
        \n## Running commands:
        To run a shell command:
        bash(command="ls -la")

        To run git commands:
        bash(command="git status")
        """)

        // Search examples
        examples.append("""
        \n## Searching code:
        To find all Swift files:
        glob(pattern="**/*.swift")

        To search for a function:
        grep(pattern="func generateResponse", file_pattern="*.swift")
        """)

        // Xcode examples
        examples.append("""
        \n## Building with Xcode:
        To build the project:
        xcode(operation=build, scheme="MLX Code")

        To run tests:
        xcode(operation=test, scheme="MLX Code")

        To clean build:
        xcode(operation=clean)
        """)

        return examples.joined(separator: "\n")
    }
}

/// Summary of tool execution
struct ToolExecutionSummary: Identifiable {
    let id = UUID()
    let toolName: String
    let parameters: [String: Any]
    let success: Bool
    let duration: TimeInterval
    let timestamp: Date
    let error: String?

    var durationMs: Int {
        return Int(duration * 1000)
    }

    var summary: String {
        let status = success ? "✅" : "❌"
        return "\(status) \(toolName) (\(durationMs)ms)"
    }

    var detailedSummary: String {
        var parts: [String] = [summary]

        if !parameters.isEmpty {
            parts.append("Parameters: \(parameters)")
        }

        if let error = error {
            parts.append("Error: \(error)")
        }

        return parts.joined(separator: "\n")
    }
}
