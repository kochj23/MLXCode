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

        let searchPath: String
        if let directoryPath = directoryPath {
            searchPath = directoryPath
        } else {
            searchPath = await AppSettings.shared.workspacePath
        }
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

        var classes: [AnalysisSymbolInfo] = []
        var structs: [AnalysisSymbolInfo] = []
        var protocols: [AnalysisSymbolInfo] = []
        var functions: [AnalysisSymbolInfo] = []
        var properties: [AnalysisSymbolInfo] = []

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
    func findSymbols(matching name: String, ofType type: SymbolType? = nil) async throws -> [AnalysisSymbolInfo] {
        guard let index = symbolIndex else {
            throw ContextAnalysisError.notIndexed
        }

        let lowercasedName = name.lowercased()
        var results: [AnalysisSymbolInfo] = []

        // Search based on type filter
        let searchArrays: [[AnalysisSymbolInfo]]
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
    func getAnalysisFileContext(_ filePath: String) async throws -> AnalysisFileContext {
        guard let index = symbolIndex else {
            throw ContextAnalysisError.notIndexed
        }

        let expandedPath = (filePath as NSString).expandingTildeInPath

        // Find all symbols in this file
        var fileClasses: [AnalysisSymbolInfo] = []
        var fileStructs: [AnalysisSymbolInfo] = []
        var fileProtocols: [AnalysisSymbolInfo] = []
        var fileFunctions: [AnalysisSymbolInfo] = []
        var fileProperties: [AnalysisSymbolInfo] = []

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

        return AnalysisFileContext(
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

    // MARK: - Code Metrics

    /// Gets code metrics for the active project
    /// - Returns: Code metrics summary
    func getCodeMetrics() async throws -> CodeMetrics {
        guard let projectPath = activeProjectPath else {
            throw ContextAnalysisError.noActiveProject
        }

        let projectDir = (projectPath as NSString).deletingLastPathComponent

        let swiftFiles = try await findFiles(withExtensions: [".swift"], in: projectDir)
        let objcFiles = try await findFiles(withExtensions: [".m", ".mm", ".h"], in: projectDir)
        let allFiles = swiftFiles + objcFiles

        var totalLines = 0
        var totalCodeLines = 0
        var totalBlankLines = 0
        var totalCommentLines = 0
        var fileSizes: [(path: String, lines: Int)] = []

        for filePath in allFiles {
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            let lineCount = lines.count

            var codeLines = 0
            var blankLines = 0
            var commentLines = 0
            var inBlockComment = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.isEmpty {
                    blankLines += 1
                } else if inBlockComment {
                    commentLines += 1
                    if trimmed.contains("*/") { inBlockComment = false }
                } else if trimmed.hasPrefix("//") {
                    commentLines += 1
                } else if trimmed.hasPrefix("/*") {
                    commentLines += 1
                    if !trimmed.contains("*/") { inBlockComment = true }
                } else {
                    codeLines += 1
                }
            }

            totalLines += lineCount
            totalCodeLines += codeLines
            totalBlankLines += blankLines
            totalCommentLines += commentLines
            fileSizes.append((filePath, lineCount))
        }

        fileSizes.sort { $0.lines > $1.lines }
        let largestFiles = fileSizes.prefix(10).map { file -> LargestFile in
            let name = (file.path as NSString).lastPathComponent
            return LargestFile(name: name, path: file.path, lines: file.lines)
        }

        var languages: [String: Int] = [:]
        languages["Swift"] = swiftFiles.count
        if !objcFiles.isEmpty {
            languages["Objective-C"] = objcFiles.count
        }

        return CodeMetrics(
            totalFiles: allFiles.count,
            totalLines: totalLines,
            codeLines: totalCodeLines,
            blankLines: totalBlankLines,
            commentLines: totalCommentLines,
            languages: languages,
            largestFiles: largestFiles
        )
    }

    /// Gets import dependency graph for the project
    /// - Returns: Array of dependency nodes
    func getDependencyGraph() async throws -> [DependencyNode] {
        guard let projectPath = activeProjectPath else {
            throw ContextAnalysisError.noActiveProject
        }

        let projectDir = (projectPath as NSString).deletingLastPathComponent
        let swiftFiles = try await findFiles(withExtensions: [".swift"], in: projectDir)

        var moduleImports: [String: Set<String>] = [:]  // file -> imports
        var fileNames: [String: String] = [:]  // path -> display name

        for filePath in swiftFiles {
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            let fileName = (filePath as NSString).lastPathComponent
            fileNames[filePath] = fileName

            var imports: Set<String> = []
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("import ") {
                    let module = trimmed.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces)
                    // Skip standard imports for dependency graph
                    if !["Foundation", "SwiftUI", "UIKit", "AppKit", "Combine", "CoreData", "XCTest"].contains(module) {
                        imports.insert(module)
                    }
                }
            }
            moduleImports[fileName] = imports
        }

        // Build dependency nodes
        var nodes: [DependencyNode] = []
        let allFileNames = Set(moduleImports.keys)

        for (fileName, imports) in moduleImports {
            // Find which other project files import this file's module
            let moduleName = fileName.replacingOccurrences(of: ".swift", with: "")
            var importedBy: [String] = []

            for (otherFile, otherImports) in moduleImports where otherFile != fileName {
                // Check if any types defined in this file are referenced
                if otherImports.contains(moduleName) {
                    importedBy.append(otherFile)
                }
            }

            nodes.append(DependencyNode(
                name: fileName,
                imports: Array(imports),
                importedBy: importedBy,
                externalDependencies: imports.filter { !allFileNames.contains($0 + ".swift") }
            ))
        }

        return nodes.sorted { $0.name < $1.name }
    }

    /// Gets framework/package dependencies
    /// - Returns: Array of framework dependency info
    func getFrameworkDependencies() async throws -> [FrameworkDependency] {
        guard let projectPath = activeProjectPath else {
            throw ContextAnalysisError.noActiveProject
        }

        let projectDir = (projectPath as NSString).deletingLastPathComponent
        var dependencies: [FrameworkDependency] = []

        // Check for Swift Package Manager (Package.swift)
        let packageSwiftPath = (projectDir as NSString).appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwiftPath) {
            if let content = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) {
                let packages = parsePackageSwift(content)
                dependencies.append(contentsOf: packages)
            }
        }

        // Check for Package.resolved
        let resolvedPaths = [
            (projectDir as NSString).appendingPathComponent("Package.resolved"),
            (projectPath as NSString).appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        ]

        for resolvedPath in resolvedPaths {
            if FileManager.default.fileExists(atPath: resolvedPath),
               let data = FileManager.default.contents(atPath: resolvedPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let pins = parsePackageResolved(json)
                // Merge with existing
                for pin in pins {
                    if !dependencies.contains(where: { $0.name == pin.name }) {
                        dependencies.append(pin)
                    }
                }
            }
        }

        // Check for CocoaPods (Podfile)
        let podfilePath = (projectDir as NSString).appendingPathComponent("Podfile")
        if FileManager.default.fileExists(atPath: podfilePath) {
            dependencies.append(FrameworkDependency(name: "CocoaPods", version: nil, source: "Podfile", manager: .cocoapods))
        }

        return dependencies
    }

    /// Runs SwiftLint if available
    /// - Returns: Lint results
    func runSwiftLint() async throws -> [LintViolation] {
        guard let projectPath = activeProjectPath else {
            throw ContextAnalysisError.noActiveProject
        }

        let projectDir = (projectPath as NSString).deletingLastPathComponent

        // Find swiftlint
        let swiftlintPaths = ["/opt/homebrew/bin/swiftlint", "/usr/local/bin/swiftlint"]
        guard let swiftlintPath = swiftlintPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return []  // SwiftLint not installed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: swiftlintPath)
        process.arguments = ["lint", "--reporter", "json", "--quiet"]
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonArray = try? JSONSerialization.jsonObject(with: outputData) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { json -> LintViolation? in
            guard let file = json["file"] as? String,
                  let line = json["line"] as? Int,
                  let severity = json["severity"] as? String,
                  let ruleId = json["rule_id"] as? String,
                  let reason = json["reason"] as? String else {
                return nil
            }

            return LintViolation(
                file: (file as NSString).lastPathComponent,
                filePath: file,
                line: line,
                column: json["character"] as? Int,
                severity: severity,
                ruleId: ruleId,
                reason: reason
            )
        }
    }

    /// Estimates cyclomatic complexity for functions in a file
    /// - Parameter filePath: Path to the Swift file
    /// - Returns: Array of function complexity estimates
    func getFileComplexity(filePath: String) async throws -> [FunctionComplexity] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            throw ContextAnalysisError.indexingFailed("Cannot read file: \(filePath)")
        }

        let lines = content.components(separatedBy: .newlines)
        var results: [FunctionComplexity] = []
        var currentFunction: String?
        var functionStartLine = 0
        var braceDepth = 0
        var complexity = 1  // Base complexity

        let complexityKeywords = ["if ", "else if ", "guard ", "for ", "while ", "case ", "catch ", "&&", "||", "?? "]

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect function start
            if let funcMatch = trimmed.range(of: #"func\s+(\w+)"#, options: .regularExpression) {
                if currentFunction != nil {
                    // Save previous function
                    results.append(FunctionComplexity(
                        name: currentFunction!,
                        line: functionStartLine,
                        complexity: complexity
                    ))
                }
                currentFunction = String(trimmed[funcMatch]).replacingOccurrences(of: "func ", with: "")
                functionStartLine = index + 1
                complexity = 1
                braceDepth = 0
            }

            if currentFunction != nil {
                // Count braces
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count

                // Count complexity-adding keywords
                for keyword in complexityKeywords {
                    if trimmed.contains(keyword) {
                        complexity += 1
                    }
                }

                // Function ended
                if braceDepth <= 0 && trimmed.contains("}") {
                    results.append(FunctionComplexity(
                        name: currentFunction!,
                        line: functionStartLine,
                        complexity: complexity
                    ))
                    currentFunction = nil
                }
            }
        }

        // Handle last function
        if let funcName = currentFunction {
            results.append(FunctionComplexity(
                name: funcName,
                line: functionStartLine,
                complexity: complexity
            ))
        }

        return results.sorted { $0.complexity > $1.complexity }
    }

    // MARK: - Private Helpers for Dependencies

    /// Parses Package.swift for dependencies
    private func parsePackageSwift(_ content: String) -> [FrameworkDependency] {
        var deps: [FrameworkDependency] = []

        // Match .package(url: "...", ...)
        let pattern = #"\.package\s*\(\s*url:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return deps }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)

        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match,
                  let urlRange = Range(match.range(at: 1), in: content) else { return }
            let url = String(content[urlRange])
            let name = url.components(separatedBy: "/").last?.replacingOccurrences(of: ".git", with: "") ?? url

            deps.append(FrameworkDependency(name: name, version: nil, source: url, manager: .spm))
        }

        return deps
    }

    /// Parses Package.resolved for pinned versions
    private func parsePackageResolved(_ json: [String: Any]) -> [FrameworkDependency] {
        var deps: [FrameworkDependency] = []

        // v2 format
        if let pins = json["pins"] as? [[String: Any]] {
            for pin in pins {
                let identity = pin["identity"] as? String ?? "unknown"
                let stateDict = pin["state"] as? [String: Any]
                let version = stateDict?["version"] as? String
                let location = pin["location"] as? String

                deps.append(FrameworkDependency(
                    name: identity,
                    version: version,
                    source: location ?? "",
                    manager: .spm
                ))
            }
        }

        // v1 format
        if let object = json["object"] as? [String: Any],
           let pins = object["pins"] as? [[String: Any]] {
            for pin in pins {
                let name = pin["package"] as? String ?? "unknown"
                let stateDict = pin["state"] as? [String: Any]
                let version = stateDict?["version"] as? String
                let repoURL = pin["repositoryURL"] as? String

                deps.append(FrameworkDependency(
                    name: name,
                    version: version,
                    source: repoURL ?? "",
                    manager: .spm
                ))
            }
        }

        return deps
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

        var classes: [AnalysisSymbolInfo] = []
        var structs: [AnalysisSymbolInfo] = []
        var protocols: [AnalysisSymbolInfo] = []
        var functions: [AnalysisSymbolInfo] = []
        var properties: [AnalysisSymbolInfo] = []

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
                        classes.append(AnalysisSymbolInfo(
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
                        structs.append(AnalysisSymbolInfo(
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
                        protocols.append(AnalysisSymbolInfo(
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
                        functions.append(AnalysisSymbolInfo(
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
                        properties.append(AnalysisSymbolInfo(
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
                        classes.append(AnalysisSymbolInfo(
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
                        protocols.append(AnalysisSymbolInfo(
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
                        functions.append(AnalysisSymbolInfo(
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
    let classes: [AnalysisSymbolInfo]
    let structs: [AnalysisSymbolInfo]
    let protocols: [AnalysisSymbolInfo]
    let functions: [AnalysisSymbolInfo]
    let properties: [AnalysisSymbolInfo]
    let fileCount: Int

    var totalSymbols: Int {
        return classes.count + structs.count + protocols.count + functions.count + properties.count
    }
}

/// Information about a symbol
struct AnalysisSymbolInfo: Identifiable {
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
    let classes: [AnalysisSymbolInfo]
    let structs: [AnalysisSymbolInfo]
    let protocols: [AnalysisSymbolInfo]
    let functions: [AnalysisSymbolInfo]
    let properties: [AnalysisSymbolInfo]
}

/// Context for a specific file
struct AnalysisFileContext {
    let filePath: String
    let classes: [AnalysisSymbolInfo]
    let structs: [AnalysisSymbolInfo]
    let protocols: [AnalysisSymbolInfo]
    let functions: [AnalysisSymbolInfo]
    let properties: [AnalysisSymbolInfo]

    var totalSymbols: Int {
        return classes.count + structs.count + protocols.count + functions.count + properties.count
    }
}

// MARK: - Code Metrics Types

/// Code metrics summary for a project
struct CodeMetrics {
    let totalFiles: Int
    let totalLines: Int
    let codeLines: Int
    let blankLines: Int
    let commentLines: Int
    let languages: [String: Int]
    let largestFiles: [LargestFile]

    var commentRatio: Double {
        guard codeLines > 0 else { return 0 }
        return Double(commentLines) / Double(codeLines) * 100
    }
}

/// Info about a large file
struct LargestFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let lines: Int
}

/// Dependency graph node
struct DependencyNode: Identifiable {
    let id = UUID()
    let name: String
    let imports: [String]
    let importedBy: [String]
    let externalDependencies: [String]
}

/// Package manager type
enum PackageManager: String {
    case spm = "Swift Package Manager"
    case cocoapods = "CocoaPods"
    case carthage = "Carthage"
}

/// Framework/package dependency
struct FrameworkDependency: Identifiable {
    let id = UUID()
    let name: String
    let version: String?
    let source: String
    let manager: PackageManager
}

/// SwiftLint violation
struct LintViolation: Identifiable {
    let id = UUID()
    let file: String
    let filePath: String
    let line: Int
    let column: Int?
    let severity: String
    let ruleId: String
    let reason: String

    var isError: Bool { severity == "error" }
    var isWarning: Bool { severity == "warning" }
}

/// Function complexity estimate
struct FunctionComplexity: Identifiable {
    let id = UUID()
    let name: String
    let line: Int
    let complexity: Int

    var rating: String {
        switch complexity {
        case 1...5: return "Low"
        case 6...10: return "Medium"
        case 11...20: return "High"
        default: return "Very High"
        }
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
