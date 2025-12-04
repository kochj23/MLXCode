//
//  CodeNavigationTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for code navigation, symbol search, and reference finding
class CodeNavigationTool: BaseTool {
    init() {
        super.init(
            name: "code_navigation",
            description: """
            Navigate code, find symbols, definitions, and references.
            Search for classes, functions, properties, and their usages across the project.
            """,
            parameters: ToolParameterSchema(
                
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Operation: find_definition, find_references, list_symbols, quick_open, goto_line",
                        enum: ["find_definition", "find_references", "list_symbols", "quick_open", "goto_line"]
                    ),
                    "symbol": ParameterProperty(
                        type: "string",
                        description: "Symbol name to search for"
                    ),
                    "file_pattern": ParameterProperty(
                        type: "string",
                        description: "File pattern for quick_open (e.g., '*ViewModel*.swift')"
                    ),
                    "file_path": ParameterProperty(
                        type: "string",
                        description: "File path for symbol search"
                    ),
                    "symbol_type": ParameterProperty(
                        type: "string",
                        description: "Type of symbol: class, func, var, protocol, enum",
                        enum: ["class", "func", "var", "protocol", "enum", "all"]
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("Missing required parameter: operation")
        }

        switch operation {
        case "find_definition":
            return try await findDefinition(parameters: parameters, context: context)
        case "find_references":
            return try await findReferences(parameters: parameters, context: context)
        case "list_symbols":
            return try await listSymbols(parameters: parameters, context: context)
        case "quick_open":
            return try await quickOpen(parameters: parameters, context: context)
        case "goto_line":
            return try await gotoLine(parameters: parameters, context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func findDefinition(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let symbol = parameters["symbol"] as? String else {
            throw ToolError.missingParameter("Missing symbol parameter")
        }

        let workingDir = context.workingDirectory

        // Search for class/struct/func definition
        let patterns = [
            "class \\(symbol)",
            "struct \\(symbol)",
            "func \\(symbol)",
            "protocol \\(symbol)",
            "enum \\(symbol)"
        ]

        var results: [SymbolDefinition] = []

        for pattern in patterns {
            let grepCommand = "cd \"\(workingDir)\" && grep -rn '\(pattern)' --include='*.swift' --include='*.m' --include='*.h' 2>/dev/null || true"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", grepCommand]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            results.append(contentsOf: parseGrepOutput(output))
        }

        guard !results.isEmpty else {
            return .failure("Definition not found for symbol: \(symbol)")
        }

        var result = "# Definition Found\n\n"
        result += "**Symbol**: \(symbol)\n\n"

        for def in results {
            result += "## \(def.file):\(def.line)\n"
            result += "```swift\n\(def.content)\n```\n\n"
        }

        return .success(result, metadata: [
            "symbol": symbol,
            "locations": results.count
        ])
    }

    private func findReferences(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let symbol = parameters["symbol"] as? String else {
            throw ToolError.missingParameter("Missing symbol parameter")
        }

        let workingDir = context.workingDirectory

        // Search for all usages
        let grepCommand = "cd \"\(workingDir)\" && grep -rn '\\b\(symbol)\\b' --include='*.swift' --include='*.m' --include='*.h' 2>/dev/null || true"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", grepCommand]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let results = parseGrepOutput(output)

        var result = "# References Found\n\n"
        result += "**Symbol**: \(symbol)\n"
        result += "**Total**: \(results.count) reference(s)\n\n"

        for ref in results {
            result += "- \(ref.file):\(ref.line) - `\(ref.content.trimmingCharacters(in: .whitespacesAndNewlines))`\n"
        }

        return .success(result, metadata: [
            "symbol": symbol,
            "references": results.count
        ])
    }

    private func listSymbols(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let symbolType = parameters["symbol_type"] as? String ?? "all"
        let filePath = parameters["file_path"] as? String
        let workingDir = context.workingDirectory

        let searchPath = filePath ?? workingDir

        var symbols: [SymbolInfo] = []

        // Search for different symbol types
        if symbolType == "class" || symbolType == "all" {
            symbols.append(contentsOf: try await findSymbolsOfType("class", in: searchPath))
        }
        if symbolType == "func" || symbolType == "all" {
            symbols.append(contentsOf: try await findSymbolsOfType("func", in: searchPath))
        }
        if symbolType == "protocol" || symbolType == "all" {
            symbols.append(contentsOf: try await findSymbolsOfType("protocol", in: searchPath))
        }

        var result = "# Symbols Found\n\n"
        result += "**Type**: \(symbolType)\n"
        result += "**Total**: \(symbols.count)\n\n"

        let grouped = Dictionary(grouping: symbols) { $0.type }

        for (type, typeSymbols) in grouped.sorted(by: { $0.key < $1.key }) {
            result += "## \(type.capitalized)\n"
            for symbol in typeSymbols.sorted(by: { $0.name < $1.name }) {
                result += "- **\(symbol.name)** (\(symbol.file):\(symbol.line))\n"
            }
            result += "\n"
        }

        return .success(result, metadata: [
            "total_symbols": symbols.count
        ])
    }

    private func quickOpen(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filePattern = parameters["file_pattern"] as? String else {
            throw ToolError.missingParameter("Missing file_pattern parameter")
        }

        let workingDir = context.workingDirectory

        // Use find command to search for files
        let findCommand = "cd \"\(workingDir)\" && find . -name '\(filePattern)' -type f | head -50"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", findCommand]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var result = "# Quick Open Results\n\n"
        result += "**Pattern**: \(filePattern)\n"
        result += "**Matches**: \(files.count)\n\n"

        for file in files {
            result += "- \(file)\n"
        }

        return .success(result, metadata: [
            "matches": files.count,
            "files": files
        ])
    }

    private func gotoLine(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] as? String else {
            throw ToolError.missingParameter("Missing file_path parameter")
        }

        guard let lineNumber = parameters["line_number"] as? Int else {
            throw ToolError.missingParameter("Missing line_number parameter")
        }

        let fullPath = resolveFilePath(filePath, workingDirectory: context.workingDirectory)
        let content = try await FileService.shared.read(path: fullPath)
        let lines = content.components(separatedBy: .newlines)

        guard lineNumber > 0 && lineNumber <= lines.count else {
            throw ToolError.executionFailed("Line number out of range: \(lineNumber)")
        }

        // Get context around the line
        let start = max(0, lineNumber - 6)
        let end = min(lines.count, lineNumber + 5)
        let contextLines = Array(lines[start..<end])

        var result = "# Line Context\n\n"
        result += "**File**: \(filePath)\n"
        result += "**Line**: \(lineNumber)\n\n"
        result += "```swift\n"

        for (offset, line) in contextLines.enumerated() {
            let currentLine = start + offset + 1
            let marker = currentLine == lineNumber ? "→ " : "  "
            result += "\(String(format: "%4d", currentLine))\(marker)\(line)\n"
        }

        result += "```\n"

        return .success(result)
    }

    // MARK: - Helper Methods

    private func findSymbolsOfType(_ type: String, in path: String) async throws -> [SymbolInfo] {
        let grepCommand = "grep -rn '^\\s*\(type) ' '\(path)' --include='*.swift' 2>/dev/null || true"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", grepCommand]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return parseSymbolsFromGrep(output, type: type)
    }

    private func parseGrepOutput(_ output: String) -> [SymbolDefinition] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var results: [SymbolDefinition] = []

        for line in lines {
            let components = line.components(separatedBy: ":")
            guard components.count >= 3 else { continue }

            let file = components[0]
            let lineNum = Int(components[1]) ?? 0
            let content = components[2...].joined(separator: ":")

            results.append(SymbolDefinition(
                file: file,
                line: lineNum,
                content: content
            ))
        }

        return results
    }

    private func parseSymbolsFromGrep(_ output: String, type: String) -> [SymbolInfo] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var results: [SymbolInfo] = []

        for line in lines {
            let components = line.components(separatedBy: ":")
            guard components.count >= 3 else { continue }

            let file = components[0]
            let lineNum = Int(components[1]) ?? 0
            let content = components[2...].joined(separator: ":")

            // Extract symbol name
            if let name = extractSymbolName(from: content, type: type) {
                results.append(SymbolInfo(
                    name: name,
                    type: type,
                    file: file,
                    line: lineNum
                ))
            }
        }

        return results
    }

    private func extractSymbolName(from line: String, type: String) -> String? {
        let pattern = "\(type)\\s+(\\w+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            let nsString = line as NSString
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }

    private func resolveFilePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return (workingDirectory as NSString).appendingPathComponent(path)
    }
}

// MARK: - Supporting Types

struct SymbolDefinition {
    let file: String
    let line: Int
    let content: String
}

struct SymbolInfo {
    let name: String
    let type: String
    let file: String
    let line: Int
}
