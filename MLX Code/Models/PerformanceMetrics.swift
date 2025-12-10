//
//  PerformanceMetrics.swift
//  MLX Code
//
//  Performance tracking for model inference
//  Created on 2025-12-09
//

import Foundation
import Combine

/// Tracks model performance metrics in real-time
@MainActor
class PerformanceMetrics: ObservableObject {
    static let shared = PerformanceMetrics()

    // MARK: - Published Properties

    /// Tokens generated per second
    @Published var tokensPerSecond: Double = 0.0

    /// Total tokens generated in current session
    @Published var totalTokens: Int = 0

    /// Current model memory usage (bytes)
    @Published var modelMemoryUsage: Int64 = 0

    /// Average response time (seconds)
    @Published var averageResponseTime: Double = 0.0

    /// Current generation start time
    @Published var currentGenerationStart: Date?

    /// Is currently generating
    @Published var isGenerating: Bool = false

    /// History of response times
    @Published var responseTimeHistory: [Double] = []

    /// History of tokens/second
    @Published var tokensPerSecondHistory: [Double] = []

    // MARK: - Private Properties

    private var generationStartTime: Date?
    private var currentTokenCount: Int = 0
    private var responseTimes: [Double] = []
    private let maxHistorySize = 100

    private init() {}

    // MARK: - Public Methods

    /// Starts tracking a new generation
    func startGeneration() {
        generationStartTime = Date()
        currentTokenCount = 0
        isGenerating = true
        currentGenerationStart = Date()
    }

    /// Records a token being generated
    func recordToken() {
        currentTokenCount += 1
        totalTokens += 1

        // Update tokens/second
        if let startTime = generationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                tokensPerSecond = Double(currentTokenCount) / elapsed
            }
        }
    }

    /// Ends generation tracking
    func endGeneration() {
        isGenerating = false

        if let startTime = generationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)

            // Record response time
            responseTimes.append(elapsed)
            if responseTimes.count > maxHistorySize {
                responseTimes.removeFirst()
            }

            // Update average
            averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

            // Record tokens/second
            if elapsed > 0 && currentTokenCount > 0 {
                let tps = Double(currentTokenCount) / elapsed
                tokensPerSecondHistory.append(tps)
                if tokensPerSecondHistory.count > maxHistorySize {
                    tokensPerSecondHistory.removeFirst()
                }
            }

            responseTimeHistory.append(elapsed)
            if responseTimeHistory.count > maxHistorySize {
                responseTimeHistory.removeFirst()
            }
        }

        generationStartTime = nil
        currentGenerationStart = nil
    }

    /// Updates model memory usage
    func updateMemoryUsage(_ bytes: Int64) {
        modelMemoryUsage = bytes
    }

    /// Resets all metrics
    func reset() {
        tokensPerSecond = 0.0
        totalTokens = 0
        modelMemoryUsage = 0
        averageResponseTime = 0.0
        currentTokenCount = 0
        responseTimes.removeAll()
        tokensPerSecondHistory.removeAll()
        responseTimeHistory.removeAll()
        generationStartTime = nil
        isGenerating = false
    }

    // MARK: - Computed Properties

    /// Formatted tokens/second string
    var tokensPerSecondFormatted: String {
        String(format: "%.1f tok/s", tokensPerSecond)
    }

    /// Formatted memory usage string
    var memoryUsageFormatted: String {
        let mb = Double(modelMemoryUsage) / (1024 * 1024)
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            let gb = mb / 1024
            return String(format: "%.2f GB", gb)
        }
    }

    /// Formatted average response time
    var averageResponseTimeFormatted: String {
        String(format: "%.2f s", averageResponseTime)
    }

    /// Peak tokens/second
    var peakTokensPerSecond: Double {
        tokensPerSecondHistory.max() ?? 0.0
    }

    /// Average tokens/second
    var averageTokensPerSecond: Double {
        guard !tokensPerSecondHistory.isEmpty else { return 0.0 }
        return tokensPerSecondHistory.reduce(0, +) / Double(tokensPerSecondHistory.count)
    }
}
