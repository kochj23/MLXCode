//
//  ContextBudgetTests.swift
//  MLX Code Tests
//
//  Unit tests for ContextBudget: budget calculations, model heuristics,
//  ratio validation, and edge cases.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class ContextBudgetTests: XCTestCase {

    // MARK: - Budget Calculations

    func testConversationBudgetCalculation() {
        let budget = ContextBudget(
            totalBudget: 10000,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2000
        )
        XCTAssertEqual(budget.conversationBudget, 7350)
    }

    func testConversationBudgetNeverNegative() {
        let budget = ContextBudget(
            totalBudget: 100,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2000
        )
        XCTAssertEqual(budget.conversationBudget, 0, "Should clamp to 0 when allocations exceed total")
    }

    func testZeroBudget() {
        let budget = ContextBudget(
            totalBudget: 0,
            systemPromptBudget: 0,
            fewShotBudget: 0,
            outputReservation: 0
        )
        XCTAssertEqual(budget.conversationBudget, 0)
        XCTAssertEqual(budget.recentMessagesBudget, 0)
        XCTAssertEqual(budget.projectContextBudget, 0)
        XCTAssertEqual(budget.summaryBudget, 0)
    }

    // MARK: - Ratio Validation

    func testRatiosSumApproximatelyToConversationBudget() {
        let budget = ContextBudget(
            totalBudget: 32768,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: 2048
        )
        let total = budget.recentMessagesBudget + budget.projectContextBudget + budget.summaryBudget
        // Due to integer truncation, total may be slightly less than conversationBudget
        XCTAssertLessThanOrEqual(total, budget.conversationBudget)
        // But should be very close
        let diff = budget.conversationBudget - total
        XCTAssertLessThan(diff, 3, "Ratio truncation should lose at most 2 tokens")
    }

    func testRecentMessageRatio() {
        let budget = ContextBudget(
            totalBudget: 10000,
            systemPromptBudget: 500,
            fewShotBudget: 0,
            outputReservation: 500
        )
        // conversationBudget = 9000
        // recentMessages = 9000 * 0.7 = 6300
        XCTAssertEqual(budget.recentMessagesBudget, 6300)
    }

    func testProjectContextRatio() {
        let budget = ContextBudget(
            totalBudget: 10000,
            systemPromptBudget: 500,
            fewShotBudget: 0,
            outputReservation: 500
        )
        // conversationBudget = 9000
        // projectContext = 9000 * 0.2 = 1800
        XCTAssertEqual(budget.projectContextBudget, 1800)
    }

    func testSummaryRatio() {
        let budget = ContextBudget(
            totalBudget: 10000,
            systemPromptBudget: 500,
            fewShotBudget: 0,
            outputReservation: 500
        )
        // conversationBudget = 9000
        // summary = 9000 * 0.1 = 900
        XCTAssertEqual(budget.summaryBudget, 900)
    }

    // MARK: - Model-Specific Budgets

    func testOutputReservationCappedForSmallWindows() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 4096)
        // min(2048, 4096/4) = min(2048, 1024) = 1024
        XCTAssertEqual(budget.outputReservation, 1024)
    }

    func testOutputReservationCappedForLargeWindows() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 131072)
        // min(2048, 131072/4) = min(2048, 32768) = 2048
        XCTAssertEqual(budget.outputReservation, 2048)
    }

    func testDaemonWindowOverridesModelConfig() {
        let model = MLXModel(name: "Test", path: "/p", contextWindowSize: 8192)
        let budget = ContextBudget.forModel(model, daemonContextWindow: 65536)
        XCTAssertEqual(budget.totalBudget, 65536, "Daemon window should override model config")
    }

    func testModelConfigUsedWhenNoDaemon() {
        let model = MLXModel(name: "Test", path: "/p", contextWindowSize: 16384)
        let budget = ContextBudget.forModel(model, daemonContextWindow: nil)
        XCTAssertEqual(budget.totalBudget, 16384, "Model config should be used when no daemon window")
    }

    func testFallbackForUnknownModel() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: nil)
        XCTAssertEqual(budget.totalBudget, 8192, "Unknown model should default to 8192")
    }

    // MARK: - Heuristic Context Window Detection

    func testHeuristicQwen() {
        let model = MLXModel(name: "Qwen 2.5 7B", path: "/p")
        let budget = ContextBudget.forModel(model)
        XCTAssertEqual(budget.totalBudget, 32768, "Qwen models should get 32768")
    }

    func testHeuristicLlama31() {
        let model = MLXModel(name: "Llama 3.1 8B", path: "/p")
        let budget = ContextBudget.forModel(model)
        XCTAssertEqual(budget.totalBudget, 131072, "Llama 3.1 should get 131072")
    }

    func testHeuristicMistral() {
        let model = MLXModel(name: "Mistral 7B v0.3", path: "/p")
        let budget = ContextBudget.forModel(model)
        XCTAssertEqual(budget.totalBudget, 32768, "Mistral should get 32768")
    }

    func testHeuristicPhi() {
        let model = MLXModel(name: "Phi-3.5 Mini", path: "/p")
        let budget = ContextBudget.forModel(model)
        XCTAssertEqual(budget.totalBudget, 4096, "Phi should get 4096")
    }

    func testHeuristicDeepSeek() {
        let model = MLXModel(name: "DeepSeek Coder 6.7B", path: "/p")
        let budget = ContextBudget.forModel(model)
        XCTAssertEqual(budget.totalBudget, 16384, "DeepSeek should get 16384")
    }

    func testSystemPromptBudgetIsFixed() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 32768)
        XCTAssertEqual(budget.systemPromptBudget, 500, "System prompt budget should be fixed at 500")
    }

    func testFewShotBudgetIsFixed() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: 32768)
        XCTAssertEqual(budget.fewShotBudget, 150, "Few-shot budget should be fixed at 150")
    }
}
