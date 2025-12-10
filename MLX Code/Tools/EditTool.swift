//
//  EditTool.swift
//  MLX Code
//
//  Structured file editing with exact string matching
//  Created on 2025-12-09
//

import Foundation

/// Precise file editing tool (like Claude Code's Edit)
actor EditTool {
    static let shared = EditTool()

    private init() {}

    // MARK: - Edit Operations

    /// Performs a structured edit on a file
    /// - Parameters:
    ///   - filePath: Absolute path to file
    ///   - oldString: Exact string to find (must be unique)
    ///   - newString: Replacement string
    ///   - replaceAll: If true, replaces all occurrences
    /// - Returns: Edit result with success status
    func edit(
        filePath: String,
        oldString: String,
        newString: String,
        replaceAll: Bool = false
    ) async throws -> EditResult {
        let fileManager = FileManager.default

        // Read file
        guard fileManager.fileExists(atPath: filePath) else {
            throw EditError.fileNotFound(filePath)
        }

        let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)

        // Validate old string exists
        guard originalContent.contains(oldString) else {
            throw EditError.stringNotFound(oldString)
        }

        // Check uniqueness if not replacing all
        if !replaceAll {
            let occurrences = originalContent.components(separatedBy: oldString).count - 1
            if occurrences > 1 {
                throw EditError.notUnique(oldString, occurrences)
            }
        }

        // Perform replacement
        let newContent = replaceAll
            ? originalContent.replacingOccurrences(of: oldString, with: newString)
            : originalContent.replacingOccurrences(of: oldString, with: newString, options: [], range: originalContent.range(of: oldString))

        // Backup original
        let backupPath = filePath + ".backup-\(Date().timeIntervalSince1970)"
        try originalContent.write(toFile: backupPath, atomically: true, encoding: .utf8)

        // Write new content
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)

        // TODO: Record for undo (temporarily disabled due to build issues)
        // let operation = FileOperation.edit(
        //     path: filePath,
        //     beforeContent: originalContent,
        //     afterContent: newContent
        // )
        //
        // await MainActor.run {
        //     FileUndoManager.shared.recordOperation(operation)
        // }

        return EditResult(
            success: true,
            filePath: filePath,
            linesChanged: countChangedLines(old: originalContent, new: newContent),
            backupPath: backupPath
        )
    }

    /// Edits multiple strings in one file atomically
    /// - Parameters:
    ///   - filePath: File to edit
    ///   - edits: Array of (oldString, newString) pairs
    /// - Returns: Edit result
    func multiEdit(
        filePath: String,
        edits: [(old: String, new: String)]
    ) async throws -> EditResult {
        let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
        var currentContent = originalContent

        // Validate all strings exist
        for (oldString, _) in edits {
            guard currentContent.contains(oldString) else {
                throw EditError.stringNotFound(oldString)
            }
        }

        // Apply all edits
        for (oldString, newString) in edits {
            currentContent = currentContent.replacingOccurrences(of: oldString, with: newString)
        }

        // Backup
        let backupPath = filePath + ".backup-\(Date().timeIntervalSince1970)"
        try originalContent.write(toFile: backupPath, atomically: true, encoding: .utf8)

        // Write
        try currentContent.write(toFile: filePath, atomically: true, encoding: .utf8)

        // TODO: Record undo (temporarily disabled due to build issues)
        // let operation = FileOperation.edit(
        //     path: filePath,
        //     beforeContent: originalContent,
        //     afterContent: currentContent
        // )
        //
        // await MainActor.run {
        //     FileUndoManager.shared.recordOperation(operation)
        // }

        return EditResult(
            success: true,
            filePath: filePath,
            linesChanged: countChangedLines(old: originalContent, new: currentContent),
            backupPath: backupPath
        )
    }

    // MARK: - Helper Methods

    private func countChangedLines(old: String, new: String) -> Int {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        var changes = 0
        let maxLines = max(oldLines.count, newLines.count)

        for i in 0..<maxLines {
            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""

            if oldLine != newLine {
                changes += 1
            }
        }

        return changes
    }
}

// MARK: - Supporting Types

/// Result of an edit operation
struct EditResult {
    let success: Bool
    let filePath: String
    let linesChanged: Int
    let backupPath: String
    let error: String?

    init(success: Bool, filePath: String, linesChanged: Int, backupPath: String, error: String? = nil) {
        self.success = success
        self.filePath = filePath
        self.linesChanged = linesChanged
        self.backupPath = backupPath
        self.error = error
    }
}

/// Edit operation errors
enum EditError: LocalizedError {
    case fileNotFound(String)
    case stringNotFound(String)
    case notUnique(String, Int)
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .stringNotFound(let string):
            return "String not found in file: \(string.prefix(50))..."
        case .notUnique(let string, let count):
            return "String appears \(count) times (must be unique). Use replaceAll=true or provide more context."
        case .writeError(let details):
            return "Failed to write file: \(details)"
        }
    }
}
