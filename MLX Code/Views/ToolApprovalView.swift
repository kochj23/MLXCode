//
//  ToolApprovalView.swift
//  MLX Code
//
//  Inline tool approval UI shown when LLM requests tool execution.
//  Created on 2026-02-19.
//

import SwiftUI

/// Inline view showing pending tool calls with approve/deny actions
struct ToolApprovalView: View {
    let pendingCalls: [PendingToolCall]
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                Text("Tool Execution Request")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(pendingCalls.count) tool\(pendingCalls.count == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Tool call list
            ForEach(pendingCalls) { call in
                HStack(spacing: 8) {
                    Image(systemName: call.approved ? "checkmark.circle.fill" : "questionmark.circle")
                        .foregroundColor(call.approved ? .green : .orange)
                        .font(.system(size: 14))
                    Text(call.toolName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(call.summary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 2)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])

                Button(action: onDeny) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Deny")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
