//
//  MultiFileOperations.swift
//  MLX Code
//
//  Batch operations across multiple files
//  Created on 2025-12-09
//

import Foundation

/// Handles operations across multiple files
actor MultiFileOperations {
    static let shared = MultiFileOperations()

    private init() {}

    // MARK: - Project-Wide Refactoring

    /// Refactors a symbol across entire project
    /// - Parameters:
    ///   - oldName: Current symbol name
    ///   - newName: New symbol name
    ///   - projectPath: Project directory
    /// - Returns: Number of files modified
    func renameSymbol(from oldName: String, to newName: String, in projectPath: String) async throws -> Int {
        let indexer = CodebaseIndexer.shared
        _ = try await indexer.indexDirectory(projectPath)

        let results = await indexer.search(oldName, limit: 100)
        var filesModified = 0

        for (file, _) in results {
            do {
                var content = file.content
                content = content.replacingOccurrences(of: "\\b\(oldName)\\b", with: newName, options: .regularExpression)

                try content.write(toFile: file.path, atomically: true, encoding: .utf8)
                filesModified += 1
            } catch {
                print("Failed to update \(file.path): \(error)")
            }
        }

        return filesModified
    }

    // MARK: - Batch Processing

    /// Applies an AI transformation to multiple files
    /// - Parameters:
    ///   - files: Files to process
    ///   - transformation: Description of transformation
    /// - Returns: Results for each file
    func batchTransform(files: [String], transformation: String) async throws -> [TransformResult] {
        var results: [TransformResult] = []

        for filePath in files {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)

                let prompt = """
                Apply this transformation to the code:
                \(transformation)

                Original code:
                ```
                \(content)
                ```

                Provide only the transformed code, no explanation.
                """

                let transformed = try await MLXService.shared.generate(prompt: prompt)

                results.append(TransformResult(
                    path: filePath,
                    success: true,
                    originalContent: content,
                    transformedContent: transformed,
                    error: nil
                ))
            } catch {
                results.append(TransformResult(
                    path: filePath,
                    success: false,
                    originalContent: nil,
                    transformedContent: nil,
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }

    /// Adds documentation to all functions in files
    /// - Parameter files: Files to document
    /// - Returns: Results
    func addDocumentationToFiles(_ files: [String]) async throws -> [TransformResult] {
        return try await batchTransform(
            files: files,
            transformation: "Add comprehensive documentation comments to all functions, classes, and methods. Use appropriate doc comment format for the language."
        )
    }

    /// Adds error handling to files
    /// - Parameter files: Files to update
    /// - Returns: Results
    func addErrorHandling(_ files: [String]) async throws -> [TransformResult] {
        return try await batchTransform(
            files: files,
            transformation: "Add comprehensive error handling: try-catch blocks, nil checks, guard statements, and helpful error messages."
        )
    }

    // MARK: - Search and Replace

    /// Performs intelligent search and replace across project
    /// - Parameters:
    ///   - pattern: Search pattern (can be regex)
    ///   - replacement: Replacement text
    ///   - projectPath: Project directory
    ///   - fileExtensions: File types to process
    /// - Returns: Number of files modified
    func searchAndReplace(
        pattern: String,
        with replacement: String,
        in projectPath: String,
        fileExtensions: [String] = ["swift", "m", "mm", "h"]
    ) async throws -> Int {
        let fileManager = FileManager.default
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        var filesModified = 0

        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                guard let ext = fileURL.pathExtension as String?,
                      fileExtensions.contains(ext) else {
                    continue
                }

                // Skip build directories
                if fileURL.path.contains("build/") || fileURL.path.contains("DerivedData/") {
                    continue
                }

                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let newContent = content.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)

                    if content != newContent {
                        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                        filesModified += 1
                    }
                } catch {
                    print("Failed to process \(fileURL.path): \(error)")
                }
            }
        }

        return filesModified
    }

    // MARK: - Code Generation

    /// Generates multiple related files
    /// - Parameters:
    ///   - description: Description of files to generate
    ///   - outputDir: Directory for generated files
    /// - Returns: Generated files
    func generateMultipleFiles(description: String, outputDir: String) async throws -> [GeneratedFile] {
        let prompt = """
        Generate multiple related files based on this description:
        \(description)

        For each file, provide:
        FILE: <filename>
        ```
        <file content>
        ```

        Generate complete, production-ready code.
        """

        let response = try await MLXService.shared.generate(prompt: prompt)

        // Parse response to extract files
        return parseGeneratedFiles(from: response, outputDir: outputDir)
    }

    private func parseGeneratedFiles(from response: String, outputDir: String) -> [GeneratedFile] {
        var files: [GeneratedFile] = []
        let lines = response.components(separatedBy: "\n")

        var currentFile: String?
        var currentContent: [String] = []
        var inCodeBlock = false

        for line in lines {
            if line.hasPrefix("FILE:") {
                // Save previous file
                if let filename = currentFile, !currentContent.isEmpty {
                    let content = currentContent.joined(separator: "\n")
                    let path = (outputDir as NSString).appendingPathComponent(filename)
                    files.append(GeneratedFile(path: path, content: content))
                }

                // Start new file
                currentFile = line.replacingOccurrences(of: "FILE:", with: "").trimmingCharacters(in: .whitespaces)
                currentContent = []
                inCodeBlock = false
            } else if line.hasPrefix("```") {
                inCodeBlock.toggle()
            } else if inCodeBlock && currentFile != nil {
                currentContent.append(line)
            }
        }

        // Save last file
        if let filename = currentFile, !currentContent.isEmpty {
            let content = currentContent.joined(separator: "\n")
            let path = (outputDir as NSString).appendingPathComponent(filename)
            files.append(GeneratedFile(path: path, content: content))
        }

        return files
    }
}

// MARK: - Supporting Types

/// Result of file transformation
struct TransformResult {
    let path: String
    let success: Bool
    let originalContent: String?
    let transformedContent: String?
    let error: String?
}

/// Generated file
struct GeneratedFile {
    let path: String
    let content: String
}
