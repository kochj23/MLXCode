//
//  CollapsibleToolResultView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// View for displaying collapsible tool execution results
struct CollapsibleToolResultView: View {
    /// The message containing tool results
    let message: Message

    /// Font size for content
    let fontSize: CGFloat

    /// Whether to enable syntax highlighting
    let enableSyntaxHighlighting: Bool

    /// Whether the disclosure group is expanded
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status indicator
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Status indicator circle
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: statusColor.opacity(0.6), radius: 4)

                    Image(systemName: statusIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(statusColor)

                    Text(statusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)

                    Spacer()

                    // Circular progress indicator for running status
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ModernColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(statusBackgroundColor)

            // Expanded content
            if isExpanded {
                Divider()
                    .background(ModernColors.glassBorder)

                MarkdownTextView(
                    markdown: message.content,
                    fontSize: fontSize,
                    enableSyntaxHighlighting: enableSyntaxHighlighting
                )
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ModernColors.glassBackground)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: statusColor.opacity(0.2), radius: 8, y: 4)
        )
        .cornerRadius(16)
        .onAppear {
            // Check if metadata says it should be collapsed
            isExpanded = message.metadata?["collapsed"] != "true"
        }
    }

    // MARK: - Computed Properties

    /// Status derived from metadata
    private var status: ToolStatus {
        guard let statusString = message.metadata?["status"] else {
            return .success
        }
        return ToolStatus(rawValue: statusString) ?? .success
    }

    /// Whether the tool is currently running
    private var isRunning: Bool {
        status == .running
    }

    /// Status color
    private var statusColor: Color {
        switch status {
        case .success:
            return ModernColors.accentGreen
        case .running:
            return ModernColors.orange
        case .error:
            return ModernColors.statusCritical
        }
    }

    /// Status background color
    private var statusBackgroundColor: Color {
        switch status {
        case .success:
            return ModernColors.accentGreen.opacity(0.1)
        case .running:
            return ModernColors.orange.opacity(0.1)
        case .error:
            return ModernColors.statusCritical.opacity(0.1)
        }
    }

    /// Status icon
    private var statusIcon: String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .running:
            return "arrow.trianglehead.clockwise"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Status text
    private var statusText: String {
        switch status {
        case .success:
            return "Tool Execution Complete"
        case .running:
            return "Tool Executing..."
        case .error:
            return "Tool Execution Failed"
        }
    }
}

/// Tool execution status
enum ToolStatus: String {
    case success
    case running
    case error
}

/// Preview provider for CollapsibleToolResultView
#Preview {
    CollapsibleToolResultView(
        message: Message(
            role: .system,
            content: """
            # Tool Execution Results

            ## Tool Call 1
            ```json
            {
              "success": true,
              "output": "File read successfully"
            }
            ```
            """,
            metadata: ["collapsible": "true", "collapsed": "true"]
        ),
        fontSize: 14,
        enableSyntaxHighlighting: true
    )
    .padding()
    .frame(width: 600)
}
