//
//  ContextManager.swift
//  MLX Code
//
//  Smart context management with automatic summarization
//  Created on 2025-12-09
//

import Foundation

/// Manages conversation context with intelligent summarization
actor ContextManager {
    static let shared = ContextManager()

    // MARK: - Properties

    private let maxRecentMessages = 10
    private let maxTotalTokens = 32000  // Conservative limit for context window
    private var messageSummaries: [UUID: String] = [:]

    private init() {}

    // MARK: - Context Optimization

    /// Optimizes conversation context for token budget
    /// - Parameters:
    ///   - messages: All conversation messages
    ///   - systemPrompt: System prompt to include
    /// - Returns: Optimized message list within token budget
    func optimizeContext(messages: [Message], systemPrompt: String?) async throws -> [Message] {
        // Always keep recent messages
        let recentMessages = Array(messages.suffix(maxRecentMessages))

        // If we're under the limit, return all
        let estimatedTokens = estimateTokenCount(messages)
        if estimatedTokens < maxTotalTokens {
            return messages
        }

        // Otherwise, summarize older messages
        let olderMessages = messages.dropLast(maxRecentMessages)

        if !olderMessages.isEmpty {
            let summary = try await summarizeMessages(Array(olderMessages))

            // Create a summary message
            let summaryMessage = Message(
                role: .system,
                content: "Previous conversation summary:\n\n\(summary)"
            )

            return [summaryMessage] + recentMessages
        }

        return recentMessages
    }

    /// Summarizes a batch of messages
    private func summarizeMessages(_ messages: [Message]) async throws -> String {
        let conversationText = messages.map { message in
            "\(message.role.displayName): \(message.content)"
        }.joined(separator: "\n\n")

        let prompt = """
        Summarize this conversation segment concisely:

        \(conversationText)

        Provide a summary that captures:
        1. Main topics discussed
        2. Key decisions or findings
        3. Important context for continuing the conversation

        Keep summary under 500 words.
        """

        return try await MLXService.shared.generate(prompt: prompt)
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

    /// Estimates token count for messages
    func estimateTokenCount(_ messages: [Message]) -> Int {
        // Rough estimate: ~4 characters per token
        let totalCharacters = messages.reduce(0) { $0 + $1.content.count }
        return totalCharacters / 4
    }

    /// Clears cached summaries
    func clearCache() {
        messageSummaries.removeAll()
    }

    // MARK: - Smart File Inclusion

    /// Determines which files should be included in context
    /// - Parameters:
    ///   - query: Current query or task
    ///   - projectPath: Project directory
    /// - Returns: Relevant file paths
    func determineRelevantFiles(for query: String, in projectPath: String) async throws -> [String] {
        // Use codebase indexer to find relevant files
        let indexer = CodebaseIndexer.shared

        // Index if not already done
        let stats = await indexer.getStatistics()
        if stats.totalFiles == 0 {
            _ = try await indexer.indexDirectory(projectPath)
        }

        // Search for relevant files
        let results = await indexer.search(query, limit: 5)

        return results.map { $0.file.path }
    }

    /// Creates optimized context with relevant files
    /// - Parameters:
    ///   - messages: Conversation messages
    ///   - query: Current query
    ///   - projectPath: Project path
    /// - Returns: Optimized context string
    func createOptimizedContext(
        messages: [Message],
        query: String,
        projectPath: String?
    ) async throws -> String {
        var context = ""

        // Add message history (optimized)
        let optimizedMessages = try await optimizeContext(messages: messages, systemPrompt: nil)

        for message in optimizedMessages {
            context += "\(message.role.displayName): \(message.content)\n\n"
        }

        // Add relevant files if project path provided
        if let projectPath = projectPath {
            let relevantFiles = try await determineRelevantFiles(for: query, in: projectPath)

            if !relevantFiles.isEmpty {
                context += "\n--- Relevant Files ---\n\n"

                for filePath in relevantFiles.prefix(3) {  // Limit to 3 files
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
    /// - Parameter usedTokens: Tokens already used
    /// - Returns: Remaining tokens available
    func remainingBudget(used usedTokens: Int) -> Int {
        return max(0, maxTotalTokens - usedTokens)
    }

    /// Checks if more context can be added
    /// - Parameters:
    ///   - currentTokens: Current token count
    ///   - additionalContent: Content to add
    /// - Returns: Whether it fits in budget
    func canAddContent(_ additionalContent: String, currentTokens: Int) -> Bool {
        let additionalTokens = additionalContent.count / 4
        return (currentTokens + additionalTokens) < maxTotalTokens
    }
}
