//
//  PerformanceCard.swift
//  MLX Code
//
//  Real-time performance monitoring with circular gauges
//
//  Created by Jordan Koch on 1/15/2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct PerformanceCard: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.cyan)

                Text("Performance")
                    .modernHeader(size: .medium)

                Spacer()
            }

            // Three circular gauges
            HStack(spacing: 24) {
                // Tokens per second
                VStack(spacing: 8) {
                    CircularGauge(
                        value: min((performanceMonitor.tokensPerSecond / 50.0) * 100.0, 100.0),
                        color: ModernColors.heatColor(percentage: min((performanceMonitor.tokensPerSecond / 50.0) * 100.0, 100.0)),
                        size: 70,
                        lineWidth: 8,
                        showValue: false
                    )

                    Text("\(Int(performanceMonitor.tokensPerSecond))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.cyan)

                    Text("tokens/sec")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)
                }

                // Model temperature
                VStack(spacing: 8) {
                    CircularGauge(
                        value: (performanceMonitor.temperature / 2.0) * 100.0,
                        color: ModernColors.orange,
                        size: 70,
                        lineWidth: 8,
                        showValue: false
                    )

                    Text(String(format: "%.1f", performanceMonitor.temperature))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.orange)

                    Text("temperature")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)
                }

                // Context utilization
                VStack(spacing: 8) {
                    CircularGauge(
                        value: performanceMonitor.contextUtilization,
                        color: ModernColors.heatColor(percentage: performanceMonitor.contextUtilization),
                        size: 70,
                        lineWidth: 8,
                        showValue: true,
                        label: "context"
                    )

                    Text("utilization")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .glassCard()
    }
}

/// Monitors real-time performance metrics for the MLX model
class PerformanceMonitor: ObservableObject {
    @Published var tokensPerSecond: Double = 0.0
    @Published var temperature: Double = 0.7 // Default model temperature
    @Published var contextUtilization: Double = 0.0 // 0-100%

    @Published var totalTokens: Int = 0
    @Published var usedTokens: Int = 0
    @Published var maxTokens: Int = 128000 // Default context window

    // Update context utilization
    func updateContext(used: Int, max: Int) {
        self.usedTokens = used
        self.maxTokens = max
        self.contextUtilization = max > 0 ? (Double(used) / Double(max)) * 100.0 : 0.0
    }

    // Update tokens per second (calculated from generation speed)
    func updateTokensPerSecond(tokens: Int, duration: TimeInterval) {
        guard duration > 0 else { return }
        self.tokensPerSecond = Double(tokens) / duration
    }

    // Update model temperature
    func updateTemperature(_ temp: Double) {
        self.temperature = temp
    }

    // Track total tokens generated
    func addTokens(_ count: Int) {
        self.totalTokens += count
    }

    // Reset for new session
    func reset() {
        self.tokensPerSecond = 0.0
        self.contextUtilization = 0.0
        self.usedTokens = 0
    }
}
