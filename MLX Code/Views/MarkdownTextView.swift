//
//  MarkdownTextView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI
import AppKit

/// A SwiftUI view that renders markdown text with syntax highlighting
/// Supports: headings, bold, italic, code blocks, inline code, lists, links
struct MarkdownTextView: View {
    /// The markdown text to render
    let markdown: String

    /// Font size for rendering
    let fontSize: CGFloat

    /// Whether to enable syntax highlighting for code blocks
    let enableSyntaxHighlighting: Bool

    /// State for tracking copy confirmation
    @State private var copiedCodeBlockIndex: Int?

    /// Initializes a new markdown text view
    /// - Parameters:
    ///   - markdown: The markdown text to render
    ///   - fontSize: Font size (default: 14)
    ///   - enableSyntaxHighlighting: Enable syntax highlighting (default: true)
    init(
        markdown: String,
        fontSize: CGFloat = 14,
        enableSyntaxHighlighting: Bool = true
    ) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.enableSyntaxHighlighting = enableSyntaxHighlighting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let blocks = parseMarkdown(markdown)
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                renderBlock(block, index: index)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Block Rendering

    /// Renders a single markdown block
    /// - Parameters:
    ///   - block: The block to render
    ///   - index: Index of the block
    /// - Returns: View representing the block
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock, index: Int) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(text: text, level: level)

        case .codeBlock(let language, let code):
            codeBlockView(code: code, language: language, index: index)

        case .list(let items, let ordered):
            listView(items: items, ordered: ordered)

        case .paragraph(let text):
            paragraphView(text: text)

        case .separator:
            Divider()
                .padding(.vertical, 8)
        }
    }

    /// Renders a heading
    /// - Parameters:
    ///   - text: Heading text
    ///   - level: Heading level (1-6)
    /// - Returns: Heading view
    private func headingView(text: String, level: Int) -> some View {
        let headingFontSize = fontSize * (2.0 - CGFloat(level) * 0.2)
        return Text(parseInlineMarkdown(text))
            .font(.system(size: headingFontSize, weight: .bold))
            .foregroundColor(ModernColors.textPrimary)
            .padding(.top, level == 1 ? 8 : 4)
            .padding(.bottom, 4)
    }

    /// Renders a paragraph
    /// - Parameter text: Paragraph text
    /// - Returns: Paragraph view
    private func paragraphView(text: String) -> some View {
        Text(parseInlineMarkdown(text))
            .font(.system(size: fontSize))
            .foregroundColor(ModernColors.textPrimary)
            .padding(.vertical, 2)
    }

    /// Renders a code block with optional syntax highlighting
    /// - Parameters:
    ///   - code: Code content
    ///   - language: Programming language
    ///   - index: Block index for copy button
    /// - Returns: Code block view
    private func codeBlockView(code: String, language: String?, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label if available
            if let lang = language, !lang.isEmpty {
                HStack {
                    Text(lang.uppercased())
                        .font(.system(size: fontSize - 2, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)

                    Spacer()

                    copyButton(for: code, index: index)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                if enableSyntaxHighlighting, let language = language {
                    Text(highlightCode(code, language: language))
                        .font(.system(size: fontSize, design: .monospaced))
                        .padding(12)
                } else {
                    Text(code)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))

            // Copy button if no language label
            if language == nil || language?.isEmpty == true {
                HStack {
                    Spacer()
                    copyButton(for: code, index: index)
                }
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    /// Renders a copy button for code blocks
    /// - Parameters:
    ///   - code: Code to copy
    ///   - index: Block index
    /// - Returns: Copy button view
    private func copyButton(for code: String, index: Int) -> some View {
        Button(action: {
            copyToClipboard(code)
            copiedCodeBlockIndex = index

            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if copiedCodeBlockIndex == index {
                    copiedCodeBlockIndex = nil
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: copiedCodeBlockIndex == index ? "checkmark" : "doc.on.doc")
                    .font(.system(size: fontSize - 2))
                Text(copiedCodeBlockIndex == index ? "Copied!" : "Copy")
                    .font(.system(size: fontSize - 2))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// Renders a list (ordered or unordered)
    /// - Parameters:
    ///   - items: List items
    ///   - ordered: Whether list is ordered
    /// - Returns: List view
    private func listView(items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: fontSize))
                        .foregroundColor(ModernColors.textPrimary)
                        .frame(width: 20, alignment: .trailing)

                    Text(parseInlineMarkdown(item))
                        .font(.system(size: fontSize))
                        .foregroundColor(ModernColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 8)
    }

    // MARK: - Markdown Parsing

    /// Parses markdown into blocks
    /// - Parameter text: Markdown text
    /// - Returns: Array of markdown blocks
    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentParagraph = ""
        var inCodeBlock = false
        var currentCodeBlock = ""
        var currentCodeLanguage: String?
        var currentListItems: [String] = []
        var currentListOrdered = false

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Code block handling
            if line.hasPrefix("```") {
                // Finish current paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }

                // Finish current list
                if !currentListItems.isEmpty {
                    blocks.append(.list(currentListItems, ordered: currentListOrdered))
                    currentListItems = []
                }

                if inCodeBlock {
                    // End code block
                    blocks.append(.codeBlock(
                        language: currentCodeLanguage,
                        code: currentCodeBlock.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    currentCodeBlock = ""
                    currentCodeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                    let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCodeLanguage = language.isEmpty ? nil : language
                }
                continue
            }

            if inCodeBlock {
                currentCodeBlock += line + "\n"
                continue
            }

            // Heading handling
            if line.hasPrefix("#") {
                // Finish current paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }

                // Finish current list
                if !currentListItems.isEmpty {
                    blocks.append(.list(currentListItems, ordered: currentListOrdered))
                    currentListItems = []
                }

                // Parse heading
                let level = line.prefix(while: { $0 == "#" }).count
                let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 6), text: text))
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }),
               line.trimmingCharacters(in: .whitespaces).count >= 3 {
                // Finish current paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }

                // Finish current list
                if !currentListItems.isEmpty {
                    blocks.append(.list(currentListItems, ordered: currentListOrdered))
                    currentListItems = []
                }

                blocks.append(.separator)
                continue
            }

            // List handling
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                // Finish current paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }

                // Start or continue unordered list
                let item = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentListItems.append(item)
                currentListOrdered = false
                continue
            }

            // Ordered list (e.g., "1. Item")
            if let match = trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                // Finish current paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }

                // Start or continue ordered list
                let item = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentListItems.append(item)
                currentListOrdered = true
                continue
            }

            // Empty line - finish current list
            if trimmedLine.isEmpty {
                if !currentListItems.isEmpty {
                    blocks.append(.list(currentListItems, ordered: currentListOrdered))
                    currentListItems = []
                }

                // Don't add empty paragraphs
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                continue
            }

            // Regular paragraph
            if !currentParagraph.isEmpty {
                currentParagraph += " "
            }
            currentParagraph += trimmedLine
        }

        // Finish any remaining blocks
        if !currentListItems.isEmpty {
            blocks.append(.list(currentListItems, ordered: currentListOrdered))
        }

        if inCodeBlock {
            blocks.append(.codeBlock(
                language: currentCodeLanguage,
                code: currentCodeBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
        }

        return blocks
    }

    /// Parses inline markdown (bold, italic, code, links)
    /// - Parameter text: Text to parse
    /// - Returns: AttributedString with formatting
    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // Bold (**text** or __text__)
        attributedString = applyInlineStyle(to: attributedString, pattern: #"\*\*(.+?)\*\*"#) { attr, range in
            var modified = attr
            modified[range].font = .system(size: fontSize, weight: .bold)
            return modified
        }

        attributedString = applyInlineStyle(to: attributedString, pattern: #"__(.+?)__"#) { attr, range in
            var modified = attr
            modified[range].font = .system(size: fontSize, weight: .bold)
            return modified
        }

        // Italic (*text* or _text_)
        attributedString = applyInlineStyle(to: attributedString, pattern: #"\*([^*]+?)\*"#) { attr, range in
            var modified = attr
            modified[range].font = .system(size: fontSize).italic()
            return modified
        }

        attributedString = applyInlineStyle(to: attributedString, pattern: #"_([^_]+?)_"#) { attr, range in
            var modified = attr
            modified[range].font = .system(size: fontSize).italic()
            return modified
        }

        // Inline code (`code`)
        attributedString = applyInlineStyle(to: attributedString, pattern: #"`([^`]+?)`"#) { attr, range in
            var modified = attr
            modified[range].font = .system(size: fontSize, design: .monospaced)
            modified[range].foregroundColor = .secondary
            modified[range].backgroundColor = Color(NSColor.textBackgroundColor)
            return modified
        }

        // Links [text](url)
        attributedString = applyInlineStyle(to: attributedString, pattern: #"\[([^\]]+?)\]\(([^)]+?)\)"#) { attr, range in
            var modified = attr
            modified[range].foregroundColor = .blue
            modified[range].underlineStyle = .single
            return modified
        }

        return attributedString
    }

    /// Applies inline style using regex pattern
    /// - Parameters:
    ///   - attributedString: String to modify
    ///   - pattern: Regex pattern
    ///   - apply: Style to apply (takes AttributedString and range, returns modified AttributedString)
    /// - Returns: Modified attributed string
    private func applyInlineStyle(
        to attributedString: AttributedString,
        pattern: String,
        apply: (AttributedString, Range<AttributedString.Index>) -> AttributedString
    ) -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributedString
        }

        var result = attributedString
        let nsString = attributedString.description as NSString
        let matches = regex.matches(in: attributedString.description, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            if let range = Range(match.range(at: 1), in: result.description),
               let attributedRange = Range<AttributedString.Index>(range, in: result) {
                result = apply(result, attributedRange)
            }
        }

        return result
    }

    /// Highlights code with basic syntax highlighting
    /// - Parameters:
    ///   - code: Code to highlight
    ///   - language: Programming language
    /// - Returns: AttributedString with syntax highlighting
    private func highlightCode(_ code: String, language: String) -> AttributedString {
        var attributedString = AttributedString(code)

        // Define syntax patterns for common languages
        let patterns: [(pattern: String, color: Color)] = {
            switch language.lowercased() {
            case "swift":
                return [
                    (#"\b(func|var|let|class|struct|enum|protocol|extension|if|else|guard|switch|case|return|import|for|while)\b"#, .purple),
                    (#"\b(String|Int|Double|Bool|Array|Dictionary|Set|Optional)\b"#, .green),
                    (#"\"[^\"]*\""#, .red),
                    (#"//.*$"#, .gray),
                    (#"/\*[\s\S]*?\*/"#, .gray),
                ]
            case "python":
                return [
                    (#"\b(def|class|if|elif|else|for|while|return|import|from|as|with|try|except|finally)\b"#, .purple),
                    (#"\b(str|int|float|bool|list|dict|set|tuple)\b"#, .green),
                    (#"\"\"\"[\s\S]*?\"\"\"|\'\'\'[\s\S]*?\'\'\'"#, .red),
                    (#"\"[^\"]*\"|\'[^\']*\'"#, .red),
                    (#"#.*$"#, .gray),
                ]
            case "javascript", "js":
                return [
                    (#"\b(function|var|let|const|class|if|else|switch|case|return|import|export|for|while|async|await)\b"#, .purple),
                    (#"\b(String|Number|Boolean|Array|Object)\b"#, .green),
                    (#"\"[^\"]*\"|\'[^\']*\'|`[^`]*`"#, .red),
                    (#"//.*$"#, .gray),
                    (#"/\*[\s\S]*?\*/"#, .gray),
                ]
            default:
                return []
            }
        }()

        for (pattern, color) in patterns {
            attributedString = applyColorHighlight(to: attributedString, pattern: pattern, color: color)
        }

        return attributedString
    }

    /// Applies color highlighting using regex pattern
    /// - Parameters:
    ///   - attributedString: String to modify
    ///   - pattern: Regex pattern
    ///   - color: Color to apply
    /// - Returns: Modified attributed string
    private func applyColorHighlight(
        to attributedString: AttributedString,
        pattern: String,
        color: Color
    ) -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return attributedString
        }

        var result = attributedString
        let nsString = attributedString.description as NSString
        let matches = regex.matches(in: attributedString.description, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if let range = Range(match.range, in: result.description),
               let attributedRange = Range<AttributedString.Index>(range, in: result) {
                result[attributedRange].foregroundColor = color
            }
        }

        return result
    }

    // MARK: - Helper Methods

    /// Copies text to clipboard
    /// - Parameter text: Text to copy
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Markdown Block Types

/// Represents a block of markdown content
private enum MarkdownBlock: Hashable {
    /// Heading with level (1-6) and text
    case heading(level: Int, text: String)

    /// Code block with optional language and code
    case codeBlock(language: String?, code: String)

    /// List with items and ordered flag
    case list([String], ordered: Bool)

    /// Paragraph with text
    case paragraph(String)

    /// Horizontal separator
    case separator
}

// MARK: - Preview

struct MarkdownTextView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MarkdownTextView(markdown: """
            # Heading 1
            This is a paragraph with **bold** and *italic* text, plus `inline code`.

            ## Heading 2
            Here's a [link](https://example.com) and more text.

            ### Code Example
            ```swift
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
            ```

            ### Lists
            - Unordered item 1
            - Unordered item 2
            - Unordered item 3

            1. Ordered item 1
            2. Ordered item 2
            3. Ordered item 3

            ---

            That's all!
            """)
            .padding()
        }
        .frame(width: 600, height: 800)
    }
}
