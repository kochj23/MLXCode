//
//  ContextMemoryTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for intelligent context management and conversation memory
class ContextMemoryTool: BaseTool {
    private var contextStore: ContextStore = ContextStore()

    init() {
        super.init(
            name: "context_memory",
            description: """
            Manage conversation context and memory.
            Store important code snippets, maintain project understanding, semantic search.
            """,
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Context operation",
                        enum: ["store", "retrieve", "search", "summarize", "clear", "list", "analyze_project"]
                    ),
                    "key": ParameterProperty(
                        type: "string",
                        description: "Context key/identifier"
                    ),
                    "content": ParameterProperty(
                        type: "string",
                        description: "Content to store"
                    ),
                    "query": ParameterProperty(
                        type: "string",
                        description: "Search query"
                    ),
                    "context_type": ParameterProperty(
                        type: "string",
                        description: "Type of context",
                        enum: ["code", "conversation", "project_structure", "important_note"]
                    ),
                    "priority": ParameterProperty(
                        type: "integer",
                        description: "Priority level (1-10, higher = more important)"
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        switch operation {
        case "store":
            return try await store(parameters: parameters)
        case "retrieve":
            return try await retrieve(parameters: parameters)
        case "search":
            return try await search(parameters: parameters)
        case "summarize":
            return try await summarize()
        case "clear":
            return try await clear(parameters: parameters)
        case "list":
            return try await list()
        case "analyze_project":
            return try await analyzeProject(context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func store(parameters: [String: Any]) async throws -> ToolResult {
        guard let key = parameters["key"] as? String,
              let content = parameters["content"] as? String else {
            throw ToolError.missingParameter("key or content")
        }

        let contextType = parameters["context_type"] as? String ?? "code"
        let priority = parameters["priority"] as? Int ?? 5

        let item = ContextItem(
            key: key,
            content: content,
            type: ContextType(rawValue: contextType) ?? .code,
            priority: priority
        )

        contextStore.store(item)

        var result = "# Context Stored\n\n"
        result += "**Key**: `\(key)`\n"
        result += "**Type**: \(contextType)\n"
        result += "**Priority**: \(priority)/10\n"
        result += "**Size**: \(content.count) characters\n\n"
        result += "## Preview\n"
        result += "```\n\(content.prefix(200))\n```\n"

        return .success(result)
    }

    private func retrieve(parameters: [String: Any]) async throws -> ToolResult {
        guard let key = parameters["key"] as? String else {
            throw ToolError.missingParameter("key")
        }

        guard let item = contextStore.retrieve(key: key) else {
            return .failure("Context key '\(key)' not found")
        }

        var result = "# Context Retrieved\n\n"
        result += "**Key**: `\(key)`\n"
        result += "**Type**: \(item.type.rawValue)\n"
        result += "**Priority**: \(item.priority)/10\n"
        result += "**Stored**: \(item.timestamp.formatted())\n"
        result += "**Access Count**: \(item.accessCount)\n\n"
        result += "## Content\n"
        result += "```\n\(item.content)\n```\n"

        return .success(result)
    }

    private func search(parameters: [String: Any]) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            throw ToolError.missingParameter("query")
        }

        let results = contextStore.search(query: query)

        var result = "# Context Search Results\n\n"
        result += "**Query**: \(query)\n"
        result += "**Matches**: \(results.count)\n\n"

        if results.isEmpty {
            result += "*No matching context found*\n"
        } else {
            for (index, item) in results.prefix(10).enumerated() {
                result += "## \(index + 1). \(item.key)\n"
                result += "- Type: \(item.type.rawValue)\n"
                result += "- Priority: \(item.priority)/10\n"
                result += "- Stored: \(item.timestamp.formatted(date: .abbreviated, time: .shortened))\n"
                result += "```\n\(item.content.prefix(150))\n```\n\n"
            }

            if results.count > 10 {
                result += "*... and \(results.count - 10) more results*\n"
            }
        }

        return .success(result, metadata: ["match_count": results.count])
    }

    private func summarize() async throws -> ToolResult {
        let summary = contextStore.summarize()

        var result = "# Context Memory Summary\n\n"
        result += "**Total Items**: \(summary.totalItems)\n"
        result += "**Total Size**: \(formatBytes(summary.totalBytes))\n\n"

        result += "## By Type\n"
        for (type, count) in summary.byType.sorted(by: { $0.value > $1.value }) {
            result += "- \(type.capitalized): \(count)\n"
        }

        result += "\n## By Priority\n"
        result += "- High (8-10): \(summary.highPriority)\n"
        result += "- Medium (5-7): \(summary.mediumPriority)\n"
        result += "- Low (1-4): \(summary.lowPriority)\n"

        result += "\n## Most Accessed\n"
        for item in summary.mostAccessed.prefix(5) {
            result += "- `\(item.key)` (\(item.accessCount) accesses)\n"
        }

        return .success(result)
    }

    private func clear(parameters: [String: Any]) async throws -> ToolResult {
        if let key = parameters["key"] as? String {
            // Clear specific key
            contextStore.remove(key: key)
            return .success("✅ Cleared context: \(key)")
        } else {
            // Clear all
            let count = contextStore.clearAll()
            return .success("✅ Cleared all context (\(count) items)")
        }
    }

    private func list() async throws -> ToolResult {
        let items = contextStore.list()

        var result = "# Stored Context\n\n"
        result += "**Total**: \(items.count) items\n\n"

        if items.isEmpty {
            result += "*No context stored*\n"
        } else {
            for item in items {
                result += "## `\(item.key)`\n"
                result += "- Type: \(item.type.rawValue)\n"
                result += "- Priority: \(item.priority)/10\n"
                result += "- Size: \(item.content.count) chars\n"
                result += "- Accessed: \(item.accessCount) times\n"
                result += "- Last: \(item.timestamp.formatted(date: .abbreviated, time: .shortened))\n\n"
            }
        }

        return .success(result)
    }

    private func analyzeProject(context: ToolContext) async throws -> ToolResult {
        let workingDir = context.workingDirectory

        // Analyze project structure
        let structure = try await analyzeProjectStructure(directory: workingDir)

        // Store in context
        let structureJson = try JSONEncoder().encode(structure)
        let structureString = String(data: structureJson, encoding: .utf8) ?? ""

        let item = ContextItem(
            key: "project_structure",
            content: structureString,
            type: .projectStructure,
            priority: 9
        )
        contextStore.store(item)

        var result = "# Project Analysis Complete\n\n"
        result += "**Files**: \(structure.totalFiles)\n"
        result += "**Directories**: \(structure.totalDirectories)\n"
        result += "**Swift Files**: \(structure.swiftFiles)\n"
        result += "**Test Files**: \(structure.testFiles)\n\n"

        result += "## Structure\n"
        for (dir, count) in structure.filesByDirectory.sorted(by: { $0.value > $1.value }).prefix(10) {
            result += "- \(dir): \(count) files\n"
        }

        result += "\n✅ Project structure stored in context memory\n"

        return .success(result)
    }

    // MARK: - Helper Methods

    private func analyzeProjectStructure(directory: String) async throws -> ProjectStructure {
        let command = """
        cd "\(directory)" && find . -type f -name "*.swift" | head -1000
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var filesByDirectory: [String: Int] = [:]
        var swiftFiles = 0
        var testFiles = 0

        for file in files {
            let dir = (file as NSString).deletingLastPathComponent
            filesByDirectory[dir, default: 0] += 1

            if file.hasSuffix(".swift") {
                swiftFiles += 1
            }
            if file.contains("Test") {
                testFiles += 1
            }
        }

        return ProjectStructure(
            totalFiles: files.count,
            totalDirectories: filesByDirectory.count,
            swiftFiles: swiftFiles,
            testFiles: testFiles,
            filesByDirectory: filesByDirectory
        )
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Supporting Types

class ContextStore {
    private var items: [String: ContextItem] = [:]

    func store(_ item: ContextItem) {
        items[item.key] = item
    }

    func retrieve(key: String) -> ContextItem? {
        if var item = items[key] {
            item.accessCount += 1
            items[key] = item
            return item
        }
        return nil
    }

    func search(query: String) -> [ContextItem] {
        let lowercased = query.lowercased()
        return items.values.filter {
            $0.key.lowercased().contains(lowercased) ||
            $0.content.lowercased().contains(lowercased)
        }.sorted { $0.priority > $1.priority }
    }

    func remove(key: String) {
        items.removeValue(forKey: key)
    }

    func clearAll() -> Int {
        let count = items.count
        items.removeAll()
        return count
    }

    func list() -> [ContextItem] {
        return Array(items.values).sorted { $0.priority > $1.priority }
    }

    func summarize() -> ContextSummary {
        let totalItems = items.count
        let totalBytes = items.values.reduce(0) { $0 + $1.content.utf8.count }

        var byType: [String: Int] = [:]
        var highPriority = 0
        var mediumPriority = 0
        var lowPriority = 0

        for item in items.values {
            byType[item.type.rawValue, default: 0] += 1

            if item.priority >= 8 {
                highPriority += 1
            } else if item.priority >= 5 {
                mediumPriority += 1
            } else {
                lowPriority += 1
            }
        }

        let mostAccessed = items.values.sorted { $0.accessCount > $1.accessCount }

        return ContextSummary(
            totalItems: totalItems,
            totalBytes: totalBytes,
            byType: byType,
            highPriority: highPriority,
            mediumPriority: mediumPriority,
            lowPriority: lowPriority,
            mostAccessed: Array(mostAccessed.prefix(10))
        )
    }
}

struct ContextItem {
    let key: String
    let content: String
    let type: ContextType
    let priority: Int
    let timestamp: Date
    var accessCount: Int

    init(key: String, content: String, type: ContextType, priority: Int) {
        self.key = key
        self.content = content
        self.type = type
        self.priority = priority
        self.timestamp = Date()
        self.accessCount = 0
    }
}

enum ContextType: String {
    case code
    case conversation
    case projectStructure = "project_structure"
    case importantNote = "important_note"
}

struct ContextSummary {
    let totalItems: Int
    let totalBytes: Int
    let byType: [String: Int]
    let highPriority: Int
    let mediumPriority: Int
    let lowPriority: Int
    let mostAccessed: [ContextItem]
}

struct ProjectStructure: Codable {
    let totalFiles: Int
    let totalDirectories: Int
    let swiftFiles: Int
    let testFiles: Int
    let filesByDirectory: [String: Int]
}
