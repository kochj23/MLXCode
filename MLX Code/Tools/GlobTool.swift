//
//  GlobTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for finding files by glob patterns
class GlobTool: BaseTool {
    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "pattern": ParameterProperty(
                    type: "string",
                    description: "Glob pattern (e.g., '**/*.swift', 'src/**/*.m')"
                ),
                "path": ParameterProperty(
                    type: "string",
                    description: "Base directory to search from (default: current directory)"
                ),
                "exclude": ParameterProperty(
                    type: "array",
                    description: "Patterns to exclude (e.g., ['node_modules', '.git'])",
                    items: ParameterProperty(type: "string", description: "Exclude pattern")
                ),
                "max_results": ParameterProperty(
                    type: "number",
                    description: "Maximum number of results (default: 100)"
                )
            ],
            required: ["pattern"]
        )

        super.init(
            name: "glob",
            description: "Find files matching glob patterns",
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
            let maxResults = try? intParameter(parameters, key: "max_results", default: 100)

            let excludePatterns: [String]
            if let excludeArray = parameters["exclude"] as? [String] {
                excludePatterns = excludeArray
            } else {
                excludePatterns = [".git", ".build", "node_modules", "Pods", "DerivedData"]
            }

            let fullPath = resolvePath(searchPath ?? context.workingDirectory, workingDirectory: context.workingDirectory)

            logInfo("Finding files matching '\(pattern)' in \(fullPath)", category: "GlobTool")

            // Find matching files
            let matches = try findFiles(
                pattern: pattern,
                basePath: fullPath,
                excludePatterns: excludePatterns,
                maxResults: maxResults ?? 100
            )

            let output = formatResults(matches, basePath: fullPath)

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
                "matches_found": matches.count
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

    // MARK: - File Finding

    /// Find files matching glob pattern
    private func findFiles(
        pattern: String,
        basePath: String,
        excludePatterns: [String],
        maxResults: Int
    ) throws -> [String] {
        var matches: [String] = []
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: basePath) else {
            throw ToolError.notFound(basePath)
        }

        // Parse glob pattern
        let (directoryPattern, filePattern) = parseGlobPattern(pattern)

        // Enumerate files
        if let enumerator = fileManager.enumerator(atPath: basePath) {
            for case let file as String in enumerator {
                // Check if we've hit max results
                if matches.count >= maxResults {
                    break
                }

                // Skip excluded patterns
                if shouldExclude(file, patterns: excludePatterns) {
                    continue
                }

                let fullPath = (basePath as NSString).appendingPathComponent(file)

                // Check if file (not directory)
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    continue
                }

                // Check if matches pattern
                if matchesGlobPattern(file, directoryPattern: directoryPattern, filePattern: filePattern) {
                    matches.append(fullPath)
                }
            }
        }

        // Sort by modification time (most recent first)
        matches.sort { path1, path2 in
            guard let date1 = try? fileManager.attributesOfItem(atPath: path1)[.modificationDate] as? Date,
                  let date2 = try? fileManager.attributesOfItem(atPath: path2)[.modificationDate] as? Date else {
                return false
            }
            return date1 > date2
        }

        return matches
    }

    /// Parse glob pattern into directory and file patterns
    private func parseGlobPattern(_ pattern: String) -> (directoryPattern: String?, filePattern: String) {
        let components = pattern.components(separatedBy: "/")

        if components.count == 1 {
            // Simple file pattern
            return (nil, components[0])
        }

        // Has directory pattern
        let filePattern = components.last ?? "*"
        let directoryPattern = components.dropLast().joined(separator: "/")

        return (directoryPattern, filePattern)
    }

    /// Check if path matches glob pattern
    private func matchesGlobPattern(_ path: String, directoryPattern: String?, filePattern: String) -> Bool {
        let components = path.components(separatedBy: "/")
        let filename = components.last ?? path

        // Check file pattern
        if !matchesPattern(filename, pattern: filePattern) {
            return false
        }

        // Check directory pattern if present
        if let dirPattern = directoryPattern {
            let dirPath = components.dropLast().joined(separator: "/")
            return matchesPattern(dirPath, pattern: dirPattern)
        }

        return true
    }

    /// Check if string matches glob pattern
    private func matchesPattern(_ string: String, pattern: String) -> Bool {
        if pattern == "*" || pattern == "**" {
            return true
        }

        // Convert glob to regex
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**", with: "⚡️")  // Temporary placeholder
            .replacingOccurrences(of: "*", with: "[^/]*")
            .replacingOccurrences(of: "⚡️", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$") else {
            return false
        }

        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }

    /// Check if path should be excluded
    private func shouldExclude(_ path: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if path.contains(pattern) {
                return true
            }
        }
        return false
    }

    /// Format results for display
    private func formatResults(_ matches: [String], basePath: String) -> String {
        if matches.isEmpty {
            return "No files found matching pattern."
        }

        var output: [String] = []
        output.append("Found \(matches.count) file(s):\n")

        for match in matches {
            // Make path relative to base if possible
            let relativePath: String
            if match.hasPrefix(basePath) {
                relativePath = String(match.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else {
                relativePath = match
            }

            // Get file size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: match),
               let size = attributes[.size] as? Int64 {
                let sizeStr = formatFileSize(size)
                output.append("  📄 \(relativePath) (\(sizeStr))")
            } else {
                output.append("  📄 \(relativePath)")
            }
        }

        return output.joined(separator: "\n")
    }

    /// Format file size
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
