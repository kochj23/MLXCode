//
//  CodeBlockView.swift
//  MLX Code
//
//  Enhanced code block rendering with syntax highlighting
//  Created on 2025-12-09
//

import SwiftUI
import AppKit

/// Renders code blocks with syntax highlighting and copy functionality
struct CodeBlockView: View {
    let code: String
    let language: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Code content with syntax highlighting
            ScrollView([.horizontal, .vertical]) {
                Text(highlightedCode)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var highlightedCode: AttributedString {
        // Simple monospaced display without complex highlighting to avoid index issues
        // Full syntax highlighting can be added later with proper AttributedString handling
        return AttributedString(code)
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Preview

struct CodeBlockView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CodeBlockView(
                code: """
                func greet(name: String) -> String {
                    let message = "Hello, \\(name)!"
                    return message
                }
                """,
                language: "swift"
            )

            CodeBlockView(
                code: """
                def greet(name):
                    message = f"Hello, {name}!"
                    return message
                """,
                language: "python"
            )
        }
        .padding()
        .frame(width: 600)
    }
}
