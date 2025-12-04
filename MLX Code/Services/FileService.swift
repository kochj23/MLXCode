//
//  FileService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for file operations (Read, Write, Edit, Glob, Grep)
/// Implements secure file handling with validation and sanitization
actor FileService {
    /// Shared singleton instance
    static let shared = FileService()

    private init() {}

    // MARK: - Read Operations

    /// Reads the contents of a file
    /// - Parameters:
    ///   - path: Path to the file
    ///   - encoding: String encoding (default: UTF-8)
    /// - Returns: File contents as string
    /// - Throws: FileServiceError if reading fails
    func read(path: String, encoding: String.Encoding = .utf8) async throws -> String {
        // Validate path
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        // Check if file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FileServiceError.fileNotFound(expandedPath)
        }

        // Check if it's a directory
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        guard !isDirectory.boolValue else {
            throw FileServiceError.isDirectory(expandedPath)
        }

        await SecureLogger.shared.info("Reading file: \(path)", category: "FileService")

        do {
            let contents = try String(contentsOfFile: expandedPath, encoding: encoding)
            return contents
        } catch {
            await SecureLogger.shared.error("Failed to read file: \(error.localizedDescription)", category: "FileService")
            throw FileServiceError.readFailed(error)
        }
    }

    /// Reads file as Data
    /// - Parameter path: Path to the file
    /// - Returns: File contents as Data
    /// - Throws: FileServiceError if reading fails
    func readData(path: String) async throws -> Data {
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FileServiceError.fileNotFound(expandedPath)
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            return data
        } catch {
            throw FileServiceError.readFailed(error)
        }
    }

    // MARK: - Write Operations

    /// Writes contents to a file
    /// - Parameters:
    ///   - content: Content to write
    ///   - path: Destination file path
    ///   - encoding: String encoding (default: UTF-8)
    ///   - createDirectories: Whether to create parent directories if needed
    /// - Throws: FileServiceError if writing fails
    func write(
        content: String,
        to path: String,
        encoding: String.Encoding = .utf8,
        createDirectories: Bool = true
    ) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Create parent directories if needed
        if createDirectories {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        await SecureLogger.shared.info("Writing file: \(path)", category: "FileService")

        do {
            try content.write(to: url, atomically: true, encoding: encoding)
        } catch {
            await SecureLogger.shared.error("Failed to write file: \(error.localizedDescription)", category: "FileService")
            throw FileServiceError.writeFailed(error)
        }
    }

    /// Writes Data to a file
    /// - Parameters:
    ///   - data: Data to write
    ///   - path: Destination file path
    ///   - createDirectories: Whether to create parent directories if needed
    /// - Throws: FileServiceError if writing fails
    func writeData(
        _ data: Data,
        to path: String,
        createDirectories: Bool = true
    ) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        if createDirectories {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        do {
            try data.write(to: url)
        } catch {
            throw FileServiceError.writeFailed(error)
        }
    }

    // MARK: - Edit Operations

    /// Replaces text in a file
    /// - Parameters:
    ///   - path: Path to the file
    ///   - oldString: String to find
    ///   - newString: Replacement string
    ///   - replaceAll: Whether to replace all occurrences (default: false)
    /// - Throws: FileServiceError if editing fails
    func edit(
        path: String,
        oldString: String,
        newString: String,
        replaceAll: Bool = false
    ) async throws {
        // Read file
        let content = try await read(path: path)

        // Perform replacement
        let newContent: String
        if replaceAll {
            newContent = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            // Replace only first occurrence
            if let range = content.range(of: oldString) {
                newContent = content.replacingCharacters(in: range, with: newString)
            } else {
                throw FileServiceError.stringNotFound(oldString)
            }
        }

        // Write back
        try await write(content: newContent, to: path)

        await SecureLogger.shared.info("File edited: \(path)", category: "FileService")
    }

    // MARK: - Glob Operations

    /// Finds files matching a glob pattern
    /// - Parameters:
    ///   - pattern: Glob pattern (e.g., "**/*.swift")
    ///   - directory: Base directory to search (default: current directory)
    /// - Returns: Array of matching file paths
    /// - Throws: FileServiceError if search fails
    func glob(pattern: String, in directory: String = ".") async throws -> [String] {
        let expandedDir = (directory as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedDir) else {
            throw FileServiceError.directoryNotFound(expandedDir)
        }

        await SecureLogger.shared.info("Globbing pattern: \(pattern) in \(directory)", category: "FileService")

        // Convert glob pattern to regex
        let regexPattern = try convertGlobToRegex(pattern)
        let regex = try NSRegularExpression(pattern: regexPattern)

        var matches: [String] = []

        // Recursively search directory
        let enumerator = FileManager.default.enumerator(atPath: expandedDir)
        while let file = enumerator?.nextObject() as? String {
            let fullPath = (expandedDir as NSString).appendingPathComponent(file)
            let range = NSRange(file.startIndex..., in: file)

            if regex.firstMatch(in: file, range: range) != nil {
                matches.append(fullPath)
            }
        }

        await SecureLogger.shared.info("Found \(matches.count) matches", category: "FileService")

        return matches.sorted()
    }

    // MARK: - Grep Operations

    /// Searches for a pattern in files
    /// - Parameters:
    ///   - pattern: Regular expression pattern
    ///   - paths: Array of file paths to search
    ///   - caseSensitive: Whether search is case-sensitive (default: true)
    ///   - contextLines: Number of context lines to include (default: 0)
    /// - Returns: Array of search results
    /// - Throws: FileServiceError if search fails
    func grep(
        pattern: String,
        in paths: [String],
        caseSensitive: Bool = true,
        contextLines: Int = 0
    ) async throws -> [GrepResult] {
        var results: [GrepResult] = []

        let regexOptions: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)

        await SecureLogger.shared.info("Grepping pattern: \(pattern) in \(paths.count) files", category: "FileService")

        for path in paths {
            do {
                let content = try await read(path: path)
                let lines = content.components(separatedBy: .newlines)

                for (lineNumber, line) in lines.enumerated() {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        results.append(GrepResult(
                            path: path,
                            lineNumber: lineNumber + 1,
                            line: line,
                            contextBefore: contextLines > 0 ? Array(lines[max(0, lineNumber - contextLines)..<lineNumber]) : [],
                            contextAfter: contextLines > 0 ? Array(lines[(lineNumber + 1)..<min(lines.count, lineNumber + 1 + contextLines)]) : []
                        ))
                    }
                }
            } catch {
                await SecureLogger.shared.warning("Failed to grep file \(path): \(error.localizedDescription)", category: "FileService")
            }
        }

        await SecureLogger.shared.info("Found \(results.count) matches", category: "FileService")

        return results
    }

    // MARK: - File System Operations

    /// Creates a directory
    /// - Parameters:
    ///   - path: Directory path to create
    ///   - createIntermediates: Whether to create intermediate directories
    /// - Throws: FileServiceError if creation fails
    func createDirectory(at path: String, createIntermediates: Bool = true) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        do {
            try FileManager.default.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: createIntermediates,
                attributes: nil
            )
            await SecureLogger.shared.info("Created directory: \(path)", category: "FileService")
        } catch {
            throw FileServiceError.createDirectoryFailed(error)
        }
    }

    /// Deletes a file or directory
    /// - Parameter path: Path to delete
    /// - Throws: FileServiceError if deletion fails
    func delete(at path: String) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw FileServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FileServiceError.fileNotFound(expandedPath)
        }

        do {
            try FileManager.default.removeItem(atPath: expandedPath)
            await SecureLogger.shared.info("Deleted: \(path)", category: "FileService")
        } catch {
            throw FileServiceError.deleteFailed(error)
        }
    }

    /// Checks if a file or directory exists
    /// - Parameter path: Path to check
    /// - Returns: True if the path exists
    func exists(at path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    // MARK: - Private Helpers

    /// Converts a glob pattern to a regular expression
    /// - Parameter glob: Glob pattern
    /// - Returns: Regular expression pattern
    private func convertGlobToRegex(_ glob: String) throws -> String {
        var regex = "^"

        var i = glob.startIndex
        while i < glob.endIndex {
            let char = glob[i]

            switch char {
            case "*":
                if i < glob.index(before: glob.endIndex) && glob[glob.index(after: i)] == "*" {
                    // ** matches any number of directories
                    regex += ".*"
                    i = glob.index(after: i)
                } else {
                    // * matches anything except /
                    regex += "[^/]*"
                }
            case "?":
                regex += "[^/]"
            case ".":
                regex += "\\."
            case "[", "]", "(", ")", "{", "}", "+", "^", "$", "|", "\\":
                regex += "\\\(char)"
            default:
                regex.append(char)
            }

            i = glob.index(after: i)
        }

        regex += "$"
        return regex
    }
}

// MARK: - Supporting Types

/// Result from a grep search
struct GrepResult {
    let path: String
    let lineNumber: Int
    let line: String
    let contextBefore: [String]
    let contextAfter: [String]
}

/// Errors that can occur during file service operations
enum FileServiceError: LocalizedError {
    case invalidPath(String)
    case fileNotFound(String)
    case directoryNotFound(String)
    case isDirectory(String)
    case readFailed(Error)
    case writeFailed(Error)
    case createDirectoryFailed(Error)
    case deleteFailed(Error)
    case stringNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .isDirectory(let path):
            return "Path is a directory: \(path)"
        case .readFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .createDirectoryFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .stringNotFound(let string):
            return "String not found in file: \(string)"
        }
    }
}
