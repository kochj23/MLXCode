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
        let ns = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
        applyHighlighting(to: ns)
        return (try? AttributedString(ns, including: \.appKit)) ?? AttributedString(code)
    }

    private func applyHighlighting(to ns: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: ns.length)
        for (pattern, color) in syntaxPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            regex.enumerateMatches(in: ns.string, range: full) { match, _, _ in
                guard let range = match?.range, range.length > 0 else { return }
                ns.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }

    private var syntaxPatterns: [(String, NSColor)] {
        switch language.lowercased() {
        case "swift":
            return [
                (#"//.*"#, NSColor.systemGray),
                (#"/\*[\s\S]*?\*/"#, NSColor.systemGray),
                (#"\"(?:[^\"\\]|\\.)*\""#, NSColor.systemRed),
                (#"\b(String|Int|Int64|Int32|Double|Float|Bool|Array|Dictionary|Set|Optional|Void|Never|Character|Data|URL|Date|UUID|Any|AnyObject)\b"#, NSColor.systemTeal),
                (#"\b(func|var|let|class|struct|enum|protocol|extension|if|else|guard|switch|case|return|import|for|while|in|do|try|catch|throw|async|await|actor|nonisolated|some|any|where|typealias|init|deinit|self|super|static|final|override|public|private|internal|fileprivate|open|mutating|lazy|weak|unowned|inout|defer|repeat|break|continue|fallthrough|is|as|nil|true|false)\b"#, NSColor.systemPurple),
                (#"\b\d+\.?\d*\b"#, NSColor.systemOrange),
            ]
        case "python":
            return [
                (#"#.*"#, NSColor.systemGray),
                (#"\"\"\"[\s\S]*?\"\"\"|\'\'\'[\s\S]*?\'\'\'"#, NSColor.systemRed),
                (#"\"(?:[^\"\\]|\\.)*\"|\'(?:[^\'\\]|\\.)*\'"#, NSColor.systemRed),
                (#"\b(str|int|float|bool|list|dict|set|tuple|None|True|False|self|cls)\b"#, NSColor.systemTeal),
                (#"\b(def|class|if|elif|else|for|while|return|import|from|as|with|try|except|finally|raise|pass|break|continue|and|or|not|in|is|lambda|yield|async|await|global|nonlocal|del|assert)\b"#, NSColor.systemPurple),
                (#"\b\d+\.?\d*\b"#, NSColor.systemOrange),
            ]
        case "javascript", "js", "typescript", "ts":
            return [
                (#"//.*"#, NSColor.systemGray),
                (#"/\*[\s\S]*?\*/"#, NSColor.systemGray),
                (#"\"(?:[^\"\\]|\\.)*\"|\'(?:[^\'\\]|\\.)*\'|`[^`]*`"#, NSColor.systemRed),
                (#"\b(String|Number|Boolean|Array|Object|Promise|null|undefined|true|false|NaN|Infinity)\b"#, NSColor.systemTeal),
                (#"\b(function|var|let|const|class|if|else|switch|case|return|import|export|from|for|while|async|await|try|catch|finally|throw|new|this|typeof|instanceof|default|break|continue|do|of|in|delete|void|yield)\b"#, NSColor.systemPurple),
                (#"\b\d+\.?\d*\b"#, NSColor.systemOrange),
            ]
        case "bash", "sh", "zsh", "shell":
            return [
                (#"#.*"#, NSColor.systemGray),
                (#"\"(?:[^\"\\]|\\.)*\"|\'[^\']*\'"#, NSColor.systemRed),
                (#"\$\w+|\$\{[^}]*\}"#, NSColor.systemOrange),
                (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|export|local|echo|exit|cd|ls|grep|sed|awk|source|alias|unset|readonly)\b"#, NSColor.systemPurple),
            ]
        case "json":
            return [
                (#"\"(?:[^\"\\]|\\.)*\"\s*:"#, NSColor.systemTeal),
                (#"\"(?:[^\"\\]|\\.)*\""#, NSColor.systemRed),
                (#"\b(true|false|null)\b"#, NSColor.systemPurple),
                (#"\b\d+\.?\d*\b"#, NSColor.systemOrange),
            ]
        case "objc", "objective-c", "m":
            return [
                (#"//.*"#, NSColor.systemGray),
                (#"/\*[\s\S]*?\*/"#, NSColor.systemGray),
                (#"@\"(?:[^\"\\]|\\.)*\"|\"(?:[^\"\\]|\\.)*\""#, NSColor.systemRed),
                (#"\b(NSString|NSArray|NSDictionary|NSInteger|BOOL|CGFloat|NSObject|UIView|void|id)\b"#, NSColor.systemTeal),
                (#"\b(if|else|for|while|return|import|@interface|@implementation|@end|@property|@synthesize|@dynamic|@protocol|@class|@selector|@encode|self|super|YES|NO|nil|NULL)\b"#, NSColor.systemPurple),
            ]
        default:
            return []
        }
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
