//
//  MemorySystem.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Memory system for storing and retrieving conversation context
class MemorySystem {
    /// Shared instance
    static let shared = MemorySystem()

    /// Maximum tokens to keep in context window
    private let maxContextTokens: Int

    /// Memory entries by key
    private var memories: [String: MemoryEntry] = [:]

    /// Active file contexts
    private var fileContexts: [String: FileContext] = [:]

    /// Recent tool executions
    private var toolHistory: [ToolExecutionRecord] = []

    /// Project context
    private var projectContext: ProjectContext?

    private init(maxContextTokens: Int = 8000) {
        self.maxContextTokens = maxContextTokens
    }

    // MARK: - Memory Management

    /// Store a memory entry
    func store(key: String, value: String, type: MemoryType = .shortTerm) {
        let entry = MemoryEntry(key: key, value: value, type: type, timestamp: Date())
        memories[key] = entry
        logInfo("Stored memory: \(key) (\(type))", category: "MemorySystem")
    }

    /// Retrieve a memory entry
    func retrieve(key: String) -> String? {
        guard let entry = memories[key] else { return nil }

        // Update access time
        memories[key]?.lastAccessed = Date()

        return entry.value
    }

    /// Delete a memory entry
    func delete(key: String) {
        memories.removeValue(forKey: key)
        logInfo("Deleted memory: \(key)", category: "MemorySystem")
    }

    /// Clear all short-term memories
    func clearShortTerm() {
        memories = memories.filter { $0.value.type != .shortTerm }
        logInfo("Cleared short-term memories", category: "MemorySystem")
    }

    /// Clear all memories
    func clearAll() {
        memories.removeAll()
        fileContexts.removeAll()
        toolHistory.removeAll()
        projectContext = nil
        logInfo("Cleared all memories", category: "MemorySystem")
    }

    // MARK: - File Context Management

    /// Store file context (recently read/edited files)
    func storeFileContext(_ path: String, content: String, lastModified: Date) {
        let context = FileContext(path: path, content: content, lastModified: lastModified)
        fileContexts[path] = context
        logInfo("Stored file context: \(path)", category: "MemorySystem")
    }

    /// Retrieve file context
    func getFileContext(_ path: String) -> FileContext? {
        return fileContexts[path]
    }

    /// Get all file contexts
    func getAllFileContexts() -> [FileContext] {
        return Array(fileContexts.values)
    }

    /// Clear file context
    func clearFileContext(_ path: String) {
        fileContexts.removeValue(forKey: path)
    }

    // MARK: - Tool History

    /// Record tool execution
    func recordToolExecution(_ toolName: String, parameters: [String: Any], result: ToolResult, duration: TimeInterval) {
        let record = ToolExecutionRecord(
            toolName: toolName,
            parameters: parameters,
            result: result,
            duration: duration,
            timestamp: Date()
        )

        toolHistory.append(record)

        // Keep only last 50 tool executions
        if toolHistory.count > 50 {
            toolHistory.removeFirst()
        }

        logInfo("Recorded tool execution: \(toolName)", category: "MemorySystem")
    }

    /// Get recent tool executions
    func getRecentToolExecutions(count: Int = 10) -> [ToolExecutionRecord] {
        return Array(toolHistory.suffix(count))
    }

    /// Get tool executions for specific tool
    func getToolExecutions(forTool toolName: String) -> [ToolExecutionRecord] {
        return toolHistory.filter { $0.toolName == toolName }
    }

    // MARK: - Project Context

    /// Set project context
    func setProjectContext(_ context: ProjectContext) {
        self.projectContext = context
        logInfo("Set project context: \(context.name)", category: "MemorySystem")
    }

    /// Get project context
    func getProjectContext() -> ProjectContext? {
        return projectContext
    }

    // MARK: - Context Window Management

    /// Build context string for LLM (within token limit)
    func buildContext(conversationHistory: [Message]) -> String {
        var contextParts: [String] = []

        // Add project context if available
        if let project = projectContext {
            contextParts.append("# Project: \(project.name)")
            contextParts.append("Path: \(project.path)")
            if let language = project.primaryLanguage {
                contextParts.append("Language: \(language)")
            }
            contextParts.append("")
        }

        // Add recent file contexts
        let recentFiles = getAllFileContexts()
            .sorted { $0.lastModified > $1.lastModified }
            .prefix(5)

        if !recentFiles.isEmpty {
            contextParts.append("# Recently Accessed Files:")
            for file in recentFiles {
                let fileName = (file.path as NSString).lastPathComponent
                contextParts.append("- \(fileName)")
            }
            contextParts.append("")
        }

        // Add important memories
        let importantMemories = memories.values
            .filter { $0.type == .longTerm || $0.type == .important }
            .sorted { $0.lastAccessed > $1.lastAccessed }
            .prefix(10)

        if !importantMemories.isEmpty {
            contextParts.append("# Important Context:")
            for memory in importantMemories {
                contextParts.append("- \(memory.key): \(memory.value)")
            }
            contextParts.append("")
        }

        return contextParts.joined(separator: "\n")
    }

    /// Estimate token count (rough approximation: 1 token ≈ 4 characters)
    func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
}

/// Memory entry
struct MemoryEntry {
    let key: String
    let value: String
    let type: MemoryType
    let timestamp: Date
    var lastAccessed: Date

    init(key: String, value: String, type: MemoryType, timestamp: Date) {
        self.key = key
        self.value = value
        self.type = type
        self.timestamp = timestamp
        self.lastAccessed = timestamp
    }
}

/// Memory type
enum MemoryType {
    case shortTerm   // Cleared after conversation
    case longTerm    // Persists across conversations
    case important   // Critical context (always included)
}

/// File context
struct FileContext {
    let path: String
    let content: String
    let lastModified: Date
    let tokenCount: Int

    init(path: String, content: String, lastModified: Date) {
        self.path = path
        self.content = content
        self.lastModified = lastModified
        // Rough token estimate
        self.tokenCount = content.count / 4
    }
}

/// Tool execution record
struct ToolExecutionRecord {
    let toolName: String
    let parameters: [String: Any]
    let result: ToolResult
    let duration: TimeInterval
    let timestamp: Date

    var summary: String {
        let status = result.success ? "✅" : "❌"
        let durationMs = Int(duration * 1000)
        return "\(status) \(toolName) (\(durationMs)ms)"
    }
}

/// Project context
struct ProjectContext {
    let name: String
    let path: String
    let primaryLanguage: String?
    let dependencies: [String]
    let metadata: [String: String]

    init(name: String, path: String, primaryLanguage: String? = nil, dependencies: [String] = [], metadata: [String: String] = [:]) {
        self.name = name
        self.path = path
        self.primaryLanguage = primaryLanguage
        self.dependencies = dependencies
        self.metadata = metadata
    }
}
