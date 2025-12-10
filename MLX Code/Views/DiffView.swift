//
//  DiffView.swift
//  MLX Code
//
//  Side-by-side diff viewer with approve/reject
//  Created on 2025-12-09
//

import SwiftUI

/// Diff viewer for code changes
struct DiffView: View {
    let filePath: String
    let originalContent: String
    let modifiedContent: String
    let onApprove: () -> Void
    let onReject: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedView: DiffViewType = .sideBySide

    enum DiffViewType: String, CaseIterable {
        case sideBySide = "Side by Side"
        case unified = "Unified"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Diff view
            if selectedView == .sideBySide {
                sideBySideDiff
            } else {
                unifiedDiff
            }

            Divider()

            // Actions
            actions
        }
        .frame(width: 1000, height: 700)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("File Changes")
                    .font(.headline)

                Text(filePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // View type picker
            Picker("View", selection: $selectedView) {
                ForEach(DiffViewType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Stats
            diffStats
        }
        .padding()
    }

    private var diffStats: some View {
        HStack(spacing: 12) {
            Label("\(additions)", systemImage: "plus")
                .foregroundColor(.green)
            Label("\(deletions)", systemImage: "minus")
                .foregroundColor(.red)
        }
        .font(.caption)
    }

    // MARK: - Side by Side View

    private var sideBySideDiff: some View {
        HStack(spacing: 0) {
            // Original
            VStack(alignment: .leading, spacing: 0) {
                Text("Original")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))

                ScrollView {
                    Text(originalContent)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            // Modified
            VStack(alignment: .leading, spacing: 0) {
                Text("Modified")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))

                ScrollView {
                    Text(modifiedContent)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Unified View

    private var unifiedDiff: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                    diffLineView(line)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(line.lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 8)

            // Change indicator
            Text(line.prefix)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(line.type == .addition ? .green : line.type == .deletion ? .red : .secondary)
                .frame(width: 20)

            // Content
            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(line.type == .addition ? Color.green.opacity(0.1) : line.type == .deletion ? Color.red.opacity(0.1) : Color.clear)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(action: {
                onReject()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Reject Changes")
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button(action: {
                onApprove()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Apply Changes")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var diffLines: [DiffLine] {
        let originalLines = originalContent.components(separatedBy: "\n")
        let modifiedLines = modifiedContent.components(separatedBy: "\n")

        var lines: [DiffLine] = []
        var lineNum = 1

        // Simple line-by-line diff (can be enhanced with proper diff algorithm)
        let maxLines = max(originalLines.count, modifiedLines.count)

        for i in 0..<maxLines {
            if i < originalLines.count && i < modifiedLines.count {
                if originalLines[i] == modifiedLines[i] {
                    // Unchanged
                    lines.append(DiffLine(
                        lineNumber: lineNum,
                        type: .unchanged,
                        prefix: " ",
                        content: originalLines[i]
                    ))
                    lineNum += 1
                } else {
                    // Changed
                    lines.append(DiffLine(
                        lineNumber: lineNum,
                        type: .deletion,
                        prefix: "-",
                        content: originalLines[i]
                    ))
                    lines.append(DiffLine(
                        lineNumber: lineNum,
                        type: .addition,
                        prefix: "+",
                        content: modifiedLines[i]
                    ))
                    lineNum += 1
                }
            } else if i < originalLines.count {
                // Deletion
                lines.append(DiffLine(
                    lineNumber: lineNum,
                    type: .deletion,
                    prefix: "-",
                    content: originalLines[i]
                ))
                lineNum += 1
            } else if i < modifiedLines.count {
                // Addition
                lines.append(DiffLine(
                    lineNumber: lineNum,
                    type: .addition,
                    prefix: "+",
                    content: modifiedLines[i]
                ))
                lineNum += 1
            }
        }

        return lines
    }

    private var additions: Int {
        diffLines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        diffLines.filter { $0.type == .deletion }.count
    }
}

// MARK: - Supporting Types

struct DiffLine {
    let lineNumber: Int
    let type: DiffLineType
    let prefix: String
    let content: String
}

enum DiffLineType {
    case unchanged
    case addition
    case deletion
}

// MARK: - Preview

struct DiffView_Previews: PreviewProvider {
    static var previews: some View {
        DiffView(
            filePath: "/path/to/file.swift",
            originalContent: """
            func oldFunction() {
                print("old")
            }
            """,
            modifiedContent: """
            func newFunction() {
                print("new and improved")
            }
            """,
            onApprove: { print("Approved") },
            onReject: { print("Rejected") }
        )
    }
}
