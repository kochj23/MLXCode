//
//  TokenMetricsView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// View displaying token performance metrics
/// Shows tokens/sec as a dial indicator and total tokens as a number
struct TokenMetricsView: View {
    /// Chat view model for accessing token metrics
    @ObservedObject var viewModel: ChatViewModel

    /// Whether the panel is expanded
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("Performance Metrics")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            if isExpanded {
                Divider()

                // Metrics content
                HStack(spacing: 24) {
                    // Tokens per second dial
                    VStack(spacing: 8) {
                        Text("Avg Tokens/Sec")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Gauge/Dial indicator
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 80, height: 80)

                            // Progress arc
                            Circle()
                                .trim(from: 0, to: min(viewModel.conversationAverageTokensPerSecond / 100.0, 1.0))
                                .stroke(
                                    tokensPerSecondColor,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: viewModel.conversationAverageTokensPerSecond)

                            // Center value
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", viewModel.conversationAverageTokensPerSecond))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("t/s")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()
                        .frame(height: 80)

                    // Total tokens counter
                    VStack(spacing: 8) {
                        Text("Total Tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Number box
                        VStack(spacing: 4) {
                            Text("\(viewModel.conversationTotalTokens)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(minWidth: 100)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                )

                            // Current generation tokens
                            if viewModel.isGenerating {
                                Text("Current: \(viewModel.currentTokenCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Current speed (real-time during generation)
                    if viewModel.isGenerating {
                        VStack(spacing: 8) {
                            Text("Current Speed")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                Text(String(format: "%.1f t/s", viewModel.tokensPerSecond))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    /// Color for tokens per second gauge based on speed
    private var tokensPerSecondColor: Color {
        let speed = viewModel.conversationAverageTokensPerSecond
        if speed < 20 {
            return .red
        } else if speed < 40 {
            return .orange
        } else if speed < 60 {
            return .yellow
        } else {
            return .green
        }
    }
}

/// Preview provider for TokenMetricsView
#Preview {
    let viewModel = ChatViewModel()
    viewModel.conversationAverageTokensPerSecond = 45.7
    viewModel.conversationTotalTokens = 1234
    viewModel.tokensPerSecond = 52.3
    viewModel.currentTokenCount = 89
    viewModel.isGenerating = true

    return TokenMetricsView(viewModel: viewModel)
        .frame(width: 600, height: 150)
        .padding()
}
