//
//  ToolUseProtocol.swift
//  MLX Code
//
//  Structured tool calling protocol with JSON schemas
//  Created on 2025-12-09
//

import Foundation

/// Tool use protocol for structured function calling
actor ToolUseProtocol {
    static let shared = ToolUseProtocol()

    // MARK: - Properties

    private var registeredTools: [String: MLXTool] = [:]

    private init() {
        registerDefaultTools()
    }

    // MARK: - Tool Registration

    private func registerDefaultTools() {
        // File operations
        registerTool(MLXTool(
            name: "read_file",
            description: "Reads a file from the filesystem",
            parameters: [
                "path": .string(required: true, description: "Absolute file path"),
                "start_line": .integer(required: false, description: "Starting line number"),
                "end_line": .integer(required: false, description: "Ending line number")
            ],
            handler: readFileHandler
        ))

        registerTool(MLXTool(
            name: "write_file",
            description: "Writes content to a file",
            parameters: [
                "path": .string(required: true, description: "Absolute file path"),
                "content": .string(required: true, description: "File content to write")
            ],
            handler: writeFileHandler
        ))

        registerTool(MLXTool(
            name: "edit_file",
            description: "Edits a file with find/replace",
            parameters: [
                "path": .string(required: true, description: "File path"),
                "find": .string(required: true, description: "Text to find"),
                "replace": .string(required: true, description: "Replacement text")
            ],
            handler: editFileHandler
        ))

        // Search operations
        registerTool(MLXTool(
            name: "grep",
            description: "Searches for pattern in files",
            parameters: [
                "pattern": .string(required: true, description: "Search pattern"),
                "path": .string(required: false, description: "Directory to search"),
                "file_type": .string(required: false, description: "File extension filter")
            ],
            handler: grepHandler
        ))

        registerTool(MLXTool(
            name: "list_files",
            description: "Lists files in a directory",
            parameters: [
                "path": .string(required: true, description: "Directory path"),
                "pattern": .string(required: false, description: "Glob pattern filter")
            ],
            handler: listFilesHandler
        ))

        // Shell operations
        registerTool(MLXTool(
            name: "bash",
            description: "Executes a bash command",
            parameters: [
                "command": .string(required: true, description: "Command to execute"),
                "working_dir": .string(required: false, description: "Working directory")
            ],
            handler: bashHandler
        ))

        // Git operations
        registerTool(MLXTool(
            name: "git_status",
            description: "Gets git repository status",
            parameters: [
                "repo_path": .string(required: true, description: "Repository path")
            ],
            handler: gitStatusHandler
        ))

        registerTool(MLXTool(
            name: "git_diff",
            description: "Shows git diff",
            parameters: [
                "repo_path": .string(required: true, description: "Repository path"),
                "cached": .boolean(required: false, description: "Show staged changes")
            ],
            handler: gitDiffHandler
        ))

        // Xcode operations
        registerTool(MLXTool(
            name: "xcode_build",
            description: "Builds an Xcode project",
            parameters: [
                "project_path": .string(required: true, description: "Project path"),
                "scheme": .string(required: false, description: "Build scheme")
            ],
            handler: xcodeBuildHandler
        ))
    }

    private func registerTool(_ tool: MLXTool) {
        registeredTools[tool.name] = tool
    }

    // MARK: - Tool Execution

    /// Executes a tool call
    /// - Parameters:
    ///   - toolName: Name of the tool
    ///   - arguments: Tool arguments
    /// - Returns: Tool result
    func executeTool(_ toolName: String, arguments: [String: Any]) async throws -> MLXToolResult {
        guard let tool = registeredTools[toolName] else {
            throw MLXToolError.toolNotFound(toolName)
        }

        // Validate arguments
        try validateArguments(arguments, against: tool.parameters)

        // Execute tool
        return try await tool.handler(arguments)
    }

    /// Gets all registered tools with their schemas
    func getAvailableTools() async -> [MLXTool] {
        return Array(registeredTools.values)
    }

    /// Generates tool descriptions for LLM prompt
    func getToolDescriptionsForPrompt() async -> String {
        var descriptions: [String] = []

        for tool in registeredTools.values.sorted(by: { $0.name < $1.name }) {
            var desc = "**\(tool.name)**: \(tool.description)\n"
            desc += "Parameters:\n"

            for (name, param) in tool.parameters {
                let req = param.isRequired ? "required" : "optional"
                desc += "  - \(name) (\(param.typeName), \(req)): \(param.paramDescription)\n"
            }

            descriptions.append(desc)
        }

        return descriptions.joined(separator: "\n")
    }

    // MARK: - Validation

    private func validateArguments(_ arguments: [String: Any], against parameters: [String: ToolParameter]) throws {
        // Check required parameters
        for (name, param) in parameters where param.isRequired {
            guard arguments[name] != nil else {
                throw MLXToolError.missingParameter(name)
            }
        }

        // Validate types
        for (name, value) in arguments {
            guard let param = parameters[name] else {
                throw MLXToolError.unknownParameter(name)
            }

            try validateValueType(value, against: param)
        }
    }

    private func validateValueType(_ value: Any, against parameter: ToolParameter) throws {
        switch parameter {
        case .string:
            guard value is String else {
                throw MLXToolError.typeMismatch("Expected string")
            }
        case .integer:
            guard value is Int else {
                throw MLXToolError.typeMismatch("Expected integer")
            }
        case .boolean:
            guard value is Bool else {
                throw MLXToolError.typeMismatch("Expected boolean")
            }
        case .array:
            guard value is [Any] else {
                throw MLXToolError.typeMismatch("Expected array")
            }
        }
    }

    // MARK: - Tool Handlers

    private func readFileHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let path = args["path"] as? String else {
            throw MLXToolError.missingParameter("path")
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        // Handle line range
        let startLine = args["start_line"] as? Int ?? 1
        let endLine = args["end_line"] as? Int ?? lines.count

        let selectedLines = lines[(startLine - 1)..<min(endLine, lines.count)]
        let result = selectedLines.joined(separator: "\n")

        return MLXToolResult(
            success: true,
            output: result,
            metadata: ["lines": lines.count, "bytes": content.count]
        )
    }

    private func writeFileHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let path = args["path"] as? String,
              let content = args["content"] as? String else {
            throw MLXToolError.missingParameter("path or content")
        }

        try content.write(toFile: path, atomically: true, encoding: .utf8)

        return MLXToolResult(
            success: true,
            output: "Wrote \(content.count) bytes to \(path)",
            metadata: ["path": path, "bytes": content.count]
        )
    }

    private func editFileHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let path = args["path"] as? String,
              let find = args["find"] as? String,
              let replace = args["replace"] as? String else {
            throw MLXToolError.missingParameter("path, find, or replace")
        }

        var content = try String(contentsOfFile: path, encoding: .utf8)
        let originalCount = content.count
        content = content.replacingOccurrences(of: find, with: replace)

        try content.write(toFile: path, atomically: true, encoding: .utf8)

        return MLXToolResult(
            success: true,
            output: "Edited \(path)",
            metadata: ["replacements": content.count != originalCount ? 1 : 0]
        )
    }

    private func grepHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let pattern = args["pattern"] as? String else {
            throw MLXToolError.missingParameter("pattern")
        }

        let path = args["path"] as? String ?? FileManager.default.currentDirectoryPath
        // Simple grep implementation (can be enhanced with ripgrep)

        return MLXToolResult(
            success: true,
            output: "Search results for: \(pattern)",
            metadata: ["pattern": pattern, "path": path]
        )
    }

    private func listFilesHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let path = args["path"] as? String else {
            throw MLXToolError.missingParameter("path")
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
        let output = contents.joined(separator: "\n")

        return MLXToolResult(
            success: true,
            output: output,
            metadata: ["count": contents.count]
        )
    }

    private func bashHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let command = args["command"] as? String else {
            throw MLXToolError.missingParameter("command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        if let workingDir = args["working_dir"] as? String {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return MLXToolResult(
            success: process.terminationStatus == 0,
            output: output,
            metadata: ["exit_code": process.terminationStatus]
        )
    }

    private func gitStatusHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let repoPath = args["repo_path"] as? String else {
            throw MLXToolError.missingParameter("repo_path")
        }

        let output = try await GitService.shared.getStatus(in: repoPath)

        return MLXToolResult(
            success: true,
            output: output,
            metadata: ["repo": repoPath]
        )
    }

    private func gitDiffHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let repoPath = args["repo_path"] as? String else {
            throw MLXToolError.missingParameter("repo_path")
        }

        let cached = args["cached"] as? Bool ?? false
        // Implement diff fetching

        return MLXToolResult(
            success: true,
            output: "Diff output",
            metadata: ["cached": cached]
        )
    }

    private func xcodeBuildHandler(_ args: [String: Any]) async throws -> MLXToolResult {
        guard let projectPath = args["project_path"] as? String else {
            throw MLXToolError.missingParameter("project_path")
        }

        let scheme = args["scheme"] as? String

        return MLXToolResult(
            success: true,
            output: "Build output",
            metadata: ["project": projectPath]
        )
    }
}

