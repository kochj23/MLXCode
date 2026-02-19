//
//  WidgetData.swift
//  MLX Code Widget
//
//  Created on 2026-02-04.
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Data model for widget display
/// Shared between the main app and widget extension via App Group
struct MLXCodeWidgetData: Codable {
    /// Model status
    let modelStatus: ModelStatus

    /// Name of the currently loaded model (nil if no model loaded)
    let modelName: String?

    /// Token generation speed (tokens per second)
    let tokensPerSecond: Double?

    /// Memory usage in bytes
    let memoryUsageBytes: Int64?

    /// Total memory available in bytes
    let totalMemoryBytes: Int64?

    /// Number of active conversations
    let activeConversations: Int

    /// Last update timestamp
    let lastUpdated: Date

    /// Whether inference is currently running
    let isGenerating: Bool

    /// Total tokens generated in current session
    let totalTokensGenerated: Int

    /// Current prompt being processed (truncated)
    let currentPromptPreview: String?

    init(
        modelStatus: ModelStatus = .idle,
        modelName: String? = nil,
        tokensPerSecond: Double? = nil,
        memoryUsageBytes: Int64? = nil,
        totalMemoryBytes: Int64? = nil,
        activeConversations: Int = 0,
        lastUpdated: Date = Date(),
        isGenerating: Bool = false,
        totalTokensGenerated: Int = 0,
        currentPromptPreview: String? = nil
    ) {
        self.modelStatus = modelStatus
        self.modelName = modelName
        self.tokensPerSecond = tokensPerSecond
        self.memoryUsageBytes = memoryUsageBytes
        self.totalMemoryBytes = totalMemoryBytes
        self.activeConversations = activeConversations
        self.lastUpdated = lastUpdated
        self.isGenerating = isGenerating
        self.totalTokensGenerated = totalTokensGenerated
        self.currentPromptPreview = currentPromptPreview
    }

    /// Default placeholder data for widget preview
    static var placeholder: MLXCodeWidgetData {
        MLXCodeWidgetData(
            modelStatus: .loaded,
            modelName: "Qwen 2.5 7B",
            tokensPerSecond: 42.5,
            memoryUsageBytes: 4_500_000_000,
            totalMemoryBytes: 16_000_000_000,
            activeConversations: 3,
            isGenerating: false,
            totalTokensGenerated: 1250
        )
    }

    /// Empty/idle state data
    static var idle: MLXCodeWidgetData {
        MLXCodeWidgetData(
            modelStatus: .idle,
            modelName: nil,
            tokensPerSecond: nil,
            memoryUsageBytes: nil,
            totalMemoryBytes: nil,
            activeConversations: 0,
            isGenerating: false,
            totalTokensGenerated: 0
        )
    }
}

/// Model loading/running status
enum ModelStatus: String, Codable {
    case idle = "idle"
    case loading = "loading"
    case loaded = "loaded"
    case generating = "generating"
    case error = "error"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading..."
        case .loaded: return "Ready"
        case .generating: return "Generating"
        case .error: return "Error"
        }
    }

    var systemImageName: String {
        switch self {
        case .idle: return "moon.zzz"
        case .loading: return "arrow.down.circle"
        case .loaded: return "checkmark.circle.fill"
        case .generating: return "bolt.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var statusColor: String {
        switch self {
        case .idle: return "gray"
        case .loading: return "orange"
        case .loaded: return "green"
        case .generating: return "blue"
        case .error: return "red"
        }
    }
}

/// Quick command actions available from widget
enum WidgetQuickCommand: String, CaseIterable, Identifiable {
    case newChat = "new_chat"
    case generateCode = "generate_code"
    case reviewCode = "review_code"
    case explainCode = "explain_code"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newChat: return "New Chat"
        case .generateCode: return "Generate"
        case .reviewCode: return "Review"
        case .explainCode: return "Explain"
        }
    }

    var systemImageName: String {
        switch self {
        case .newChat: return "plus.bubble"
        case .generateCode: return "wand.and.stars"
        case .reviewCode: return "magnifyingglass"
        case .explainCode: return "questionmark.circle"
        }
    }

    /// Deep link URL for the command
    var deepLinkURL: URL {
        URL(string: "mlxcode://\(rawValue)")!
    }
}

/// Memory formatting utilities
extension MLXCodeWidgetData {
    /// Formatted memory usage string (e.g., "4.5 GB")
    var formattedMemoryUsage: String {
        guard let bytes = memoryUsageBytes else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    /// Formatted total memory string
    var formattedTotalMemory: String {
        guard let bytes = totalMemoryBytes else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    /// Memory usage percentage (0.0 to 1.0)
    var memoryUsagePercent: Double {
        guard let used = memoryUsageBytes, let total = totalMemoryBytes, total > 0 else {
            return 0.0
        }
        return Double(used) / Double(total)
    }

    /// Formatted tokens per second string
    var formattedTokenSpeed: String {
        guard let tps = tokensPerSecond else { return "--" }
        return String(format: "%.1f tok/s", tps)
    }

    /// Time since last update
    var timeSinceUpdate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}
