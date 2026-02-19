//
//  ContextBudget.swift
//  MLX Code
//
//  Token budget allocation for context-window-aware message assembly.
//  Ensures system prompt, tools, recent messages, and project context
//  all fit within the model's context window.
//  Created on 2026-02-19.
//

import Foundation

/// Manages token budget allocation across context components
struct ContextBudget {
    /// Total token budget (model's context window)
    let totalBudget: Int

    /// Fixed allocation for system prompt + tool descriptions
    let systemPromptBudget: Int

    /// Fixed allocation for few-shot examples
    let fewShotBudget: Int

    /// Reserved tokens for model's response output
    let outputReservation: Int

    /// Tokens available for conversation content
    var conversationBudget: Int {
        max(0, totalBudget - systemPromptBudget - fewShotBudget - outputReservation)
    }

    /// Budget for recent messages (70% of conversation budget)
    var recentMessagesBudget: Int {
        Int(Double(conversationBudget) * 0.7)
    }

    /// Budget for project context — file tree, recent files (20%)
    var projectContextBudget: Int {
        Int(Double(conversationBudget) * 0.2)
    }

    /// Budget for conversation summary of dropped messages (10%)
    var summaryBudget: Int {
        Int(Double(conversationBudget) * 0.1)
    }

    /// Creates a context budget for the given model
    static func forModel(_ model: MLXModel?, daemonContextWindow: Int? = nil) -> ContextBudget {
        // Prefer daemon-reported context window, then model config, then name-based heuristic
        let contextWindow = daemonContextWindow
            ?? model?.contextWindowSize
            ?? detectContextWindow(modelName: model?.name ?? "")

        return ContextBudget(
            totalBudget: contextWindow,
            systemPromptBudget: 500,
            fewShotBudget: 150,
            outputReservation: min(2048, contextWindow / 4)
        )
    }

    /// Heuristic context window detection from model name
    private static func detectContextWindow(modelName: String) -> Int {
        let name = modelName.lowercased()
        if name.contains("qwen") { return 32768 }
        if name.contains("llama-3.1") || name.contains("llama 3.1") { return 131072 }
        if name.contains("llama-3.2") || name.contains("llama 3.2") { return 8192 }
        if name.contains("mistral") { return 32768 }
        if name.contains("phi") { return 4096 }
        if name.contains("deepseek") { return 16384 }
        if name.contains("codellama") { return 16384 }
        if name.contains("gemma") { return 8192 }
        return 8192  // Conservative default
    }
}
