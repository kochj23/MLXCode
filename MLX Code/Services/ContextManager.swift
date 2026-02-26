//
//  ContextManager.swift
//  MLX Code
//
//  Smart context management with budget-aware assembly,
//  rule-based compaction, and automatic project context inclusion.
//  Created on 2025-12-09. Updated 2026-02-19.
//

import Foundation

/// Manages conversation context with intelligent summarization
actor ContextManager {
    static let shared = ContextManager()

    // MARK: - Properties

    private let maxRecentMessages = 10
    private let maxTotalTokens = 32000  // Fallback limit for legacy path
    private var messageSummaries: [UUID: String] = [:]

    private init() {}

    // MARK: - Token Estimation (improved)

    /// Estimates token count for a single string
    /// Uses word-based heuristic: ~1.3 tokens/word for English, ~1.5 for code
    func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let words = text.split(separator: " ").count
        let hasCodeIndicators = text.contains("{") || text.contains("func ") ||
            text.contains("import ") || text.contains("let ") || text.contains("var ")

        if hasCodeIndicators {
            // Code: more symbols = more tokens
            return Int(Double(words) * 1.5) + (text.count / 20)
        } else {
            return Int(Double(words) * 1.3)
        }
    }

    /// Estimates total token count for an array of messages
    func estimateTokenCount(_ messages: [Message]) -> Int {
        return messages.reduce(0) { total, msg in
            total + estimateTokens(msg.content) + 4  // +4 for role markers
        }
    }

    // MARK: - Budget-Aware Context Assembly

    /// Assembles optimized context within token budget
    /// - Parameters:
    ///   - messages: All conversation messages
    ///   - systemPrompt: System prompt string (already within systemPromptBudget)
    ///   - projectPath: Optional project directory for auto-context
    ///   - budget: Token budget allocation
    /// - Returns: Optimized message array ready for the model
    func assembleContext(
        messages: [Message],
        systemPrompt: String,
        projectPath: String?,
        budget: ContextBudget
    ) async -> [Message] {
        var assembled: [Message] = []

        // 1. System prompt (always included)
        assembled.append(Message.system(systemPrompt))

        // 2. Recent messages (fill from most recent backwards)
        let nonSystemMessages = messages.filter { $0.role != .system }
        var recentMessages: [Message] = []
        var recentTokens = 0

        for message in nonSystemMessages.reversed() {
            let msgTokens = estimateTokens(message.content) + 4
            if recentTokens + msgTokens > budget.recentMessagesBudget {
                break
            }
            recentMessages.append(message)
            recentTokens += msgTokens
        }
        // Reverse once after collecting to restore chronological order (avoids O(n^2) inserts at index 0)
        recentMessages.reverse()

        // 3. If older messages were dropped, create rule-based summary
        let droppedCount = nonSystemMessages.count - recentMessages.count
        if droppedCount > 0 {
            let olderMessages = Array(nonSystemMessages.prefix(droppedCount))
            let summary = compactSummary(olderMessages, maxTokens: budget.summaryBudget)
            if !summary.isEmpty {
                assembled.append(Message.system("[Earlier conversation summary: \(summary)]"))
            }
        }

        // 4. Project context (if budget allows)
        if let projectPath = projectPath, budget.projectContextBudget > 50 {
            let projectContext = await buildProjectContext(projectPath, maxTokens: budget.projectContextBudget)
            if !projectContext.isEmpty {
                assembled.append(Message.system("[Project context]\n\(projectContext)"))
            }
        }

        // 5. Add the recent messages
        assembled.append(contentsOf: recentMessages)

        return assembled
    }

    // MARK: - Rule-Based Compaction

    /// Creates a compact summary of messages without LLM calls (instant, predictable)
    private func compactSummary(_ messages: [Message], maxTokens: Int) -> String {
        var summaryParts: [String] = []

        for message in messages {
            switch message.role {
            case .user:
                let preview = String(message.content.prefix(60))
                summaryParts.append("User: \(preview)...")
            case .assistant:
                // Keep first sentence
                let firstSentence = message.content.prefix(while: { $0 != "." && $0 != "\n" })
                let truncated = firstSentence.isEmpty ? String(message.content.prefix(60)) : String(firstSentence) + "."
                summaryParts.append("Assistant: \(truncated)")
            case .system:
                // Check if this is a tool result
                if message.metadata?["collapsible"] == "true" || message.content.contains("<tool_result>") {
                    summaryParts.append("[Tool executed]")
                }
                // Skip other system messages in summary
            }
        }

        var result = summaryParts.joined(separator: " | ")

        // Truncate to budget
        while estimateTokens(result) > maxTokens && !summaryParts.isEmpty {
            summaryParts.removeLast()
            result = summaryParts.joined(separator: " | ")
        }

        return result
    }

    // MARK: - Project Context Auto-Include

    /// Builds compact project context from the working directory
    private func buildProjectContext(_ projectPath: String, maxTokens: Int) async -> String {
        let fm = FileManager.default
        var contextParts: [String] = []

        // File tree: top-level items (Swift files + directories, max 20 entries)
        if let items = try? fm.contentsOfDirectory(atPath: projectPath) {
            let filteredItems = items.filter { !$0.hasPrefix(".") }
            let swiftFiles = filteredItems.filter { $0.hasSuffix(".swift") }.sorted()
            let directories = filteredItems.filter {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: "\(projectPath)/\($0)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()

            if !directories.isEmpty || !swiftFiles.isEmpty {
                contextParts.append("Project files:")
                for dir in directories.prefix(10) {
                    contextParts.append("  \(dir)/")
                }
                for file in swiftFiles.prefix(10) {
                    contextParts.append("  \(file)")
                }
            }
        }

        // Recent files from MemorySystem (first 200 chars each, max 3)
        let recentFiles = await MemorySystem.shared.getAllFileContexts()
        let sortedFiles = recentFiles
            .sorted { $0.lastModified > $1.lastModified }
            .prefix(3)

        for file in sortedFiles {
            let fileName = (file.path as NSString).lastPathComponent
            let preview = String(file.content.prefix(200))
            contextParts.append("\nRecent: \(fileName)\n\(preview)...")
        }

        var result = contextParts.joined(separator: "\n")

        // Truncate to budget
        while estimateTokens(result) > maxTokens && !contextParts.isEmpty {
            contextParts.removeLast()
            result = contextParts.joined(separator: "\n")
        }

        return result
    }

    // MARK: - Legacy API (kept for backwards compatibility)

    /// Optimizes conversation context for token budget (legacy path)
    func optimizeContext(messages: [Message], systemPrompt: String?) async throws -> [Message] {
        let recentMessages = Array(messages.suffix(maxRecentMessages))

        let estimatedTokens = estimateTokenCount(messages)
        if estimatedTokens < maxTotalTokens {
            return messages
        }

        let olderMessages = messages.dropLast(maxRecentMessages)
        if !olderMessages.isEmpty {
            let summary = compactSummary(Array(olderMessages), maxTokens: 500)
            let summaryMessage = Message(
                role: .system,
                content: "Previous conversation summary:\n\n\(summary)"
            )
            return [summaryMessage] + recentMessages
        }

        return recentMessages
    }

    /// Gets or creates a summary for a message
    func getSummary(for message: Message) async throws -> String {
        if let cached = messageSummaries[message.id] {
            return cached
        }

        let prompt = """
        Summarize this message in one concise sentence:

        \(message.content)

        Focus on the key point or action.
        """

        let summary = try await MLXService.shared.generate(prompt: prompt)
        messageSummaries[message.id] = summary

        return summary
    }

    /// Clears cached summaries
    func clearCache() {
        messageSummaries.removeAll()
    }

    // MARK: - Smart File Inclusion

    /// Determines which files should be included in context
    func determineRelevantFiles(for query: String, in projectPath: String) async throws -> [String] {
        let indexer = CodebaseIndexer.shared
        let stats = await indexer.getStatistics()
        if stats.totalFiles == 0 {
            _ = try await indexer.indexDirectory(projectPath)
        }
        let results = await indexer.search(query, limit: 5)
        return results.map { $0.file.path }
    }

    /// Creates optimized context with relevant files
    func createOptimizedContext(
        messages: [Message],
        query: String,
        projectPath: String?
    ) async throws -> String {
        var context = ""

        let optimizedMessages = try await optimizeContext(messages: messages, systemPrompt: nil)
        for message in optimizedMessages {
            context += "\(message.role.displayName): \(message.content)\n\n"
        }

        if let projectPath = projectPath {
            let relevantFiles = try await determineRelevantFiles(for: query, in: projectPath)
            if !relevantFiles.isEmpty {
                context += "\n--- Relevant Files ---\n\n"
                for filePath in relevantFiles.prefix(3) {
                    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                        context += "File: \(filePath)\n```\n\(content.prefix(1000))\n```\n\n"
                    }
                }
            }
        }

        return context
    }

    // MARK: - Token Budget Management

    /// Calculates remaining token budget
    func remainingBudget(used usedTokens: Int) -> Int {
        return max(0, maxTotalTokens - usedTokens)
    }

    /// Checks if more context can be added
    func canAddContent(_ additionalContent: String, currentTokens: Int) -> Bool {
        let additionalTokens = estimateTokens(additionalContent)
        return (currentTokens + additionalTokens) < maxTotalTokens
    }
}
