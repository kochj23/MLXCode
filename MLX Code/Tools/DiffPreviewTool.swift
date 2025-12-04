//
//  DiffPreviewTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for generating and managing file diffs with preview and selective application
class DiffPreviewTool: BaseTool {
    private var pendingDiffs: [String: DiffSet] = [:]

    init() {
        super.init(
            name: "diff_preview",
            description: """
            Generate, preview, and selectively apply file changes.
            Create diffs, review changes, accept/reject modifications.
            """,
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Diff operation",
                        enum: ["create_diff", "preview_diff", "apply_diff", "reject_diff", "list_pending", "create_batch"]
                    ),
                    "diff_id": ParameterProperty(
                        type: "string",
                        description: "Diff identifier"
                    ),
                    "file_path": ParameterProperty(
                        type: "string",
                        description: "File to diff"
                    ),
                    "original_content": ParameterProperty(
                        type: "string",
                        description: "Original file content"
                    ),
                    "new_content": ParameterProperty(
                        type: "string",
                        description: "New file content"
                    ),
                    "files": ParameterProperty(
                        type: "array",
                        description: "Array of file changes for batch operations"
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        switch operation {
        case "create_diff":
            return try await createDiff(parameters: parameters, context: context)
        case "preview_diff":
            return try await previewDiff(parameters: parameters)
        case "apply_diff":
            return try await applyDiff(parameters: parameters, context: context)
        case "reject_diff":
            return try await rejectDiff(parameters: parameters)
        case "list_pending":
            return try await listPending()
        case "create_batch":
            return try await createBatch(parameters: parameters, context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func createDiff(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] as? String else {
            throw ToolError.missingParameter("file_path")
        }

        let fullPath = resolveFilePath(filePath, workingDirectory: context.workingDirectory)

        // Read original content
        let originalContent: String
        if FileManager.default.fileExists(atPath: fullPath) {
            originalContent = try await FileService.shared.read(path: fullPath)
        } else {
            originalContent = ""
        }

        // Get new content
        guard let newContent = parameters["new_content"] as? String else {
            throw ToolError.missingParameter("new_content")
        }

        // Generate diff
        let diff = generateUnifiedDiff(original: originalContent, new: newContent, filePath: filePath)

        // Create diff set
        let diffId = UUID().uuidString
        let diffSet = DiffSet(
            id: diffId,
            changes: [
                FileChange(
                    filePath: filePath,
                    originalContent: originalContent,
                    newContent: newContent,
                    diff: diff
                )
            ]
        )

        pendingDiffs[diffId] = diffSet

        var result = "# Diff Created\n\n"
        result += "**Diff ID**: `\(diffId)`\n"
        result += "**File**: \(filePath)\n\n"
        result += "## Preview\n"
        result += "```diff\n\(diff.prefix(1000))\n```\n"

        if diff.count > 1000 {
            result += "\n*... diff truncated (showing first 1000 chars)*\n"
        }

        result += "\n**Actions:**\n"
        result += "- Use `preview_diff` with `diff_id: \"\(diffId)\"` to see full diff\n"
        result += "- Use `apply_diff` with `diff_id: \"\(diffId)\"` to apply changes\n"
        result += "- Use `reject_diff` with `diff_id: \"\(diffId)\"` to discard\n"

        return .success(result, metadata: ["diff_id": diffId])
    }

    private func previewDiff(parameters: [String: Any]) async throws -> ToolResult {
        guard let diffId = parameters["diff_id"] as? String else {
            throw ToolError.missingParameter("diff_id")
        }

        guard let diffSet = pendingDiffs[diffId] else {
            return .failure("Diff ID '\(diffId)' not found")
        }

        var result = "# Diff Preview\n\n"
        result += "**Diff ID**: `\(diffId)`\n"
        result += "**Files**: \(diffSet.changes.count)\n\n"

        for (index, change) in diffSet.changes.enumerated() {
            result += "## File \(index + 1): \(change.filePath)\n\n"
            result += "### Changes\n"
            result += "```diff\n\(change.diff)\n```\n\n"

            // Statistics
            let stats = calculateDiffStats(diff: change.diff)
            result += "**Stats**: +\(stats.additions) -\(stats.deletions)\n\n"
        }

        return .success(result)
    }

    private func applyDiff(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let diffId = parameters["diff_id"] as? String else {
            throw ToolError.missingParameter("diff_id")
        }

        guard let diffSet = pendingDiffs[diffId] else {
            return .failure("Diff ID '\(diffId)' not found")
        }

        var appliedFiles: [String] = []

        for change in diffSet.changes {
            let fullPath = resolveFilePath(change.filePath, workingDirectory: context.workingDirectory)

            do {
                try await FileService.shared.write(content: change.newContent, to: fullPath)
                appliedFiles.append(change.filePath)
            } catch {
                return .failure("Failed to apply changes to \(change.filePath): \(error.localizedDescription)")
            }
        }

        // Remove from pending
        pendingDiffs.removeValue(forKey: diffId)

        var result = "# Changes Applied\n\n"
        result += "**Diff ID**: `\(diffId)`\n"
        result += "**Files Modified**: \(appliedFiles.count)\n\n"

        for file in appliedFiles {
            result += "- ✅ \(file)\n"
        }

        return .success(result)
    }

    private func rejectDiff(parameters: [String: Any]) async throws -> ToolResult {
        guard let diffId = parameters["diff_id"] as? String else {
            throw ToolError.missingParameter("diff_id")
        }

        guard let diffSet = pendingDiffs[diffId] else {
            return .failure("Diff ID '\(diffId)' not found")
        }

        pendingDiffs.removeValue(forKey: diffId)

        var result = "# Diff Rejected\n\n"
        result += "**Diff ID**: `\(diffId)`\n"
        result += "**Files Discarded**: \(diffSet.changes.count)\n\n"

        for change in diffSet.changes {
            result += "- ❌ \(change.filePath)\n"
        }

        return .success(result)
    }

    private func listPending() async throws -> ToolResult {
        var result = "# Pending Diffs\n\n"

        if pendingDiffs.isEmpty {
            result += "*No pending diffs*\n"
        } else {
            result += "**Total**: \(pendingDiffs.count)\n\n"

            for (diffId, diffSet) in pendingDiffs {
                result += "## `\(diffId)`\n"
                result += "- Files: \(diffSet.changes.count)\n"
                result += "- Created: \(diffSet.createdAt.formatted())\n"

                for change in diffSet.changes {
                    let stats = calculateDiffStats(diff: change.diff)
                    result += "  - \(change.filePath) (+\(stats.additions) -\(stats.deletions))\n"
                }
                result += "\n"
            }
        }

        return .success(result, metadata: ["pending_count": pendingDiffs.count])
    }

    private func createBatch(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filesArray = parameters["files"] as? [[String: Any]] else {
            throw ToolError.missingParameter("files array")
        }

        var changes: [FileChange] = []

        for fileInfo in filesArray {
            guard let filePath = fileInfo["path"] as? String,
                  let newContent = fileInfo["content"] as? String else {
                continue
            }

            let fullPath = resolveFilePath(filePath, workingDirectory: context.workingDirectory)

            // Read original
            let originalContent: String
            if FileManager.default.fileExists(atPath: fullPath) {
                originalContent = try await FileService.shared.read(path: fullPath)
            } else {
                originalContent = ""
            }

            // Generate diff
            let diff = generateUnifiedDiff(original: originalContent, new: newContent, filePath: filePath)

            changes.append(FileChange(
                filePath: filePath,
                originalContent: originalContent,
                newContent: newContent,
                diff: diff
            ))
        }

        // Create batch diff set
        let diffId = UUID().uuidString
        let diffSet = DiffSet(id: diffId, changes: changes)
        pendingDiffs[diffId] = diffSet

        var result = "# Batch Diff Created\n\n"
        result += "**Diff ID**: `\(diffId)`\n"
        result += "**Files**: \(changes.count)\n\n"

        for change in changes {
            let stats = calculateDiffStats(diff: change.diff)
            result += "- \(change.filePath) (+\(stats.additions) -\(stats.deletions))\n"
        }

        result += "\n**Actions:**\n"
        result += "- Use `preview_diff` to see full changes\n"
        result += "- Use `apply_diff` to apply all changes\n"
        result += "- Use `reject_diff` to discard\n"

        return .success(result, metadata: ["diff_id": diffId, "file_count": changes.count])
    }

    // MARK: - Helper Methods

    private func generateUnifiedDiff(original: String, new: String, filePath: String) -> String {
        let originalLines = original.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)

        var diff = "--- \(filePath)\n"
        diff += "+++ \(filePath)\n"

        // Simple line-by-line diff
        let maxLines = max(originalLines.count, newLines.count)

        for i in 0..<maxLines {
            let originalLine = i < originalLines.count ? originalLines[i] : nil
            let newLine = i < newLines.count ? newLines[i] : nil

            if originalLine == newLine {
                if let line = originalLine {
                    diff += " \(line)\n"
                }
            } else {
                if let original = originalLine {
                    diff += "-\(original)\n"
                }
                if let new = newLine {
                    diff += "+\(new)\n"
                }
            }
        }

        return diff
    }

    private func calculateDiffStats(diff: String) -> (additions: Int, deletions: Int) {
        let lines = diff.components(separatedBy: .newlines)
        var additions = 0
        var deletions = 0

        for line in lines {
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletions += 1
            }
        }

        return (additions, deletions)
    }

    private func resolveFilePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return (workingDirectory as NSString).appendingPathComponent(path)
    }
}

// MARK: - Supporting Types

struct DiffSet {
    let id: String
    let changes: [FileChange]
    let createdAt: Date

    init(id: String, changes: [FileChange]) {
        self.id = id
        self.changes = changes
        self.createdAt = Date()
    }
}

struct FileChange {
    let filePath: String
    let originalContent: String
    let newContent: String
    let diff: String
}
