//
//  ContextManagerTests.swift
//  MLX Code Tests
//
//  Tests for token budgeting, context compaction, and
//  budget-aware context assembly in ContextManager / ContextBudget.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class ContextManagerTests: XCTestCase {

    // MARK: - Token Estimation

    func testEstimateTokensEmptyString() async {
        let manager = ContextManager.shared
        let tokens = await manager.estimateTokens("")
        XCTAssertEqual(tokens, 0, "Empty string should have 0 tokens")
    }

    func testEstimateTokensSingleWord() async {
        let manager = ContextManager.shared
        let tokens = await manager.estimateTokens("hello")
        XCTAssertGreaterThan(tokens, 0, "Single word should have at least 1 token")
    }

    func testEstimateTokensPlainEnglish() async {
        let manager = ContextManager.shared
        let text = "The quick brown fox jumps over the lazy dog"
        let tokens = await manager.estimateTokens(text)
        // 9 words * ~1.3 = ~11-12 tokens
        XCTAssertGreaterThanOrEqual(tokens, 9, "Should estimate at least one token per word")
        XCTAssertLessThan(tokens, 30, "Should not wildly overestimate plain English")
    }

    func testEstimateTokensCodeContent() async {
        let manager = ContextManager.shared
        let code = """
        import Foundation
        func greet() {
            let name = "World"
            print("Hello, \\(name)")
        }
        """
        let tokens = await manager.estimateTokens(code)
        // Code has indicators: "func ", "import ", "let "
        // Should use the higher multiplier (1.5) plus symbol bonus
        XCTAssertGreaterThan(tokens, 10, "Code should produce meaningful token estimate")
    }

    func testEstimateTokensCodeHigherThanPlainText() async {
        let manager = ContextManager.shared
        // Same number of words but one is code, one is plain text
        let plainText = "the quick brown fox jumps over fence gate road wall"
        let codeText = "import Foundation func doWork let value var result data"
        let plainTokens = await manager.estimateTokens(plainText)
        let codeTokens = await manager.estimateTokens(codeText)
        XCTAssertGreaterThan(codeTokens, plainTokens,
            "Code should estimate more tokens than equivalent-length plain text due to symbol density")
    }

    func testEstimateTokenCountMultipleMessages() async {
        let manager = ContextManager.shared
        let messages = [
            Message.user("Hello, how are you?"),
            Message.assistant("I am doing well, thank you for asking."),
            Message.user("Write some Swift code please.")
        ]
        let tokens = await manager.estimateTokenCount(messages)
        // Each message gets its content tokens + 4 for role markers
        XCTAssertGreaterThan(tokens, 12, "Multiple messages should have meaningful token count")
        XCTAssertGreaterThanOrEqual(tokens, 12, "Should include at least 4 tokens per message for role markers")
    }

    // MARK: - ContextBudget Calculations

    func testContextBudgetConversationBudget() {
        let budget = ContextBudget(
            totalBudget: 10000,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2000
        )
        // conversationBudget = max(0, 10000 - 500 - 150 - 2000) = 7350
        XCTAssertEqual(budget.conversationBudget, 7350)
    }

    func testContextBudgetNeverNegative() {
        let budget = ContextBudget(
            totalBudget: 100,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2000
        )
        // Should clamp to 0 when allocations exceed total
        XCTAssertEqual(budget.conversationBudget, 0, "Conversation budget should never be negative")
        XCTAssertEqual(budget.recentMessagesBudget, 0, "Recent messages budget should never be negative")
        XCTAssertEqual(budget.projectContextBudget, 0)
        XCTAssertEqual(budget.summaryBudget, 0)
    }

    func testContextBudgetRatiosSumToOne() {
        let budget = ContextBudget(
            totalBudget: 32768,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2048
        )
        let convBudget = budget.conversationBudget
        let recentRatio = Double(budget.recentMessagesBudget) / Double(convBudget)
        let projectRatio = Double(budget.projectContextBudget) / Double(convBudget)
        let summaryRatio = Double(budget.summaryBudget) / Double(convBudget)

        // Ratios should be approximately 0.7, 0.2, 0.1
        // Allow for integer truncation
        XCTAssertEqual(recentRatio, 0.7, accuracy: 0.01, "Recent messages ratio should be ~70%")
        XCTAssertEqual(projectRatio, 0.2, accuracy: 0.01, "Project context ratio should be ~20%")
        XCTAssertEqual(summaryRatio, 0.1, accuracy: 0.01, "Summary ratio should be ~10%")
    }

    func testContextBudgetOutputReservationCap() {
        // For small context windows, outputReservation = min(2048, contextWindow/4)
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 4096)
        XCTAssertEqual(budget.outputReservation, 1024, "Output reservation should be capped to contextWindow/4 for small windows")
    }

    func testContextBudgetOutputReservationLargeWindow() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 131072)
        XCTAssertEqual(budget.outputReservation, 2048, "Output reservation should be capped at 2048 for large windows")
    }

    // MARK: - Model Context Window Detection

    func testContextWindowQwen() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: nil)
        // When no model and no daemon window, falls back to detectContextWindow("")
        // Default is 8192
        XCTAssertEqual(budget.totalBudget, 8192, "Default context window should be 8192")
    }

    func testContextWindowDaemonOverride() {
        // Daemon-reported window should take priority
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 65536)
        XCTAssertEqual(budget.totalBudget, 65536, "Daemon context window should override defaults")
    }

    // MARK: - Remaining Budget

    func testRemainingBudgetCalculation() async {
        let manager = ContextManager.shared
        let remaining = await manager.remainingBudget(used: 20000)
        XCTAssertEqual(remaining, 12000, "Remaining budget should be maxTotalTokens - used (32000 - 20000)")
    }

    func testRemainingBudgetNeverNegative() async {
        let manager = ContextManager.shared
        let remaining = await manager.remainingBudget(used: 50000)
        XCTAssertEqual(remaining, 0, "Remaining budget should never be negative")
    }

    func testRemainingBudgetZeroUsed() async {
        let manager = ContextManager.shared
        let remaining = await manager.remainingBudget(used: 0)
        XCTAssertEqual(remaining, 32000, "Remaining budget should equal maxTotalTokens when nothing used")
    }

    // MARK: - Can Add Content

    func testCanAddContentWithinBudget() async {
        let manager = ContextManager.shared
        let canAdd = await manager.canAddContent("short string", currentTokens: 100)
        XCTAssertTrue(canAdd, "Should be able to add small content when well under budget")
    }

    func testCanAddContentExceedsBudget() async {
        let manager = ContextManager.shared
        // Create a very long string that will exceed budget
        let longContent = String(repeating: "word ", count: 50000)
        let canAdd = await manager.canAddContent(longContent, currentTokens: 30000)
        XCTAssertFalse(canAdd, "Should not be able to add content that exceeds budget")
    }

    func testCanAddContentExactlyAtBudget() async {
        let manager = ContextManager.shared
        // currentTokens at 31999, adding one word (~1-2 tokens) should still fit
        let canAdd = await manager.canAddContent("hello", currentTokens: 31999)
        XCTAssertFalse(canAdd, "Content at the boundary should be rejected (must be strictly less than maxTotalTokens)")
    }

    // MARK: - Legacy Context Optimization

    func testOptimizeContextUnderBudget() async throws {
        let manager = ContextManager.shared
        // Small conversation that fits within budget
        let messages = [
            Message.user("Hello"),
            Message.assistant("Hi there!"),
            Message.user("How are you?"),
            Message.assistant("I am great, thanks!")
        ]

        let optimized = try await manager.optimizeContext(messages: messages, systemPrompt: nil)
        XCTAssertEqual(optimized.count, messages.count,
            "Messages under budget should be returned as-is")
    }

    func testOptimizeContextOverBudget() async throws {
        let manager = ContextManager.shared
        // Create a conversation that exceeds 32000 tokens
        var messages: [Message] = []
        for i in 0..<200 {
            let longContent = String(repeating: "word \(i) ", count: 50)
            messages.append(Message.user(longContent))
            messages.append(Message.assistant("Response to message \(i). " + String(repeating: "detail ", count: 30)))
        }

        let optimized = try await manager.optimizeContext(messages: messages, systemPrompt: nil)

        XCTAssertLessThan(optimized.count, messages.count,
            "Over-budget conversation should be compacted")
        // Should have summary + recent messages
        // Recent = last 10 messages; compacted should be summary + 10
        XCTAssertLessThanOrEqual(optimized.count, 11,
            "Optimized should contain at most summary + 10 recent messages")
    }

    func testOptimizeContextPreservesRecentMessages() async throws {
        let manager = ContextManager.shared
        var messages: [Message] = []
        for i in 0..<200 {
            messages.append(Message.user("Message \(i)"))
            messages.append(Message.assistant("Reply \(i) " + String(repeating: "padding ", count: 50)))
        }

        let optimized = try await manager.optimizeContext(messages: messages, systemPrompt: nil)

        // The most recent messages should be preserved
        guard let lastOptimized = optimized.last else {
            XCTFail("Optimized context should not be empty")
            return
        }
        guard let lastOriginal = messages.last else {
            XCTFail("Original messages should not be empty")
            return
        }
        XCTAssertEqual(lastOptimized.content, lastOriginal.content,
            "Most recent message should be preserved after compaction")
    }

    func testOptimizeContextIncludesSummary() async throws {
        let manager = ContextManager.shared
        var messages: [Message] = []
        for i in 0..<200 {
            messages.append(Message.user("Question about topic \(i)"))
            messages.append(Message.assistant("Answer about topic \(i) " + String(repeating: "detail ", count: 50)))
        }

        let optimized = try await manager.optimizeContext(messages: messages, systemPrompt: nil)

        // First message should be the summary
        guard let firstMessage = optimized.first else {
            XCTFail("Optimized context should not be empty")
            return
        }
        XCTAssertEqual(firstMessage.role, .system,
            "First message in compacted context should be a system summary")
        XCTAssertTrue(firstMessage.content.contains("summary"),
            "Summary message should contain the word 'summary'")
    }

    // MARK: - Budget-Aware Context Assembly

    func testAssembleContextIncludesSystemPrompt() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 8192,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 1024
        )
        let messages = [
            Message.user("Hello"),
            Message.assistant("Hi!")
        ]

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "You are a helpful assistant.",
            projectPath: nil,
            budget: budget
        )

        XCTAssertFalse(assembled.isEmpty, "Assembled context should not be empty")
        XCTAssertEqual(assembled.first?.role, .system,
            "First message should be system prompt")
        XCTAssertEqual(assembled.first?.content, "You are a helpful assistant.")
    }

    func testAssembleContextFiltersSystemMessages() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 8192,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 1024
        )
        let messages = [
            Message.system("Old system message"),
            Message.user("Hello"),
            Message.assistant("Hi!"),
            Message.system("Tool result"),
            Message.user("Another question")
        ]

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "New system prompt",
            projectPath: nil,
            budget: budget
        )

        // Should have: system prompt + user-Hello + assistant-Hi! + user-AnotherQuestion
        // System messages from original are filtered out of the "non-system" recent messages
        let systemMessages = assembled.filter { $0.role == .system }
        let nonSystemMessages = assembled.filter { $0.role != .system }

        XCTAssertEqual(systemMessages.first?.content, "New system prompt",
            "Injected system prompt should be first")
        XCTAssertTrue(nonSystemMessages.count <= 3,
            "Non-system messages should be the recent user/assistant turns")
    }

    func testAssembleContextRespectsBudget() async {
        let manager = ContextManager.shared
        // Very tight budget that can only fit a few messages
        let budget = ContextBudget(
            totalBudget: 500,
            systemPromptBudget: 100,
            fewShotBudget: 50,
            outputReservation: 100
        )
        // conversationBudget = max(0, 500-100-50-100) = 250
        // recentMessagesBudget = 250 * 0.7 = 175

        var messages: [Message] = []
        for i in 0..<50 {
            messages.append(Message.user("Question \(i) " + String(repeating: "padding ", count: 20)))
            messages.append(Message.assistant("Answer \(i) " + String(repeating: "detail ", count: 20)))
        }

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "System prompt",
            projectPath: nil,
            budget: budget
        )

        // The assembled context should be smaller than the original
        XCTAssertLessThan(assembled.count, messages.count + 1,
            "Assembled context should be smaller than original when budget is tight")
    }

    func testAssembleContextCreatesCompactionSummary() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 1000,
            systemPromptBudget: 100,
            fewShotBudget: 50,
            outputReservation: 200
        )

        var messages: [Message] = []
        for i in 0..<100 {
            messages.append(Message.user("Question about topic \(i)"))
            messages.append(Message.assistant("Detailed answer \(i) " + String(repeating: "context ", count: 15)))
        }

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "System prompt",
            projectPath: nil,
            budget: budget
        )

        // Should have a summary message for dropped older messages
        let summaryMessages = assembled.filter {
            $0.role == .system && $0.content.contains("Earlier conversation summary")
        }
        XCTAssertFalse(summaryMessages.isEmpty,
            "Should include a compaction summary when messages are dropped")
    }

    // MARK: - Compaction Preserves Key Information

    func testCompactionPreservesUserIntentPreviews() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 1000,
            systemPromptBudget: 100,
            fewShotBudget: 50,
            outputReservation: 200
        )

        let messages = [
            Message.user("Write a SwiftUI view for user profiles"),
            Message.assistant("Sure, here is a SwiftUI view. " + String(repeating: "code ", count: 200)),
            Message.user("Add dark mode support to the profile view"),
            Message.assistant("Done, I added dark mode. " + String(repeating: "more code ", count: 200)),
            Message.user("Now add unit tests"),  // This is the most recent, should be in recent messages
        ]

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "System",
            projectPath: nil,
            budget: budget
        )

        // The most recent user message should definitely be in the assembled context
        let lastUserMessage = assembled.last { $0.role == .user }
        XCTAssertNotNil(lastUserMessage, "Most recent user message should be preserved")
    }

    // MARK: - Cache Management

    func testClearCacheDoesNotCrash() async {
        let manager = ContextManager.shared
        await manager.clearCache()
        // Just verify it doesn't crash
    }

    // MARK: - Boundary Conditions

    func testEmptyMessageArray() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 8192,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 1024
        )

        let assembled = await manager.assembleContext(
            messages: [],
            systemPrompt: "System prompt",
            projectPath: nil,
            budget: budget
        )

        XCTAssertEqual(assembled.count, 1, "Empty messages should produce only the system prompt")
        XCTAssertEqual(assembled.first?.role, .system)
    }

    func testSingleMessage() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 8192,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 1024
        )

        let messages = [Message.user("Hello")]

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "System",
            projectPath: nil,
            budget: budget
        )

        // System prompt + the single user message
        XCTAssertEqual(assembled.count, 2)
    }

    func testZeroBudgetTotalDoesNotCrash() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 0,
            systemPromptBudget: 0,
            fewShotBudget: 0,
            outputReservation: 0
        )

        let messages = [Message.user("Hello")]

        let assembled = await manager.assembleContext(
            messages: messages,
            systemPrompt: "System",
            projectPath: nil,
            budget: budget
        )

        // Should at least include system prompt even at zero budget
        XCTAssertGreaterThanOrEqual(assembled.count, 1, "Should not crash on zero budget")
    }

    // MARK: - Performance

    func testAssembleContextPerformance() async {
        let manager = ContextManager.shared
        let budget = ContextBudget(
            totalBudget: 32768,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2048
        )

        var messages: [Message] = []
        for i in 0..<500 {
            messages.append(Message.user("Message \(i)"))
            messages.append(Message.assistant("Reply \(i)"))
        }

        // Performance test: assembling context for 1000 messages should be fast
        let startTime = Date()
        for _ in 0..<10 {
            _ = await manager.assembleContext(
                messages: messages,
                systemPrompt: "System prompt",
                projectPath: nil,
                budget: budget
            )
        }
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 5.0,
            "10 context assemblies of 1000 messages should complete in under 5 seconds")
    }
}
