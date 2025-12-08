//
//  ContextAnalysisService.swift
//  MLX Code
//
//  Created on 2025-12-08.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for context-aware code analysis
/// Uses SourceKit for Swift/Obj-C symbol parsing and understands project architecture
actor ContextAnalysisService {
    /// Shared singleton instance
    static let shared = ContextAnalysisService()

    /// Currently active workspace/project
    private var activeProjectPath: String?

    /// Cached symbol index
    private var symbolIndex: SymbolIndex?

    /// Last update time for symbol index
    private var lastIndexUpdate: Date?

    /// Minimum time between index updates (seconds)
    private let minimumIndexInterval: TimeInterval = 30.0

    private init() {}

    // MARK: - Project Detection

    /// Auto-detects active Xcode workspace or project
    /// - Parameter directoryPath: Optional directory to search from (defaults to workspace path from settings)
    /// - Returns: Path to detected workspace/project, or nil if none found
    func detectActiveProject(from directoryPath: String? = nil) async throws -> String? {
        await SecureLogger.shared.info("Detecting active Xcode project", category: "ContextAnalysis")

        let searchPath = directoryPath ?? await AppSettings.shared.workspacePath
        let expandedPath = (searchPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            await SecureLogger.shared.warning("Search path does not exist: \(expandedPath)", category: "ContextAnalysis")
            return nil
        }

        // Look for .xcworkspace first, then .xcodeproj
        let workspace = try await findFile(withExtension: ".xcworkspace", in: expandedPath)
        if let workspace = workspace {
            activeProjectPath = workspace
            await SecureLogger.shared.info("Found workspace: \(workspace)", category: "ContextAnalysis")
            return workspace
        }

        let project = try await findFile(withExtension: ".xcodeproj", in: expandedPath)
        if let project = project {
            activeProjectPath = project
            await SecureLogger.shared.info("Found project: \(project)", category: "ContextAnalysis")
            return project
        }

        await SecureLogger.shared.warning("No Xcode workspace or project found in: \(expandedPath)", category: "ContextAnalysis")
        return nil
    }

    /// Sets the active project path manually
    /// - Parameter path: Path to workspace or project
    func setActiveProject(_ path: String) async {
        activeProjectPath = path
        symbolIndex = nil // Clear cache
        lastIndexUpdate = nil
        await SecureLogger.shared.info("Active project set to: \(path)", category: "ContextAnalysis")
    }

    /// Gets the currently active project path
    /// - Returns: Active project path, or nil if none set
    func getActiveProject() -> String? {
        return activeProjectPath
    }

    // MARK: - Symbol Indexing

    /// Indexes symbols in the active project
    /// - Parameters:
    ///   - force: Force reindex even if recently updated
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Symbol index
    /// - Throws: ContextAnalysisError if indexing fails
    func indexProject(force: Bool = false, progressHandler: ((Int, String) -> Void)? = nil) async throws -> SymbolIndex {
        guard let projectPath = activeProjectPath else {
            throw ContextAnalysisError.noActiveProject
        }

        // Check if we can use cached index
        if !force,
           let index = symbolIndex,
           let lastUpdate = lastIndexUpdate,
           Date().timeIntervalSince(lastUpdate) < minimumIndexInterval {
            await SecureLogger.shared.info("Using cached symbol index", category: "ContextAnalysis")
            return index
        }

        await SecureLogger.shared.info("Indexing project: \(projectPath)", category: "ContextAnalysis")

        // Find project directory (parent of .xcodeproj/.xcworkspace)
        let projectDir = (projectPath as NSString).deletingLastPathComponent

        // Find all Swift and Objective-C files
        let swiftFiles = try await findFiles(withExtensions: [".swift"], in: projectDir)
        let objcFiles = try await findFiles(withExtensions: [".m", ".mm", ".h"], in: projectDir)
        let allFiles = swiftFiles + objcFiles

        await SecureLogger.shared.info("Found \(allFiles.count) source files to index", category: "ContextAnalysis")

        var classes: [SymbolInfo] = []
        var structs: [SymbolInfo] = []
        var protocols: [SymbolInfo] = []
        var functions: [SymbolInfo] = []
        var properties: [SymbolInfo] = []

        // Parse each file
        for (index, filePath) in allFiles.enumerated() {
            progressHandler?(index + 1, filePath)

            do {
                let fileSymbols = try await parseFile(filePath)
                classes.append(contentsOf: fileSymbols.classes)
                structs.append(contentsOf: fileSymbols.structs)
                protocols.append(contentsOf: fileSymbols.protocols)
                functions.append(contentsOf: fileSymbols.functions)
                properties.append(contentsOf: fileSymbols.properties)
            } catch {
                await SecureLogger.shared.warning("Failed to parse \(filePath): \(error)", category: "ContextAnalysis")
            }
        }

        let index = SymbolIndex(
            projectPath: projectPath,
            classes: classes,
            structs: structs,
            protocols: protocols,
            functions: functions,
            properties: properties,
            fileCount: allFiles.count
        )

        symbolIndex = index
        lastIndexUpdate = Date()

        await SecureLogger.shared.info("Indexing complete: \(index.totalSymbols) symbols found", category: "ContextAnalysis")

        return index
    }

    /// Gets current symbol index (returns cached if available)
    /// - Returns: Symbol index, or nil if not indexed yet
    func getSymbolIndex() -> SymbolIndex? {
        return symbolIndex
    }

    // MARK: - Symbol Lookup

    /// Finds symbols matching a name or pattern
    /// - Parameters:
    ///   - name: Symbol name or pattern to search for
    ///   - type: Optional symbol type filter
    /// - Returns: Array of matching symbols
    func findSymbols(matching name: String, ofType type: SymbolType? = nil) async throws -> [SymbolInfo] {
        guard let index = symbolIndex else {
            throw ContextAnalysisError.notIndexed
        }

        let lowercasedName = name.lowercased()
        var results: [SymbolInfo] = []

        // Search based on type filter
        let searchArrays: [[SymbolInfo]]
        if let type = type {
            switch type {
            case .class:
                searchArrays = [index.classes]
            case .struct:
                searchArrays = [index.structs]
            case .protocol:
                searchArrays = [index.protocols]
            case .function:
                searchArrays = [index.functions]
            case .property:
                searchArrays = [index.properties]
            }
        } else {
            searchArrays = [index.classes, index.structs, index.protocols, index.functions, index.properties]
        }

        // Fuzzy search through symbols
        for array in searchArrays {
            for symbol in array {
                if symbol.name.lowercased().contains(lowercasedName) {
                    results.append(symbol)
                }
            }
        }

        await SecureLogger.shared.info("Found \(results.count) symbols matching '\(name)'", category: "ContextAnalysis")

        return results
    }

    /// Gets context for a specific file
    /// - Parameter filePath: Path to file
    /// - Returns: File context including symbols defined in the file
    func getFileContext(_ filePath: String) async throws -> FileContext {
        guard let index = symbolIndex else {
            throw ContextAnalysisError.notIndexed
        }

        let expandedPath = (filePath as NSString).expandingTildeInPath

        // Find all symbols in this file
        var fileClasses: [SymbolInfo] = []
        var fileStructs: [SymbolInfo] = []
        var fileProtocols: [SymbolInfo] = []
        var fileFunctions: [SymbolInfo] = []
        var fileProperties: [SymbolInfo] = []

        for symbol in index.classes where symbol.filePath == expandedPath {
            fileClasses.append(symbol)
        }

        for symbol in index.structs where symbol.filePath == expandedPath {
            fileStructs.append(symbol)
        }

        for symbol in index.protocols where symbol.filePath == expandedPath {
            fileProtocols.append(symbol)
        }

        for symbol in index.functions where symbol.filePath == expandedPath {
            fileFunctions.append(symbol)
        }

        for symbol in index.properties where symbol.filePath == expandedPath {
            fileProperties.append(symbol)
        }

        return FileContext(
            filePath: expandedPath,
            classes: fileClasses,
            structs: fileStructs,
            protocols: fileProtocols,
            functions: fileFunctions,
            properties: fileProperties
        )
    }

    // MARK: - Context Generation

    /// Generates context string for AI prompt
    /// - Parameters:
    ///   - query: User query
    ///   - maxSymbols: Maximum number of relevant symbols to include
    /// - Returns: Formatted context string
    func generateContext(for query: String, maxSymbols: Int = 10) async throws -> String {
        guard let index = symbolIndex else {
            throw ContextAnalysisError.notIndexed
        }

        var contextParts: [String] = []

        // Add project summary
        contextParts.append("# Project Context")
        contextParts.append("Project: \(index.projectPath)")
        contextParts.append("Total Symbols: \(index.totalSymbols)")
        contextParts.append("- Classes: \(index.classes.count)")
        contextParts.append("- Structs: \(index.structs.count)")
        contextParts.append("- Protocols: \(index.protocols.count)")
        contextParts.append("- Functions: \(index.functions.count)")
        contextParts.append("- Properties: \(index.properties.count)")
        contextParts.append("")

        // Find relevant symbols based on query
        let relevantSymbols = try await findSymbols(matching: query)

        if !relevantSymbols.isEmpty {
            contextParts.append("# Relevant Symbols")
            for (i, symbol) in relevantSymbols.prefix(maxSymbols).enumerated() {
                contextParts.append("\(i+1). \(symbol.type.rawValue.capitalized): \(symbol.name)")
                contextParts.append("   File: \(symbol.fileName)")
                if let line = symbol.lineNumber {
                    contextParts.append("   Line: \(line)")
                }
                if let signature = symbol.signature {
                    contextParts.append("   Signature: \(signature)")
                }
                contextParts.append("")
            }
        }

        return contextParts.joined(separator: "\n")
    }

    // MARK: - Private Methods

    /// Finds a file with given extension in directory
    private func findFile(withExtension ext: String, in directory: String) async throws -> String? {
        let url = URL(fileURLWithPath: directory)

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.path.hasSuffix(ext) {
                return fileURL.path
            }
        }

        return nil
    }

    /// Finds all files with given extensions in directory
    private func findFiles(withExtensions extensions: [String], in directory: String) async throws -> [String] {
        let url = URL(fileURLWithPath: directory)
        var results: [String] = []

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let path = fileURL.path

            // Skip build directories and dependencies
            if path.contains("/Build/") ||
               path.contains("/DerivedData/") ||
               path.contains("/.build/") ||
               path.contains("/Pods/") ||
               path.contains("/Carthage/") {
                continue
            }

            for ext in extensions {
                if path.hasSuffix(ext) {
                    results.append(path)
                    break
                }
            }
        }

        return results
    }

    /// Parses a source file for symbols
    private func parseFile(_ filePath: String) async throws -> FileSymbols {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var classes: [SymbolInfo] = []
        var structs: [SymbolInfo] = []
        var protocols: [SymbolInfo] = []
        var functions: [SymbolInfo] = []
        var properties: [SymbolInfo] = []

        let fileName = (filePath as NSString).lastPathComponent

        // Simple regex-based parsing (faster than SourceKit for basic needs)
        // For Swift files
        if filePath.hasSuffix(".swift") {
            for (lineNumber, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Match class declarations
                if let match = trimmed.range(of: #"^(public |private |internal |open )?class\s+(\w+)"#, options: .regularExpression) {
                    let className = extractName(from: trimmed, pattern: #"class\s+(\w+)"#)
                    if let name = className {
                        classes.append(SymbolInfo(
                            name: name,
                            type: .class,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }

                // Match struct declarations
                else if let _ = trimmed.range(of: #"^(public |private |internal )?struct\s+(\w+)"#, options: .regularExpression) {
                    let structName = extractName(from: trimmed, pattern: #"struct\s+(\w+)"#)
                    if let name = structName {
                        structs.append(SymbolInfo(
                            name: name,
                            type: .struct,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }

                // Match protocol declarations
                else if let _ = trimmed.range(of: #"^(public |private |internal )?protocol\s+(\w+)"#, options: .regularExpression) {
                    let protocolName = extractName(from: trimmed, pattern: #"protocol\s+(\w+)"#)
                    if let name = protocolName {
                        protocols.append(SymbolInfo(
                            name: name,
                            type: .protocol,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }

                // Match function declarations
                else if let _ = trimmed.range(of: #"^(public |private |internal |open )?(static )?func\s+(\w+)"#, options: .regularExpression) {
                    let funcName = extractName(from: trimmed, pattern: #"func\s+(\w+)"#)
                    if let name = funcName {
                        functions.append(SymbolInfo(
                            name: name,
                            type: .function,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1,
                            signature: trimmed
                        ))
                    }
                }

                // Match property declarations
                else if let _ = trimmed.range(of: #"^(public |private |internal )?(let |var)\s+(\w+)"#, options: .regularExpression) {
                    let propName = extractName(from: trimmed, pattern: #"(let |var)\s+(\w+)"#)
                    if let name = propName {
                        properties.append(SymbolInfo(
                            name: name,
                            type: .property,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }
            }
        }

        // For Objective-C files
        else if filePath.hasSuffix(".m") || filePath.hasSuffix(".mm") || filePath.hasSuffix(".h") {
            for (lineNumber, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Match @interface declarations
                if let _ = trimmed.range(of: #"^@interface\s+(\w+)"#, options: .regularExpression) {
                    let className = extractName(from: trimmed, pattern: #"@interface\s+(\w+)"#)
                    if let name = className {
                        classes.append(SymbolInfo(
                            name: name,
                            type: .class,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }

                // Match @protocol declarations
                else if let _ = trimmed.range(of: #"^@protocol\s+(\w+)"#, options: .regularExpression) {
                    let protocolName = extractName(from: trimmed, pattern: #"@protocol\s+(\w+)"#)
                    if let name = protocolName {
                        protocols.append(SymbolInfo(
                            name: name,
                            type: .protocol,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1
                        ))
                    }
                }

                // Match method declarations
                else if trimmed.hasPrefix("-") || trimmed.hasPrefix("+") {
                    if let name = extractObjCMethodName(from: trimmed) {
                        functions.append(SymbolInfo(
                            name: name,
                            type: .function,
                            filePath: filePath,
                            fileName: fileName,
                            lineNumber: lineNumber + 1,
                            signature: trimmed
                        ))
                    }
                }
            }
        }

        return FileSymbols(
            classes: classes,
            structs: structs,
            protocols: protocols,
            functions: functions,
            properties: properties
        )
    }

    /// Extracts name from regex match
    private func extractName(from string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else {
            return nil
        }

        // Get last capture group (the name)
        let lastGroupIndex = match.numberOfRanges - 1
        guard lastGroupIndex > 0 else { return nil }

        let matchRange = match.range(at: lastGroupIndex)
        guard matchRange.location != NSNotFound,
              let range = Range(matchRange, in: string) else {
            return nil
        }

        return String(string[range])
    }

    /// Extracts Objective-C method name
    private func extractObjCMethodName(from string: String) -> String? {
        // Match pattern like "- (void)methodName:(Type)param" -> "methodName:"
        let components = string.components(separatedBy: ")")
        guard components.count >= 2 else { return nil }

        let methodPart = components[1].trimmingCharacters(in: .whitespaces)
        if let spaceIndex = methodPart.firstIndex(of: " ") {
            return String(methodPart[..<spaceIndex])
        }

        return methodPart
    }
}

// MARK: - Data Models

/// Symbol index containing all discovered symbols
struct SymbolIndex {
    let projectPath: String
    let classes: [SymbolInfo]
    let structs: [SymbolInfo]
    let protocols: [SymbolInfo]
    let functions: [SymbolInfo]
    let properties: [SymbolInfo]
    let fileCount: Int

    var totalSymbols: Int {
        return classes.count + structs.count + protocols.count + functions.count + properties.count
    }
}

/// Information about a symbol
struct SymbolInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: SymbolType
    let filePath: String
    let fileName: String
    let lineNumber: Int?
    let signature: String?

    init(name: String, type: SymbolType, filePath: String, fileName: String, lineNumber: Int? = nil, signature: String? = nil) {
        self.name = name
        self.type = type
        self.filePath = filePath
        self.fileName = fileName
        self.lineNumber = lineNumber
        self.signature = signature
    }
}

/// Type of symbol
enum SymbolType: String {
    case `class`
    case `struct`
    case `protocol`
    case function
    case property
}

/// Symbols found in a file
private struct FileSymbols {
    let classes: [SymbolInfo]
    let structs: [SymbolInfo]
    let protocols: [SymbolInfo]
    let functions: [SymbolInfo]
    let properties: [SymbolInfo]
}

/// Context for a specific file
struct FileContext {
    let filePath: String
    let classes: [SymbolInfo]
    let structs: [SymbolInfo]
    let protocols: [SymbolInfo]
    let functions: [SymbolInfo]
    let properties: [SymbolInfo]

    var totalSymbols: Int {
        return classes.count + structs.count + protocols.count + functions.count + properties.count
    }
}

// MARK: - Errors

/// Errors that can occur during context analysis
enum ContextAnalysisError: LocalizedError {
    case noActiveProject
    case notIndexed
    case projectNotFound(String)
    case indexingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProject:
            return "No active project set. Use detectActiveProject() or setActiveProject() first."
        case .notIndexed:
            return "Project not indexed. Call indexProject() first."
        case .projectNotFound(let path):
            return "Project not found: \(path)"
        case .indexingFailed(let message):
            return "Indexing failed: \(message)"
        }
    }
}
