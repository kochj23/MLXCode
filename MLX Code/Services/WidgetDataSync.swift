//
//  WidgetDataSync.swift
//  MLX Code
//
//  Created on 2026-02-04.
//  Copyright 2026 Jordan Koch. All rights reserved.
//
//  Syncs app state to the widget extension via App Group shared container

import Foundation
import WidgetKit

/// Manages synchronization of app state to the widget
@MainActor
class WidgetDataSync {

    /// Shared singleton instance
    static let shared = WidgetDataSync()

    /// App Group identifier for shared container access
    private static let appGroupIdentifier = "group.com.jkoch.mlxcode"

    /// Key for storing widget data in UserDefaults
    private static let widgetDataKey = "MLXCodeWidgetData"

    /// Shared UserDefaults for App Group
    private let sharedDefaults: UserDefaults?

    /// Performance metrics tracking
    private var lastTokenCount: Int = 0
    private var lastTokenTime: Date = Date()
    private var tokensPerSecond: Double = 0.0
    private var totalTokensGenerated: Int = 0

    private init() {
        sharedDefaults = UserDefaults(suiteName: WidgetDataSync.appGroupIdentifier)

        if sharedDefaults == nil {
            print("[WidgetDataSync] Warning: Could not access App Group UserDefaults")
        }
    }

    // MARK: - Public API

    /// Updates widget with current model status
    /// - Parameters:
    ///   - isLoaded: Whether a model is loaded
    ///   - modelName: Name of the loaded model
    ///   - isGenerating: Whether generation is in progress
    func updateModelStatus(isLoaded: Bool, modelName: String?, isGenerating: Bool) {
        let status: WidgetModelStatus
        if isGenerating {
            status = .generating
        } else if isLoaded {
            status = .loaded
        } else {
            status = .idle
        }

        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: status,
            modelName: modelName,
            tokensPerSecond: tokensPerSecond,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: isGenerating,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: nil
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Updates widget when model loading starts
    func updateModelLoading() {
        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .loading,
            modelName: nil,
            tokensPerSecond: nil,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: false,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: nil
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Updates widget when model is loaded
    /// - Parameter modelName: Name of the loaded model
    func updateModelLoaded(modelName: String) {
        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .loaded,
            modelName: modelName,
            tokensPerSecond: nil,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: false,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: nil
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Updates widget when model is unloaded
    func updateModelUnloaded() {
        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .idle,
            modelName: nil,
            tokensPerSecond: nil,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: false,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: nil
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Updates widget during token generation
    /// - Parameters:
    ///   - modelName: Name of the model generating
    ///   - tokenCount: Number of tokens generated so far
    ///   - promptPreview: Preview of the prompt being processed
    func updateGenerationProgress(modelName: String, tokenCount: Int, promptPreview: String?) {
        // Calculate tokens per second
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastTokenTime)
        let tokenDelta = tokenCount - lastTokenCount

        if timeDelta > 0.1 && tokenDelta > 0 {
            tokensPerSecond = Double(tokenDelta) / timeDelta
            lastTokenCount = tokenCount
            lastTokenTime = now
        }

        totalTokensGenerated += tokenDelta > 0 ? tokenDelta : 0

        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .generating,
            modelName: modelName,
            tokensPerSecond: tokensPerSecond,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: true,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: promptPreview?.prefix(100).description
        )

        saveWidgetData(data)
        // Don't reload widget during generation to avoid UI flicker
    }

    /// Updates widget when generation completes
    /// - Parameter modelName: Name of the model
    func updateGenerationComplete(modelName: String) {
        lastTokenCount = 0
        lastTokenTime = Date()

        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .loaded,
            modelName: modelName,
            tokensPerSecond: tokensPerSecond,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: false,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: nil
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Updates widget when an error occurs
    /// - Parameter message: Error message
    func updateError(message: String) {
        let memoryInfo = getSystemMemoryInfo()

        let data = WidgetData(
            modelStatus: .error,
            modelName: nil,
            tokensPerSecond: nil,
            memoryUsageBytes: memoryInfo.used,
            totalMemoryBytes: memoryInfo.total,
            activeConversations: getActiveConversationCount(),
            lastUpdated: Date(),
            isGenerating: false,
            totalTokensGenerated: totalTokensGenerated,
            currentPromptPreview: message
        )

        saveWidgetData(data)
        reloadWidget()
    }

    /// Resets token statistics (call when starting a new session)
    func resetTokenStats() {
        totalTokensGenerated = 0
        tokensPerSecond = 0.0
        lastTokenCount = 0
        lastTokenTime = Date()
    }

    // MARK: - Private Methods

    /// Saves widget data to shared container
    private func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            print("[WidgetDataSync] Cannot save: No access to App Group")
            return
        }

        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(data)
            defaults.set(encodedData, forKey: WidgetDataSync.widgetDataKey)
            defaults.synchronize()
        } catch {
            print("[WidgetDataSync] Failed to save widget data: \(error)")
        }
    }

    /// Requests widget reload
    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "MLXCodeWidget")
    }

    /// Gets system memory information
    private func getSystemMemoryInfo() -> (used: Int64, total: Int64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let usedBytes: Int64 = result == KERN_SUCCESS ? Int64(info.resident_size) : 0
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)

        return (usedBytes, totalBytes)
    }

    /// Gets the count of active conversations
    private func getActiveConversationCount() -> Int {
        // This could be integrated with ConversationManager
        // For now, return a default value
        return 1
    }
}

// MARK: - Widget Data Model (for main app)

/// Data model shared with widget
struct WidgetData: Codable {
    let modelStatus: WidgetModelStatus
    let modelName: String?
    let tokensPerSecond: Double?
    let memoryUsageBytes: Int64?
    let totalMemoryBytes: Int64?
    let activeConversations: Int
    let lastUpdated: Date
    let isGenerating: Bool
    let totalTokensGenerated: Int
    let currentPromptPreview: String?
}

/// Model status for widget
enum WidgetModelStatus: String, Codable {
    case idle
    case loading
    case loaded
    case generating
    case error
}
