//
//  FileOperationsTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for file operations (read, write, edit)
class FileOperationsTool: BaseTool {
    enum Operation: String {
        case read
        case write
        case edit
        case list
        case delete
        case move
        case copy
    }

    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "Operation to perform: read, write, edit, list, delete, move, copy",
                    enum: ["read", "write", "edit", "list", "delete", "move", "copy"]
                ),
                "path": ParameterProperty(
                    type: "string",
                    description: "File or directory path (absolute or relative)"
                ),
                "content": ParameterProperty(
                    type: "string",
                    description: "Content to write (for write/edit operations)"
                ),
                "old_string": ParameterProperty(
                    type: "string",
                    description: "String to replace (for edit operation)"
                ),
                "new_string": ParameterProperty(
                    type: "string",
                    description: "Replacement string (for edit operation)"
                ),
                "destination": ParameterProperty(
                    type: "string",
                    description: "Destination path (for move/copy operations)"
                ),
                "line_start": ParameterProperty(
                    type: "number",
                    description: "Start line number for partial read (1-indexed)"
                ),
                "line_end": ParameterProperty(
                    type: "number",
                    description: "End line number for partial read (1-indexed)"
                )
            ],
            required: ["operation", "path"]
        )

        super.init(
            name: "file_operations",
            description: "Perform file operations: read, write, edit, list, delete, move, copy files",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        do {
            // Validate required parameters
            try validateParameters(parameters, required: ["operation", "path"])

            let operationStr = try stringParameter(parameters, key: "operation")
            guard let operation = Operation(rawValue: operationStr) else {
                throw ToolError.invalidParameterType("operation", expected: "valid operation")
            }

            let path = try stringParameter(parameters, key: "path")
            let fullPath = resolvePath(path, workingDirectory: context.workingDirectory)

            // Execute operation
            let result: ToolResult
            switch operation {
            case .read:
                result = try readFile(path: fullPath, parameters: parameters, context: context)
            case .write:
                result = try writeFile(path: fullPath, parameters: parameters, context: context)
            case .edit:
                result = try editFile(path: fullPath, parameters: parameters, context: context)
            case .list:
                result = try listDirectory(path: fullPath, context: context)
            case .delete:
                result = try deleteFile(path: fullPath, context: context)
            case .move:
                result = try moveFile(path: fullPath, parameters: parameters, context: context)
            case .copy:
                result = try copyFile(path: fullPath, parameters: parameters, context: context)
            }

            // Record telemetry
            let _ = Date().timeIntervalSince(startTime)
            ToolTelemetry(
                toolName: name,
                startTime: startTime,
                endTime: Date(),
                success: result.success,
                error: result.error
            ).log()

            return result

        } catch {
            let _ = Date().timeIntervalSince(startTime)
            ToolTelemetry(
                toolName: name,
                startTime: startTime,
                endTime: Date(),
                success: false,
                error: error.localizedDescription
            ).log()

            throw error
        }
    }

    // MARK: - File Operations

    /// Read file content
    private func readFile(path: String, parameters: [String: Any], context: ToolContext) throws -> ToolResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("File not found: \(path)")
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            return .failure("Permission denied: \(path)")
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Check for partial read
        if let lineStart = parameters["line_start"] as? Int,
           let lineEnd = parameters["line_end"] as? Int {
            let start = max(0, lineStart - 1)  // Convert to 0-indexed
            let end = min(lines.count, lineEnd)

            if start >= lines.count {
                return .failure("Line start \(lineStart) exceeds file length (\(lines.count) lines)")
            }

            let selectedLines = Array(lines[start..<end])
            let numberedLines = selectedLines.enumerated().map { index, line in
                let lineNumber = start + index + 1
                return String(format: "%6d\t%@", lineNumber, line)
            }.joined(separator: "\n")

            // Store in memory
            context.memory?.storeFileContext(path, content: content, lastModified: Date())

            return .success(numberedLines, metadata: [
                "path": path,
                "total_lines": lines.count,
                "lines_read": selectedLines.count,
                "line_range": "\(lineStart)-\(lineEnd)"
            ])
        }

        // Full file read with line numbers
        let numberedLines = lines.enumerated().map { index, line in
            return String(format: "%6d\t%@", index + 1, line)
        }.joined(separator: "\n")

        // Store in memory
        context.memory?.storeFileContext(path, content: content, lastModified: Date())

        return .success(numberedLines, metadata: [
            "path": path,
            "total_lines": lines.count,
            "size_bytes": content.count
        ])
    }

    /// Write file content
    private func writeFile(path: String, parameters: [String: Any], context: ToolContext) throws -> ToolResult {
        guard let content = parameters["content"] as? String else {
            return .failure("Missing 'content' parameter for write operation")
        }

        // Check if file already exists
        let fileExists = FileManager.default.fileExists(atPath: path)

        // Create parent directories if needed
        let parentDir = (path as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parentDir) {
            try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }

        // Write file
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        let action = fileExists ? "Updated" : "Created"
        let lineCount = content.components(separatedBy: .newlines).count

        // Store in memory
        context.memory?.storeFileContext(path, content: content, lastModified: Date())

        return .success("\(action) file: \(path)", metadata: [
            "path": path,
            "action": action.lowercased(),
            "lines": lineCount,
            "size_bytes": content.count
        ])
    }

    /// Edit file content (search and replace)
    private func editFile(path: String, parameters: [String: Any], context: ToolContext) throws -> ToolResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("File not found: \(path)")
        }

        guard let oldString = parameters["old_string"] as? String,
              let newString = parameters["new_string"] as? String else {
            return .failure("Missing 'old_string' or 'new_string' parameter for edit operation")
        }

        // Read current content
        var content = try String(contentsOfFile: path, encoding: .utf8)

        // Count occurrences
        let occurrences = content.components(separatedBy: oldString).count - 1

        if occurrences == 0 {
            return .failure("String not found in file: '\(oldString)'")
        }

        // Perform replacement
        content = content.replacingOccurrences(of: oldString, with: newString)

        // Write back
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        // Store in memory
        context.memory?.storeFileContext(path, content: content, lastModified: Date())

        return .success("Replaced \(occurrences) occurrence(s) in \(path)", metadata: [
            "path": path,
            "occurrences": occurrences,
            "old_string": oldString,
            "new_string": newString
        ])
    }

    /// List directory contents
    private func listDirectory(path: String, context: ToolContext) throws -> ToolResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("Directory not found: \(path)")
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .failure("Path is not a directory: \(path)")
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
        let sortedContents = contents.sorted()

        var output: [String] = []
        for item in sortedContents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)

            let prefix = isDir.boolValue ? "📁" : "📄"
            output.append("\(prefix) \(item)")
        }

        return .success(output.joined(separator: "\n"), metadata: [
            "path": path,
            "count": sortedContents.count
        ])
    }

    /// Delete file or directory
    private func deleteFile(path: String, context: ToolContext) throws -> ToolResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("File not found: \(path)")
        }

        try FileManager.default.removeItem(atPath: path)

        // Remove from memory
        context.memory?.clearFileContext(path)

        return .success("Deleted: \(path)", metadata: [
            "path": path
        ])
    }

    /// Move file
    private func moveFile(path: String, parameters: [String: Any], context: ToolContext) throws -> ToolResult {
        guard let destination = parameters["destination"] as? String else {
            return .failure("Missing 'destination' parameter for move operation")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("Source file not found: \(path)")
        }

        let destPath = resolvePath(destination, workingDirectory: context.workingDirectory)

        try FileManager.default.moveItem(atPath: path, toPath: destPath)

        // Update memory
        context.memory?.clearFileContext(path)

        return .success("Moved: \(path) → \(destPath)", metadata: [
            "source": path,
            "destination": destPath
        ])
    }

    /// Copy file
    private func copyFile(path: String, parameters: [String: Any], context: ToolContext) throws -> ToolResult {
        guard let destination = parameters["destination"] as? String else {
            return .failure("Missing 'destination' parameter for copy operation")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure("Source file not found: \(path)")
        }

        let destPath = resolvePath(destination, workingDirectory: context.workingDirectory)

        try FileManager.default.copyItem(atPath: path, toPath: destPath)

        return .success("Copied: \(path) → \(destPath)", metadata: [
            "source": path,
            "destination": destPath
        ])
    }

    // MARK: - Helpers

    /// Resolve relative path to absolute path
    private func resolvePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }

        if path.hasPrefix("~/") {
            return NSString(string: path).expandingTildeInPath
        }

        return (workingDirectory as NSString).appendingPathComponent(path)
    }
}
