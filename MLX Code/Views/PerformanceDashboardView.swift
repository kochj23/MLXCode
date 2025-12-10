//
//  PerformanceDashboardView.swift
//  MLX Code
//
//  Real-time performance metrics dashboard
//  Created on 2025-12-09
//

import SwiftUI
import Charts

/// Dashboard showing model performance metrics
struct PerformanceDashboardView: View {
    @ObservedObject private var metrics = PerformanceMetrics.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Performance", systemImage: "chart.xyaxis.line")
                    .font(.headline)

                Spacer()

                Button(action: { metrics.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset metrics")
            }

            Divider()

            // Live metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                metricCard(
                    title: "Speed",
                    value: metrics.tokensPerSecondFormatted,
                    icon: "gauge",
                    color: .blue
                )

                metricCard(
                    title: "Total Tokens",
                    value: "\(metrics.totalTokens)",
                    icon: "number",
                    color: .green
                )

                metricCard(
                    title: "Memory",
                    value: metrics.memoryUsageFormatted,
                    icon: "memorychip",
                    color: .orange
                )

                metricCard(
                    title: "Avg Response",
                    value: metrics.averageResponseTimeFormatted,
                    icon: "clock",
                    color: .purple
                )
            }

            // Performance graphs
            if !metrics.tokensPerSecondHistory.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tokens/Second History")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Chart {
                        ForEach(Array(metrics.tokensPerSecondHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Index", index),
                                y: .value("Tokens/s", value)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                    }
                    .frame(height: 100)

                    HStack {
                        Text("Peak: \(String(format: "%.1f", metrics.peakTokensPerSecond)) tok/s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Avg: \(String(format: "%.1f", metrics.averageTokensPerSecond)) tok/s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Real-time indicator
            if metrics.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let startTime = metrics.currentGenerationStart {
                        Text("Elapsed: \(Date().timeIntervalSince(startTime), format: .number.precision(.fractionLength(1)))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView()
            .frame(width: 400, height: 500)
    }
}
