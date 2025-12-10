//
//  EnhancedMessageView.swift
//  MLX Code
//
//  Enhanced message rendering with streaming support and syntax highlighting
//  Created on 2025-12-09
//

import SwiftUI
import AppKit

/// Enhanced message view with real-time streaming and code highlighting
struct EnhancedMessageView: View {
    let message: Message
    @State private var displayedText: String = ""
    @State private var isStreaming: Bool = false

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                if message.role == .assistant {
                    // Assistant avatar
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "brain")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        )
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                    // Message content
                    renderContent()
                        .textSelection(.enabled)
                        .padding(12)
                        .background(messageBackground)
                        .cornerRadius(12)

                    // Metadata
                    HStack(spacing: 8) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if isStreaming {
                            Text("•")
                                .foregroundColor(.secondary)
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .frame(maxWidth: message.role == .user ? 500 : .infinity, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .user {
                    // User avatar
                    Circle()
                        .fill(Color.gray.gradient)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .onAppear {
            // Simulate streaming effect for new messages
            if message.content.count > displayedText.count {
                animateStreaming()
            } else {
                displayedText = message.content
            }
        }
        .onChange(of: message.content) {
            if message.content.count > displayedText.count {
                animateStreaming()
            }
        }
    }

    private var messageBackground: some ShapeStyle {
        if message.role == .user {
            return Color.blue.opacity(0.1).gradient
        } else {
            return Color(NSColor.controlBackgroundColor).gradient
        }
    }

    @ViewBuilder
    private func renderContent() -> some View {
        let blocks = parseMarkdownBlocks(displayedText)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    Text(text)
                        .font(.body)
                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                case .inlineCode(let code):
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
    }

    private func animateStreaming() {
        isStreaming = true
        let targetText = message.content

        // Stream character by character
        let characters = Array(targetText)
        var index = displayedText.count

        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if index < characters.count {
                displayedText += String(characters[index])
                index += 1
            } else {
                timer.invalidate()
                isStreaming = false
            }
        }
    }

    private func parseMarkdownBlocks(_ text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var currentText = ""
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        var i = 0
        while i < lines.count {
            let line = String(lines[i])

            // Check for code block
            if line.hasPrefix("```") {
                // Flush current text
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }

                // Extract language
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

                // Find closing ```
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let codeLine = String(lines[i])
                    if codeLine.trimmingCharacters(in: .whitespaces) == "```" {
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }

                let code = codeLines.joined(separator: "\n")
                blocks.append(.code(code, language))
            }
            // Check for inline code
            else if line.contains("`") {
                // Simple inline code detection
                currentText += line + "\n"
            }
            else {
                currentText += line + "\n"
            }

            i += 1
        }

        // Flush remaining text
        if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return blocks.isEmpty ? [.text(text)] : blocks
    }
}

/// Message block types for rendering
enum MessageBlock {
    case text(String)
    case code(String, String)  // code, language
    case inlineCode(String)
}

// MARK: - Preview

struct EnhancedMessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnhancedMessageView(
                message: Message(
                    role: .user,
                    content: "Can you explain this code?"
                )
            )

            EnhancedMessageView(
                message: Message(
                    role: .assistant,
                    content: """
                    Sure! Here's an example:

                    ```swift
                    func calculateSum(numbers: [Int]) -> Int {
                        return numbers.reduce(0, +)
                    }
                    ```

                    This uses the `reduce` function to sum all numbers.
                    """
                )
            )
        }
        .padding()
        .frame(width: 700)
    }
}
