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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.cyan)
                    .textCase(.uppercase)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(copied ? ModernColors.accentGreen : ModernColors.textSecondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ModernColors.glassBackground)

            Divider()
                .background(ModernColors.glassBorder)

            // Code content with syntax highlighting
            ScrollView([.horizontal, .vertical]) {
                Text(highlightedCode)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(ModernColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ModernColors.glassBackground)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ModernColors.glassBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        )
        .cornerRadius(16)
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
