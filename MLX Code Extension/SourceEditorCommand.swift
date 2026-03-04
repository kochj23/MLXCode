//
//  SourceEditorCommand.swift
//  MLX Code Extension
//
//  Handles all five Editor > MLX Code commands inside Xcode.
//  Captures selected text + full source, writes to the shared App Group
//  container, then opens the main MLX Code app via URL scheme.
//
//  Created by Jordan Koch on 2026-03-04.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    // MARK: - Command IDs (must match Info.plist)

    enum CommandID: String {
        case explain   = "com.local.mlxcode.xcodeeditor.explain"
        case refactor  = "com.local.mlxcode.xcodeeditor.refactor"
        case tests     = "com.local.mlxcode.xcodeeditor.tests"
        case fix       = "com.local.mlxcode.xcodeeditor.fix"
        case ask       = "com.local.mlxcode.xcodeeditor.ask"
    }

    // MARK: - XCSourceEditorCommand

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let buffer = invocation.buffer

        // Collect selected lines (fall back to full file if nothing selected)
        let selectedText = extractSelectedText(from: buffer)
        let fullSource = buffer.completeBuffer

        // Build the request payload
        let request = XcodeRequest(
            commandIdentifier: invocation.commandIdentifier,
            selectedText: selectedText,
            fullSource: fullSource,
            contentUTI: buffer.contentUTI
        )

        // Write to shared App Group container
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.jkoch.mlxcode"
        ) else {
            completionHandler(ExtensionError.noAppGroup)
            return
        }

        let requestURL = groupURL.appendingPathComponent("mlxcode-xcode-request.json")
        do {
            let data = try JSONEncoder().encode(request)
            try data.write(to: requestURL, options: .atomic)
        } catch {
            completionHandler(error)
            return
        }

        // Open the main app
        guard let appURL = URL(string: "mlxcode://xcode-action") else {
            completionHandler(ExtensionError.invalidURL)
            return
        }
        NSWorkspace.shared.open(appURL)

        completionHandler(nil)
    }

    // MARK: - Private

    private func extractSelectedText(from buffer: XCSourceTextBuffer) -> String {
        let lines = buffer.lines as? [String] ?? []
        guard !buffer.selections.isEmpty else {
            return buffer.completeBuffer
        }

        var selected: [String] = []
        for selection in buffer.selections {
            guard let range = selection as? XCSourceTextRange else { continue }
            let start = range.start.line
            let end   = min(range.end.line, lines.count - 1)
            guard start <= end else { continue }

            if start == end {
                // Single-line selection — extract the column range
                let line = lines[start]
                let startCol = min(range.start.column, line.count)
                let endCol   = min(range.end.column, line.count)
                if startCol < endCol {
                    let s = line.index(line.startIndex, offsetBy: startCol)
                    let e = line.index(line.startIndex, offsetBy: endCol)
                    selected.append(String(line[s..<e]))
                } else {
                    selected.append(line)
                }
            } else {
                selected.append(contentsOf: lines[start...end])
            }
        }

        return selected.joined()
    }
}

// MARK: - XcodeRequest

/// Payload written to the App Group container and read by the main app.
struct XcodeRequest: Codable {
    let commandIdentifier: String
    let selectedText: String
    let fullSource: String
    let contentUTI: String
}

// MARK: - Errors

enum ExtensionError: LocalizedError {
    case noAppGroup
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noAppGroup:
            return "Could not access shared App Group container. Ensure MLX Code is installed."
        case .invalidURL:
            return "Invalid URL scheme for MLX Code."
        }
    }
}
