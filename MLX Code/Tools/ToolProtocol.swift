//
//  ToolProtocol.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Base protocol for all tools that can be executed by the LLM
protocol Tool {
    /// Unique identifier for the tool
    var name: String { get }

    /// Human-readable description of what the tool does
    var description: String { get }

    /// JSON schema describing the tool's parameters
    var parameters: ToolParameterSchema { get }

    /// Execute the tool with given parameters
    /// - Parameters:
    ///   - parameters: Dictionary of parameter name to value
    ///   - context: Execution context with conversation state
    /// - Returns: Result of tool execution
    func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult
}

/// Schema definition for tool parameters
struct ToolParameterSchema: Codable {
    /// Parameter type (e.g., "object")
    let type: String

    /// Properties defined for this tool
    let properties: [String: ParameterProperty]

    /// Required parameter names
    let required: [String]

    /// Additional properties allowed
    let additionalProperties: Bool

    init(properties: [String: ParameterProperty], required: [String] = [], additionalProperties: Bool = false) {
        self.type = "object"
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

/// Individual parameter property definition
class ParameterProperty: Codable {
    /// Parameter type (string, number, boolean, array, object)
    let type: String

    /// Human-readable description
    let description: String

    /// Enum values if applicable
    let `enum`: [String]?

    /// Items schema for array types
    let items: ParameterProperty?

    /// Default value
    let `default`: String?

    init(type: String, description: String, enum: [String]? = nil, items: ParameterProperty? = nil, default: String? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.items = items
        self.default = `default`
    }
}

/// Context passed to tool execution
struct ToolContext {
    /// Current working directory
    let workingDirectory: String

    /// Conversation history (for context-aware tools)
    let conversationHistory: [Message]

    /// Current project path (if any)
    let projectPath: String?

    /// User settings
    let settings: AppSettings

    /// Memory system for storing context
    let memory: MemorySystem?

    init(workingDirectory: String = FileManager.default.currentDirectoryPath,
         conversationHistory: [Message] = [],
         projectPath: String? = nil,
         settings: AppSettings,
         memory: MemorySystem? = nil) {
        self.workingDirectory = workingDirectory
        self.conversationHistory = conversationHistory
        self.projectPath = projectPath
        self.settings = settings
        self.memory = memory
    }
}

/// Result returned from tool execution
struct ToolResult {
    /// Whether execution was successful
    let success: Bool

    /// Output data (can be string, dictionary, array, etc.)
    let output: Any

    /// Error message if failed
    let error: String?

    /// Metadata about execution (timing, etc.)
    let metadata: [String: Any]

    init(success: Bool, output: Any, error: String? = nil, metadata: [String: Any] = [:]) {
        self.success = success
        self.output = output
        self.error = error
        self.metadata = metadata
    }

    /// Create success result
    static func success(_ output: Any, metadata: [String: Any] = [:]) -> ToolResult {
        return ToolResult(success: true, output: output, metadata: metadata)
    }

    /// Create failure result
    static func failure(_ error: String, metadata: [String: Any] = [:]) -> ToolResult {
        return ToolResult(success: false, output: "", error: error, metadata: metadata)
    }

    /// Convert result to JSON string for LLM
    func toJSON() -> String {
        var dict: [String: Any] = [
            "success": success,
            "output": output,
            "metadata": metadata
        ]

        if let error = error {
            dict["error"] = error
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{\"success\": false, \"error\": \"Failed to serialize result\"}"
    }
}

/// Base class for tools with common functionality
class BaseTool: Tool {
    let name: String
    let description: String
    let parameters: ToolParameterSchema

    init(name: String, description: String, parameters: ToolParameterSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        fatalError("execute(parameters:context:) must be implemented by subclass")
    }

    /// Validate required parameters are present
    func validateParameters(_ parameters: [String: Any], required: [String]) throws {
        for requiredParam in required {
            guard parameters[requiredParam] != nil else {
                throw ToolError.missingParameter(requiredParam)
            }
        }
    }

    /// Extract string parameter
    func stringParameter(_ parameters: [String: Any], key: String, default defaultValue: String? = nil) throws -> String {
        if let value = parameters[key] as? String {
            return value
        }
        if let defaultValue = defaultValue {
            return defaultValue
        }
        throw ToolError.invalidParameterType(key, expected: "String")
    }

    /// Extract integer parameter
    func intParameter(_ parameters: [String: Any], key: String, default defaultValue: Int? = nil) throws -> Int {
        if let value = parameters[key] as? Int {
            return value
        }
        if let defaultValue = defaultValue {
            return defaultValue
        }
        throw ToolError.invalidParameterType(key, expected: "Int")
    }

    /// Extract boolean parameter
    func boolParameter(_ parameters: [String: Any], key: String, default defaultValue: Bool? = nil) throws -> Bool {
        if let value = parameters[key] as? Bool {
            return value
        }
        if let defaultValue = defaultValue {
            return defaultValue
        }
        throw ToolError.invalidParameterType(key, expected: "Bool")
    }

    /// Extract array parameter
    func arrayParameter(_ parameters: [String: Any], key: String) throws -> [Any] {
        guard let value = parameters[key] as? [Any] else {
            throw ToolError.invalidParameterType(key, expected: "Array")
        }
        return value
    }
}

/// Errors that can occur during tool execution
enum ToolError: LocalizedError {
    case missingParameter(String)
    case invalidParameterType(String, expected: String)
    case executionFailed(String)
    case notFound(String)
    case permissionDenied(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameterType(let param, let expected):
            return "Invalid type for parameter '\(param)': expected \(expected)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .permissionDenied(let resource):
            return "Permission denied: \(resource)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}

/// Tool execution telemetry
struct ToolTelemetry {
    /// Tool name
    let toolName: String

    /// Execution start time
    let startTime: Date

    /// Execution end time
    let endTime: Date

    /// Duration in seconds
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    /// Success flag
    let success: Bool

    /// Error message if failed
    let error: String?

    /// Log telemetry
    func log() {
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        let durationMs = Int(duration * 1000)

        var message = "[\(toolName)] \(status) (\(durationMs)ms)"
        if let error = error {
            message += " - \(error)"
        }

        logInfo(message, category: "ToolTelemetry")
    }
}
