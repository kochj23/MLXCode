//
//  RAGService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for Retrieval-Augmented Generation (RAG)
/// Manages codebase indexing, embeddings, and semantic search
actor RAGService {
    /// Shared singleton instance
    static let shared = RAGService()

    /// Whether the RAG system is initialized
    private var isInitialized = false

    private init() {}

    /// Gets the path to the RAG Python script
    /// - Returns: Full path to the script, or nil if not found
    private func getScriptPath() -> String? {
        // Try bundle resource first
        if let bundlePath = Bundle.main.path(forResource: "rag_system", ofType: "py") {
            return bundlePath
        }

        // Fall back to development directory
        let projectPath = "/Volumes/Data/xcode/MLX Code/Python/rag_system.py"
        if FileManager.default.fileExists(atPath: projectPath) {
            return projectPath
        }

        return nil
    }

    // MARK: - Indexing

    /// Indexes a directory for semantic search
    /// - Parameters:
    ///   - directoryPath: Path to directory to index
    ///   - extensions: File extensions to include (nil for defaults)
    ///   - excludePatterns: Patterns to exclude (nil for defaults)
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Indexing statistics
    /// - Throws: RAGServiceError if indexing fails
    func indexDirectory(
        _ directoryPath: String,
        extensions: [String]? = nil,
        excludePatterns: [String]? = nil,
        progressHandler: ((String, Int) -> Void)? = nil
    ) async throws -> IndexingResult {
        await SecureLogger.shared.info("Starting directory indexing: \(directoryPath)", category: "RAGService")

        // Expand path
        let expandedPath = (directoryPath as NSString).expandingTildeInPath

        // Verify directory exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw RAGServiceError.pathNotFound(expandedPath)
        }

        // Build command
        var args = ["index", expandedPath]

        if let extensions = extensions {
            args.append("--extensions")
            args.append(contentsOf: extensions)
        }

        if let excludePatterns = excludePatterns {
            args.append("--exclude")
            args.append(contentsOf: excludePatterns)
        }

        // Run Python script
        let (output, error) = try await runPythonScript(args: args)

        // Parse result
        guard let resultData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw RAGServiceError.invalidResponse("Failed to parse indexing result")
        }

        guard let success = json["success"] as? Bool, success else {
            let errorMessage = json["error"] as? String ?? "Unknown error"
            throw RAGServiceError.indexingFailed(errorMessage)
        }

        let indexed = json["indexed"] as? Int ?? 0
        let skipped = json["skipped"] as? Int ?? 0
        let errors = json["errors"] as? Int ?? 0

        await SecureLogger.shared.info("Indexing complete: \(indexed) files indexed, \(skipped) skipped, \(errors) errors", category: "RAGService")

        return IndexingResult(
            indexed: indexed,
            skipped: skipped,
            errors: errors,
            directory: expandedPath
        )
    }

    /// Indexes a single file
    /// - Parameter filePath: Path to file
    /// - Returns: Indexing result
    /// - Throws: RAGServiceError if indexing fails
    func indexFile(_ filePath: String) async throws -> FileIndexResult {
        await SecureLogger.shared.info("Indexing file: \(filePath)", category: "RAGService")

        let expandedPath = (filePath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw RAGServiceError.pathNotFound(expandedPath)
        }

        // For single file, we can use directory indexing with specific path
        let result = try await indexDirectory(
            expandedPath,
            extensions: [Path(filePath).extension]
        )

        return FileIndexResult(
            filePath: expandedPath,
            chunks: result.indexed
        )
    }

    // MARK: - Search

    /// Searches for relevant code snippets
    /// - Parameters:
    ///   - query: Search query
    ///   - maxResults: Maximum number of results
    ///   - fileExtensions: Optional filter by file extensions
    /// - Returns: Array of search results
    /// - Throws: RAGServiceError if search fails
    func search(
        query: String,
        maxResults: Int = 5,
        fileExtensions: [String]? = nil
    ) async throws -> [SearchResult] {
        await SecureLogger.shared.info("Searching: \(query)", category: "RAGService")

        // Sanitize query
        let sanitizedQuery = SecurityUtils.sanitizeUserInput(query)

        // Build command
        var args = ["search", sanitizedQuery, "--n-results", "\(maxResults)"]

        if let extensions = fileExtensions {
            args.append("--extensions")
            args.append(contentsOf: extensions)
        }

        // Run Python script
        let (output, _) = try await runPythonScript(args: args)

        // Parse results
        guard let resultData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw RAGServiceError.invalidResponse("Failed to parse search results")
        }

        guard let success = json["success"] as? Bool, success else {
            let errorMessage = json["error"] as? String ?? "Unknown error"
            throw RAGServiceError.searchFailed(errorMessage)
        }

        guard let resultsArray = json["results"] as? [[String: Any]] else {
            return []
        }

        // Convert to SearchResult objects
        var searchResults: [SearchResult] = []

        for resultDict in resultsArray {
            guard let document = resultDict["document"] as? String,
                  let metadata = resultDict["metadata"] as? [String: Any],
                  let filePath = metadata["file_path"] as? String,
                  let fileName = metadata["file_name"] as? String else {
                continue
            }

            let result = SearchResult(
                document: document,
                filePath: filePath,
                fileName: fileName,
                fileExtension: metadata["file_extension"] as? String ?? "",
                chunkIndex: metadata["chunk_index"] as? Int ?? 0,
                totalChunks: metadata["total_chunks"] as? Int ?? 1,
                distance: resultDict["distance"] as? Double
            )

            searchResults.append(result)
        }

        await SecureLogger.shared.info("Found \(searchResults.count) results", category: "RAGService")

        return searchResults
    }

    /// Gets relevant context for a query to inject into prompts
    /// - Parameters:
    ///   - query: User query
    ///   - maxResults: Number of code snippets to retrieve
    ///   - maxContextLength: Maximum context length in characters
    /// - Returns: Formatted context string
    /// - Throws: RAGServiceError if retrieval fails
    func getContextForQuery(
        _ query: String,
        maxResults: Int = 3,
        maxContextLength: Int = 4000
    ) async throws -> String {
        await SecureLogger.shared.info("Getting context for query: \(query)", category: "RAGService")

        let sanitizedQuery = SecurityUtils.sanitizeUserInput(query)

        // Build command
        let args = [
            "context",
            sanitizedQuery,
            "--n-results", "\(maxResults)",
            "--max-length", "\(maxContextLength)"
        ]

        // Run Python script
        let (output, _) = try await runPythonScript(args: args)

        await SecureLogger.shared.info("Retrieved context (\(output.count) chars)", category: "RAGService")

        return output
    }

    // MARK: - Statistics

    /// Gets statistics about indexed data
    /// - Returns: RAG statistics
    /// - Throws: RAGServiceError if retrieval fails
    func getStatistics() async throws -> RAGStatistics {
        await SecureLogger.shared.info("Getting RAG statistics", category: "RAGService")

        let (output, _) = try await runPythonScript(args: ["stats"])

        guard let resultData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw RAGServiceError.invalidResponse("Failed to parse statistics")
        }

        guard let success = json["success"] as? Bool, success else {
            let errorMessage = json["error"] as? String ?? "Unknown error"
            throw RAGServiceError.operationFailed(errorMessage)
        }

        return RAGStatistics(
            totalChunks: json["total_chunks"] as? Int ?? 0,
            uniqueFiles: json["unique_files"] as? Int ?? 0,
            dbPath: json["db_path"] as? String ?? ""
        )
    }

    /// Clears all indexed data
    /// - Throws: RAGServiceError if clearing fails
    func clearAllData() async throws {
        await SecureLogger.shared.info("Clearing all RAG data", category: "RAGService")

        let (output, _) = try await runPythonScript(args: ["clear"])

        guard let resultData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
              let success = json["success"] as? Bool, success else {
            throw RAGServiceError.operationFailed("Failed to clear data")
        }

        await SecureLogger.shared.info("RAG data cleared successfully", category: "RAGService")
    }

    // MARK: - Private Methods

    /// Runs the RAG Python script with given arguments
    /// - Parameter args: Command-line arguments
    /// - Returns: Tuple of (stdout, stderr)
    /// - Throws: RAGServiceError if execution fails
    private func runPythonScript(args: [String]) async throws -> (String, String) {
        guard let scriptPath = getScriptPath() else {
            throw RAGServiceError.scriptNotFound("rag_system.py not found in bundle or development path")
        }

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw RAGServiceError.scriptNotFound(scriptPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath] + args

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus

        guard exitCode == 0 else {
            throw RAGServiceError.scriptExecutionFailed("Exit code \(exitCode): \(error)")
        }

        return (output, error)
    }
}

// MARK: - Data Models

/// Result of directory indexing
struct IndexingResult {
    let indexed: Int
    let skipped: Int
    let errors: Int
    let directory: String
}

/// Result of file indexing
struct FileIndexResult {
    let filePath: String
    let chunks: Int
}

/// Search result from RAG system
struct SearchResult {
    let document: String
    let filePath: String
    let fileName: String
    let fileExtension: String
    let chunkIndex: Int
    let totalChunks: Int
    let distance: Double?
}

/// RAG system statistics
struct RAGStatistics {
    let totalChunks: Int
    let uniqueFiles: Int
    let dbPath: String
}

// MARK: - Errors

/// Errors that can occur during RAG operations
enum RAGServiceError: LocalizedError {
    case scriptNotFound(String)
    case pathNotFound(String)
    case indexingFailed(String)
    case searchFailed(String)
    case operationFailed(String)
    case scriptExecutionFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "RAG script not found: \(path)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .indexingFailed(let message):
            return "Indexing failed: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .scriptExecutionFailed(let message):
            return "Script execution failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}

// MARK: - Path Helper

/// Simple path helper
private struct Path {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var `extension`: String {
        return (value as NSString).pathExtension
    }
}
