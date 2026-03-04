//
//  MessageRowView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// View for displaying a single message in the chat
struct MessageRowView: View {
    /// The message to display
    let message: Message

    /// App settings for font size
    @ObservedObject private var settings = AppSettings.shared

    /// Whether code blocks should be highlighted
    @State private var showingCopyConfirmation = false
    @State private var toolCallExpanded = false
    var onContinue: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            avatar

            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Header with role and timestamp
                header

                // Message text
                messageContent

                // Actions
                if message.role == .assistant {
                    actions
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(glassCardTint)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .opacity(0.9)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(ModernColors.glassBorder, lineWidth: 2)
                )
                .shadow(color: glassCardShadow, radius: 10, y: 5)
        )
    }

    // MARK: - Subviews

    /// Avatar icon
    private var avatar: some View {
        Image(systemName: avatarIcon)
            .font(.system(size: 24))
            .foregroundColor(avatarColor)
            .frame(width: 40, height: 40)
            .background(Circle().fill(avatarColor.opacity(0.1)))
    }

    /// Header with role and timestamp
    private var header: some View {
        HStack {
            Text(message.role.displayName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(avatarColor)

            Spacer()

            Text(formatTimestamp(message.timestamp))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    /// Message content with markdown rendering
    @ViewBuilder
    private var messageContent: some View {
        if message.role == .assistant && message.content.isEmpty {
            ThinkingIndicatorView(showMessage: true, message: "Thinking")
                .padding(.vertical, 8)
        } else if isCollapsibleToolResult {
            CollapsibleToolResultView(
                message: message,
                fontSize: settings.fontSize,
                enableSyntaxHighlighting: settings.enableSyntaxHighlighting
            )
        } else if isRawToolCall {
            DisclosureGroup(isExpanded: $toolCallExpanded) {
                MarkdownTextView(
                    markdown: message.content,
                    fontSize: settings.fontSize,
                    enableSyntaxHighlighting: settings.enableSyntaxHighlighting
                )
                .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.green)
                    Text("Called: \(extractToolName())")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.green)
                }
            }
        } else {
            MarkdownTextView(
                markdown: message.content,
                fontSize: settings.fontSize,
                enableSyntaxHighlighting: settings.enableSyntaxHighlighting
            )
        }
    }

    private var isCollapsibleToolResult: Bool {
        return message.metadata?["collapsible"] == "true"
    }

    private var isRawToolCall: Bool {
        return message.role == .assistant && message.content.contains("<tool>")
    }

    private func extractToolName() -> String {
        guard let start = message.content.range(of: "<tool>"),
              let end = message.content.range(of: "</tool>") else { return "tool" }
        let json = String(message.content[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = json.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = obj["name"] as? String {
            return name
        }
        return "tool"
    }

    /// Action buttons for assistant messages
    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: copyToClipboard) {
                HStack(spacing: 6) {
                    Image(systemName: showingCopyConfirmation ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    Text(showingCopyConfirmation ? "Copied!" : "Copy")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(showingCopyConfirmation ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                .foregroundColor(showingCopyConfirmation ? .green : .blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Copy entire message to clipboard")

            if let onContinue {
                Button(action: onContinue) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                        Text("Continue")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Continue generating this response")
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Computed Properties

    private var avatarIcon: String {
        switch message.role {
        case .user:
            return "person.circle.fill"
        case .assistant:
            return "cpu"
        case .system:
            return "info.circle.fill"
        }
    }

    private var avatarColor: Color {
        switch message.role {
        case .user:
            return ModernColors.cyan
        case .assistant:
            return ModernColors.purple
        case .system:
            return ModernColors.orange
        }
    }

    private var glassCardTint: Color {
        switch message.role {
        case .user:
            return ModernColors.cyan.opacity(0.08)
        case .assistant:
            return ModernColors.purple.opacity(0.08)
        case .system:
            return ModernColors.orange.opacity(0.08)
        }
    }

    private var glassCardShadow: Color {
        switch message.role {
        case .user:
            return ModernColors.cyan.opacity(0.3)
        case .assistant:
            return ModernColors.purple.opacity(0.3)
        case .system:
            return ModernColors.orange.opacity(0.3)
        }
    }

    // MARK: - Helper Methods

    /// Formats a timestamp for display
    /// - Parameter date: The date to format
    /// - Returns: Formatted time string
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// Copies message content to clipboard
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)

        // Show confirmation
        showingCopyConfirmation = true

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showingCopyConfirmation = false
        }
    }
}

// MARK: - Preview

struct MessageRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MessageRowView(message: Message.user("Hello, can you help me with Swift code?"))

            MessageRowView(message: Message.assistant("""
            Sure! Here's a simple Swift function:

            ```swift
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
            ```

            This function takes a name and returns a greeting.
            """))

            MessageRowView(message: Message.system("System initialized"))
        }
        .padding()
        .frame(width: 600)
    }
}