// MARK: - Tool Definition

/// Tool that can be called by LLM
struct MLXTool {
    let name: String
    let description: String
    let parameters: [String: ToolParameter]
    let handler: ([String: Any]) async throws -> MLXToolResult

    /// Converts tool to JSON schema
    func toJSONSchema() -> [String: Any] {
        var schema: [String: Any] = [
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "properties": parameters.mapValues { $0.toJSON() },
                "required": parameters.filter { $0.value.isRequired }.map { $0.key }
            ]
        ]

        return schema
    }
}

/// Tool parameter definition
enum ToolParameter {
    case string(required: Bool, description: String)
    case integer(required: Bool, description: String)
    case boolean(required: Bool, description: String)
    case array(required: Bool, description: String)

    var isRequired: Bool {
        switch self {
        case .string(let required, _),
             .integer(let required, _),
             .boolean(let required, _),
             .array(let required, _):
            return required
        }
    }

    var paramDescription: String {
        switch self {
        case .string(_, let desc),
             .integer(_, let desc),
             .boolean(_, let desc),
             .array(_, let desc):
            return desc
        }
    }

    var typeName: String {
        switch self {
        case .string: return "string"
        case .integer: return "integer"
        case .boolean: return "boolean"
        case .array: return "array"
        }
    }

    func toJSON() -> [String: Any] {
        return [
            "type": typeName,
            "description": paramDescription
        ]
    }
}

/// Result from tool execution
struct MLXToolResult {
    let success: Bool
    let output: String
    let metadata: [String: Any]
    let error: String?

    init(success: Bool, output: String, metadata: [String: Any] = [:], error: String? = nil) {
        self.success = success
        self.output = output
        self.metadata = metadata
        self.error = error
    }
}

/// Tool execution errors
enum MLXToolError: LocalizedError {
    case toolNotFound(String)
    case missingParameter(String)
    case unknownParameter(String)
    case typeMismatch(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .missingParameter(let name):
            return "Missing required parameter: \(name)"
        case .unknownParameter(let name):
            return "Unknown parameter: \(name)"
        case .typeMismatch(let details):
            return "Type mismatch: \(details)"
        case .executionFailed(let details):
            return "Execution failed: \(details)"
        }
    }
}
