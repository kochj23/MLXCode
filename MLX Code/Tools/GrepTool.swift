//
//  GrepTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for searching code content (like grep/ripgrep)
class GrepTool: BaseTool {
    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "pattern": ParameterProperty(
                    type: "string",
                    description: "Search pattern (regex supported)"
                ),
                "path": ParameterProperty(
                    type: "string",
                    description: "Directory or file to search in (default: current directory)"
                ),
                "file_pattern": ParameterProperty(
                    type: "string",
                    description: "File pattern to match (e.g., '*.swift', '*.m')"
                ),
                "case_sensitive": ParameterProperty(
                    type: "boolean",
                    description: "Case sensitive search (default: false)"
                ),
                "max_results": ParameterProperty(
                    type: "number",
                    description: "Maximum number of results to return (default: 50)"
                ),
                "context_lines": ParameterProperty(
                    type: "number",
                    description: "Number of context lines before/after match (default: 2)"
                )
            ],
            required: ["pattern"]
        )

        super.init(
            name: "grep",
            description: "Search for patterns in code files (grep-like functionality)",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        do {
            // Validate required parameters
            try validateParameters(parameters, required: ["pattern"])

            let pattern = try stringParameter(parameters, key: "pattern")
            let searchPath = try? stringParameter(parameters, key: "path", default: context.workingDirectory)
            let filePattern = try? stringParameter(parameters, key: "file_pattern", default: "*")
            let caseSensitive = try? boolParameter(parameters, key: "case_sensitive", default: false)
            let maxResults = try? intParameter(parameters, key: "max_results", default: 50)
            let contextLines = try? intParameter(parameters, key: "context_lines", default: 2)

            let fullPath = resolvePath(searchPath ?? context.workingDirectory, workingDirectory: context.workingDirectory)

            logInfo("Searching for pattern '\(pattern)' in \(fullPath)", category: "GrepTool")

            // Perform search
            let results = try searchFiles(
                pattern: pattern,
                path: fullPath,
                filePattern: filePattern ?? "*",
                caseSensitive: caseSensitive ?? false,
                maxResults: maxResults ?? 50,
                contextLines: contextLines ?? 2
            )

            let output = formatResults(results)

            // Record telemetry
            let _ = Date().timeIntervalSince(startTime)
            ToolTelemetry(
                toolName: name,
                startTime: startTime,
                endTime: Date(),
                success: true,
                error: nil
            ).log()

            return .success(output, metadata: [
                "pattern": pattern,
                "path": fullPath,
                "matches_found": results.count,
                "files_searched": Set(results.map { $0.file }).count
            ])

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

    // MARK: - Search Implementation

    /// Search result
    struct SearchMatch {
        let file: String
        let lineNumber: Int
        let line: String
        let contextBefore: [String]
        let contextAfter: [String]
    }

    /// Search files for pattern
    private func searchFiles(
        pattern: String,
        path: String,
        filePattern: String,
        caseSensitive: Bool,
        maxResults: Int,
        contextLines: Int
    ) throws -> [SearchMatch] {
        var matches: [SearchMatch] = []

        // Create regex
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        let regex = try NSRegularExpression(pattern: pattern, options: options)

        // Get files to search
        let files = try getFiles(at: path, matching: filePattern)

        fileLoop: for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else {
                continue
            }

            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    // Extract context
                    let beforeStart = max(0, index - contextLines)
                    let afterEnd = min(lines.count, index + contextLines + 1)

                    let contextBefore = Array(lines[beforeStart..<index])
                    let contextAfter = Array(lines[(index + 1)..<afterEnd])

                    matches.append(SearchMatch(
                        file: file,
                        lineNumber: index + 1,
                        line: line,
                        contextBefore: contextBefore,
                        contextAfter: contextAfter
                    ))

                    if matches.count >= maxResults {
                        break fileLoop
                    }
                }
            }
        }

        return matches
    }

    /// Get files matching pattern
    private func getFiles(at path: String, matching pattern: String) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ToolError.notFound(path)
        }

        if !isDirectory.boolValue {
            // Single file
            return [path]
        }

        // Directory - recursively find files
        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(file)

                // Skip hidden files and directories
                if file.hasPrefix(".") {
                    continue
                }

                // Check if matches pattern
                if matchesPattern(file, pattern: pattern) {
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                        files.append(fullPath)
                    }
                }
            }
        }

        return files
    }

    /// Check if filename matches pattern
    private func matchesPattern(_ filename: String, pattern: String) -> Bool {
        if pattern == "*" {
            return true
        }

        // Convert glob pattern to regex
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$") else {
            return false
        }

        let range = NSRange(filename.startIndex..., in: filename)
        return regex.firstMatch(in: filename, range: range) != nil
    }

    /// Format search results
    private func formatResults(_ results: [SearchMatch]) -> String {
        if results.isEmpty {
            return "No matches found."
        }

        var output: [String] = []
        var currentFile = ""

        for result in results {
            // Print file header if changed
            if result.file != currentFile {
                if !currentFile.isEmpty {
                    output.append("")  // Blank line between files
                }
                output.append("📄 \(result.file)")
                output.append(String(repeating: "-", count: 60))
                currentFile = result.file
            }

            // Print context before
            for (offset, line) in result.contextBefore.enumerated() {
                let lineNum = result.lineNumber - result.contextBefore.count + offset
                output.append(String(format: "%6d  %@", lineNum, line))
            }

            // Print matching line (highlighted)
            output.append(String(format: "%6d→ %@", result.lineNumber, result.line))

            // Print context after
            for (offset, line) in result.contextAfter.enumerated() {
                let lineNum = result.lineNumber + offset + 1
                output.append(String(format: "%6d  %@", lineNum, line))
            }

            output.append("")  // Blank line after match
        }

        return output.joined(separator: "\n")
    }

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
