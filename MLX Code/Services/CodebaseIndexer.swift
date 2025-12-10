//
//  CodebaseIndexer.swift
//  MLX Code
//
//  Semantic code indexing and search
//  Created on 2025-12-09
//

import Foundation

/// Indexes codebases for semantic search and smart context
actor CodebaseIndexer {
    static let shared = CodebaseIndexer()

    /// Indexed file entry
    struct IndexedFile: Codable {
        let path: String
        let content: String
        let language: String
        let lastModified: Date
        let size: Int
        let symbols: [Symbol]
    }

    /// Code symbol (function, class, etc.)
    struct Symbol: Codable {
        let name: String
        let type: SymbolType
        let line: Int
        let signature: String?
    }

    enum SymbolType: String, Codable {
        case function
        case classType
        case structType
        case enumType
        case protocolType
        case property
        case method
    }

    // MARK: - Properties

    private var index: [String: IndexedFile] = [:]
    private var isIndexing: Bool = false

    private init() {}

    // MARK: - Indexing

    /// Indexes a directory recursively
    /// - Parameter path: Directory path to index
    /// - Returns: Number of files indexed
    func indexDirectory(_ path: String) async throws -> Int {
        guard !isIndexing else {
            throw CodebaseError.indexingInProgress
        }

        isIndexing = true
        defer { isIndexing = false }

        let fileManager = FileManager.default
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        var filesIndexed = 0

        // Recursively find all Swift, Objective-C, and Python files
        let extensions = ["swift", "m", "mm", "h", "py", "js", "ts", "jsx", "tsx"]

        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                guard let ext = fileURL.pathExtension.lowercased() as String?,
                      extensions.contains(ext) else {
                    continue
                }

                // Skip build directories
                if fileURL.path.contains("build/") ||
                   fileURL.path.contains("DerivedData/") ||
                   fileURL.path.contains(".build/") ||
                   fileURL.path.contains("Pods/") {
                    continue
                }

                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let symbols = extractSymbols(from: content, language: ext)

                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let size = attributes[.size] as? Int ?? 0
                    let modified = attributes[.modificationDate] as? Date ?? Date()

                    let indexed = IndexedFile(
                        path: fileURL.path,
                        content: content,
                        language: ext,
                        lastModified: modified,
                        size: size,
                        symbols: symbols
                    )

                    index[fileURL.path] = indexed
                    filesIndexed += 1
                } catch {
                    // Skip files we can't read
                    continue
                }
            }
        }

        return filesIndexed
    }

    /// Searches indexed files for a pattern
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum results to return
    /// - Returns: Matching files with relevance scores
    func search(_ query: String, limit: Int = 10) async -> [(file: IndexedFile, score: Double)] {
        let lowercaseQuery = query.lowercased()
        var results: [(file: IndexedFile, score: Double)] = []

        for file in index.values {
            var score = 0.0

            // Check file name
            if file.path.lowercased().contains(lowercaseQuery) {
                score += 10.0
            }

            // Check symbols
            for symbol in file.symbols {
                if symbol.name.lowercased().contains(lowercaseQuery) {
                    score += 5.0
                }
            }

            // Check content
            let contentLower = file.content.lowercased()
            let occurrences = contentLower.components(separatedBy: lowercaseQuery).count - 1
            score += Double(occurrences) * 0.5

            if score > 0 {
                results.append((file, score))
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        return Array(results.prefix(limit))
    }

    /// Finds files similar to a given file
    /// - Parameter path: File path
    /// - Returns: Similar files
    func findSimilarFiles(_ path: String, limit: Int = 5) async -> [IndexedFile] {
        guard let file = index[path] else { return [] }

        var scores: [(file: IndexedFile, score: Double)] = []

        for otherFile in index.values where otherFile.path != path {
            var score = 0.0

            // Same language bonus
            if otherFile.language == file.language {
                score += 5.0
            }

            // Shared symbols
            let sharedSymbols = Set(file.symbols.map { $0.name }).intersection(Set(otherFile.symbols.map { $0.name }))
            score += Double(sharedSymbols.count) * 2.0

            if score > 0 {
                scores.append((otherFile, score))
            }
        }

        scores.sort { $0.score > $1.score }
        return scores.prefix(limit).map { $0.file }
    }

    /// Gets statistics about the index
    func getStatistics() async -> IndexStatistics {
        let totalFiles = index.count
        let totalSize = index.values.reduce(0) { $0 + $1.size }
        let totalSymbols = index.values.reduce(0) { $0 + $1.symbols.count }

        let languageCounts = Dictionary(grouping: index.values, by: { $0.language })
            .mapValues { $0.count }

        return IndexStatistics(
            totalFiles: totalFiles,
            totalSize: totalSize,
            totalSymbols: totalSymbols,
            languageCounts: languageCounts
        )
    }

    // MARK: - Private Methods

    private func extractSymbols(from content: String, language: String) -> [Symbol] {
        var symbols: [Symbol] = []
        let lines = content.components(separatedBy: .newlines)

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            switch language {
            case "swift":
                // Extract Swift symbols
                if let symbol = extractSwiftSymbol(from: trimmed, line: lineNumber + 1) {
                    symbols.append(symbol)
                }
            case "py":
                // Extract Python symbols
                if let symbol = extractPythonSymbol(from: trimmed, line: lineNumber + 1) {
                    symbols.append(symbol)
                }
            case "m", "mm", "h":
                // Extract Objective-C symbols
                if let symbol = extractObjCSymbol(from: trimmed, line: lineNumber + 1) {
                    symbols.append(symbol)
                }
            default:
                break
            }
        }

        return symbols
    }

    private func extractSwiftSymbol(from line: String, line lineNumber: Int) -> Symbol? {
        // Match: func, class, struct, enum, protocol
        if line.hasPrefix("func ") {
            let name = line.components(separatedBy: "(").first?
                .replacingOccurrences(of: "func ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .function, line: lineNumber, signature: line)
        }

        if line.hasPrefix("class ") {
            let name = line.components(separatedBy: CharacterSet(charactersIn: ":{<")).first?
                .replacingOccurrences(of: "class ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .classType, line: lineNumber, signature: nil)
        }

        if line.hasPrefix("struct ") {
            let name = line.components(separatedBy: CharacterSet(charactersIn: ":{<")).first?
                .replacingOccurrences(of: "struct ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .structType, line: lineNumber, signature: nil)
        }

        if line.hasPrefix("enum ") {
            let name = line.components(separatedBy: CharacterSet(charactersIn: ":{<")).first?
                .replacingOccurrences(of: "enum ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .enumType, line: lineNumber, signature: nil)
        }

        return nil
    }

    private func extractPythonSymbol(from line: String, line lineNumber: Int) -> Symbol? {
        if line.hasPrefix("def ") {
            let name = line.components(separatedBy: "(").first?
                .replacingOccurrences(of: "def ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .function, line: lineNumber, signature: line)
        }

        if line.hasPrefix("class ") {
            let name = line.components(separatedBy: CharacterSet(charactersIn: ":(")).first?
                .replacingOccurrences(of: "class ", with: "")
                .trimmingCharacters(in: .whitespaces) ?? ""
            return Symbol(name: name, type: .classType, line: lineNumber, signature: nil)
        }

        return nil
    }

    private func extractObjCSymbol(from line: String, line lineNumber: Int) -> Symbol? {
        // Match @interface, @implementation, - (void), + (void)
        if line.hasPrefix("@interface ") {
            let name = line.replacingOccurrences(of: "@interface ", with: "")
                .components(separatedBy: CharacterSet(charactersIn: " :<()")).first ?? ""
            return Symbol(name: name, type: .classType, line: lineNumber, signature: nil)
        }

        if line.hasPrefix("- (") || line.hasPrefix("+ (") {
            // Extract method name
            if let methodRange = line.range(of: "\\)\\s*\\w+", options: .regularExpression) {
                let method = String(line[methodRange])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ") "))
                return Symbol(name: method, type: .method, line: lineNumber, signature: line)
            }
        }

        return nil
    }
}

/// Index statistics
struct IndexStatistics {
    let totalFiles: Int
    let totalSize: Int
    let totalSymbols: Int
    let languageCounts: [String: Int]

    var totalSizeFormatted: String {
        let mb = Double(totalSize) / (1024 * 1024)
        if mb < 1 {
            let kb = Double(totalSize) / 1024
            return String(format: "%.1f KB", kb)
        } else if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            let gb = mb / 1024
            return String(format: "%.2f GB", gb)
        }
    }
}

/// Codebase indexing errors
enum CodebaseError: LocalizedError {
    case indexingInProgress
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .indexingInProgress:
            return "Indexing already in progress"
        case .invalidPath:
            return "Invalid directory path"
        }
    }
}
