//
//  SharedDataManager.swift
//  MLX Code Widget
//
//  Created on 2026-02-04.
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Manages shared data between the main app and widget extension
/// Uses App Group container for data persistence
class SharedDataManager {

    /// Shared singleton instance
    static let shared = SharedDataManager()

    /// App Group identifier for shared container access
    static let appGroupIdentifier = "group.com.jkoch.mlxcode"

    /// Key for storing widget data in UserDefaults
    private static let widgetDataKey = "MLXCodeWidgetData"

    /// Shared UserDefaults for App Group
    private let sharedDefaults: UserDefaults?

    /// Shared container URL
    private let containerURL: URL?

    private init() {
        sharedDefaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)
        containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDataManager.appGroupIdentifier)

        if sharedDefaults == nil {
            print("[SharedDataManager] Warning: Could not access App Group UserDefaults")
        }
        if containerURL == nil {
            print("[SharedDataManager] Warning: Could not access App Group container")
        }
    }

    // MARK: - Widget Data

    /// Saves widget data to shared container
    /// - Parameter data: Widget data to save
    func saveWidgetData(_ data: MLXCodeWidgetData) {
        guard let defaults = sharedDefaults else {
            print("[SharedDataManager] Cannot save: No access to App Group")
            return
        }

        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(data)
            defaults.set(encodedData, forKey: SharedDataManager.widgetDataKey)
            defaults.synchronize()

            print("[SharedDataManager] Widget data saved successfully")
        } catch {
            print("[SharedDataManager] Failed to save widget data: \(error)")
        }
    }

    /// Loads widget data from shared container
    /// - Returns: Saved widget data or nil if not available
    func loadWidgetData() -> MLXCodeWidgetData? {
        guard let defaults = sharedDefaults else {
            print("[SharedDataManager] Cannot load: No access to App Group")
            return nil
        }

        guard let encodedData = defaults.data(forKey: SharedDataManager.widgetDataKey) else {
            print("[SharedDataManager] No widget data found")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let data = try decoder.decode(MLXCodeWidgetData.self, from: encodedData)
            return data
        } catch {
            print("[SharedDataManager] Failed to decode widget data: \(error)")
            return nil
        }
    }

    /// Clears all widget data
    func clearWidgetData() {
        sharedDefaults?.removeObject(forKey: SharedDataManager.widgetDataKey)
        sharedDefaults?.synchronize()
        print("[SharedDataManager] Widget data cleared")
    }

    // MARK: - Convenience Methods

    /// Updates model status in widget data
    /// - Parameters:
    ///   - status: New model status
    ///   - modelName: Model name (optional)
    func updateModelStatus(_ status: ModelStatus, modelName: String? = nil) {
        var data = loadWidgetData() ?? MLXCodeWidgetData.idle

        data = MLXCodeWidgetData(
            modelStatus: status,
            modelName: modelName ?? data.modelName,
            tokensPerSecond: data.tokensPerSecond,
            memoryUsageBytes: data.memoryUsageBytes,
            totalMemoryBytes: data.totalMemoryBytes,
            activeConversations: data.activeConversations,
            lastUpdated: Date(),
            isGenerating: status == .generating,
            totalTokensGenerated: data.totalTokensGenerated,
            currentPromptPreview: data.currentPromptPreview
        )

        saveWidgetData(data)
    }

    /// Updates performance metrics in widget data
    /// - Parameters:
    ///   - tokensPerSecond: Token generation speed
    ///   - memoryUsageBytes: Current memory usage
    ///   - totalMemoryBytes: Total available memory
    func updatePerformanceMetrics(
        tokensPerSecond: Double? = nil,
        memoryUsageBytes: Int64? = nil,
        totalMemoryBytes: Int64? = nil
    ) {
        var data = loadWidgetData() ?? MLXCodeWidgetData.idle

        data = MLXCodeWidgetData(
            modelStatus: data.modelStatus,
            modelName: data.modelName,
            tokensPerSecond: tokensPerSecond ?? data.tokensPerSecond,
            memoryUsageBytes: memoryUsageBytes ?? data.memoryUsageBytes,
            totalMemoryBytes: totalMemoryBytes ?? data.totalMemoryBytes,
            activeConversations: data.activeConversations,
            lastUpdated: Date(),
            isGenerating: data.isGenerating,
            totalTokensGenerated: data.totalTokensGenerated,
            currentPromptPreview: data.currentPromptPreview
        )

        saveWidgetData(data)
    }

    /// Updates generation progress in widget data
    /// - Parameters:
    ///   - isGenerating: Whether generation is in progress
    ///   - tokensGenerated: Total tokens generated so far
    ///   - promptPreview: Preview of current prompt
    func updateGenerationProgress(
        isGenerating: Bool,
        tokensGenerated: Int? = nil,
        promptPreview: String? = nil
    ) {
        var data = loadWidgetData() ?? MLXCodeWidgetData.idle

        data = MLXCodeWidgetData(
            modelStatus: isGenerating ? .generating : (data.modelName != nil ? .loaded : .idle),
            modelName: data.modelName,
            tokensPerSecond: data.tokensPerSecond,
            memoryUsageBytes: data.memoryUsageBytes,
            totalMemoryBytes: data.totalMemoryBytes,
            activeConversations: data.activeConversations,
            lastUpdated: Date(),
            isGenerating: isGenerating,
            totalTokensGenerated: tokensGenerated ?? data.totalTokensGenerated,
            currentPromptPreview: promptPreview ?? data.currentPromptPreview
        )

        saveWidgetData(data)
    }

    /// Updates conversation count
    /// - Parameter count: Number of active conversations
    func updateConversationCount(_ count: Int) {
        var data = loadWidgetData() ?? MLXCodeWidgetData.idle

        data = MLXCodeWidgetData(
            modelStatus: data.modelStatus,
            modelName: data.modelName,
            tokensPerSecond: data.tokensPerSecond,
            memoryUsageBytes: data.memoryUsageBytes,
            totalMemoryBytes: data.totalMemoryBytes,
            activeConversations: count,
            lastUpdated: Date(),
            isGenerating: data.isGenerating,
            totalTokensGenerated: data.totalTokensGenerated,
            currentPromptPreview: data.currentPromptPreview
        )

        saveWidgetData(data)
    }

    // MARK: - System Info

    /// Gets current system memory information
    /// - Returns: Tuple of (used bytes, total bytes)
    static func getSystemMemoryInfo() -> (used: Int64, total: Int64) {
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
}
