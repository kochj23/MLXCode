//
//  CodeAnalysisTool.swift
//  MLX Code
//
//  LLM tool for code analysis, metrics, and quality checks
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Tool for code analysis operations (metrics, dependencies, lint, complexity)
class CodeAnalysisTool: BaseTool {

    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "Analysis operation to perform",
                    enum: [
                        "metrics", "dependencies", "framework_deps",
                        "lint", "complexity", "full_analysis"
                    ]
                ),
                "file_path": ParameterProperty(
                    type: "string",
                    description: "Path to a specific file (for complexity analysis)"
                ),
                "project_path": ParameterProperty(
                    type: "string",
                    description: "Path to project directory (auto-detected if not set)"
                )
            ],
            required: ["operation"]
        )

        super.init(
            name: "code_analysis",
            description: "Code analysis: metrics, dependency graphs, SwiftLint, complexity analysis",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        try validateParameters(parameters, required: ["operation"])

        let operationStr = try stringParameter(parameters, key: "operation")

        // Ensure project is set for analysis
        if let projectPath = try? stringParameter(parameters, key: "project_path") {
            await ContextAnalysisService.shared.setActiveProject(projectPath)
        } else if let contextPath = context.projectPath {
            await ContextAnalysisService.shared.setActiveProject(contextPath)
        } else {
            _ = try await ContextAnalysisService.shared.detectActiveProject(from: context.workingDirectory)
        }

        switch operationStr {
        case "metrics":
            return try await codeMetrics()

        case "dependencies":
            return try await dependencyGraph()

        case "framework_deps":
            return try await frameworkDependencies()

        case "lint":
            return try await lintResults()

        case "complexity":
            let filePath = try? stringParameter(parameters, key: "file_path")
            return try await complexityAnalysis(filePath: filePath, context: context)

        case "full_analysis":
            return try await fullAnalysis(context: context)

        default:
            return .failure("Unknown analysis operation: \(operationStr)")
        }
    }

    // MARK: - Operation Implementations

    private func codeMetrics() async throws -> ToolResult {
        let metrics = try await ContextAnalysisService.shared.getCodeMetrics()

        var output = """
        Code Metrics:
          Total Files: \(metrics.totalFiles)
          Total Lines: \(metrics.totalLines)
          Code Lines: \(metrics.codeLines)
          Comment Lines: \(metrics.commentLines) (\(String(format: "%.1f", metrics.commentRatio))% ratio)
          Blank Lines: \(metrics.blankLines)

        Languages:
        """

        for (lang, count) in metrics.languages.sorted(by: { $0.value > $1.value }) {
            output += "\n  \(lang): \(count) files"
        }

        if !metrics.largestFiles.isEmpty {
            output += "\n\nLargest Files:"
            for file in metrics.largestFiles.prefix(10) {
                output += "\n  \(file.name): \(file.lines) lines"
            }
        }

        return .success(output, metadata: [
            "total_files": metrics.totalFiles,
            "total_lines": metrics.totalLines,
            "code_lines": metrics.codeLines
        ])
    }

    private func dependencyGraph() async throws -> ToolResult {
        let nodes = try await ContextAnalysisService.shared.getDependencyGraph()

        if nodes.isEmpty {
            return .success("No internal dependencies found.")
        }

        var output = "Dependency Graph (\(nodes.count) files):\n"

        // Show files with most external dependencies first
        let sorted = nodes.sorted { $0.externalDependencies.count > $1.externalDependencies.count }

        for node in sorted.prefix(30) {
            if !node.externalDependencies.isEmpty {
                output += "\n  \(node.name):"
                output += "\n    External: \(node.externalDependencies.joined(separator: ", "))"
            }
        }

        return .success(output, metadata: ["file_count": nodes.count])
    }

    private func frameworkDependencies() async throws -> ToolResult {
        let deps = try await ContextAnalysisService.shared.getFrameworkDependencies()

        if deps.isEmpty {
            return .success("No external framework dependencies found.")
        }

        var output = "Framework Dependencies (\(deps.count)):\n"

        for dep in deps {
            let version = dep.version.map { " v\($0)" } ?? ""
            output += "  \(dep.name)\(version) [\(dep.manager.rawValue)]\n"
        }

        return .success(output, metadata: ["count": deps.count])
    }

    private func lintResults() async throws -> ToolResult {
        let violations = try await ContextAnalysisService.shared.runSwiftLint()

        if violations.isEmpty {
            return .success("SwiftLint: No violations found (or SwiftLint not installed).")
        }

        let errors = violations.filter { $0.isError }
        let warnings = violations.filter { $0.isWarning }

        var output = "SwiftLint Results: \(errors.count) errors, \(warnings.count) warnings\n"

        // Show errors first
        if !errors.isEmpty {
            output += "\nErrors:\n"
            for v in errors.prefix(20) {
                output += "  \(v.file):\(v.line) [\(v.ruleId)] \(v.reason)\n"
            }
        }

        if !warnings.isEmpty {
            output += "\nWarnings:\n"
            for v in warnings.prefix(20) {
                output += "  \(v.file):\(v.line) [\(v.ruleId)] \(v.reason)\n"
            }
        }

        if violations.count > 40 {
            output += "\n... and \(violations.count - 40) more"
        }

        return .success(output, metadata: [
            "errors": errors.count,
            "warnings": warnings.count,
            "total": violations.count
        ])
    }

    private func complexityAnalysis(filePath: String?, context: ToolContext) async throws -> ToolResult {
        if let path = filePath {
            let resolvedPath = path.hasPrefix("/") ? path : (context.workingDirectory as NSString).appendingPathComponent(path)
            let results = try await ContextAnalysisService.shared.getFileComplexity(filePath: resolvedPath)

            if results.isEmpty {
                return .success("No functions found in \(path)")
            }

            var output = "Complexity Analysis for \((path as NSString).lastPathComponent):\n"
            for func_ in results {
                output += "  \(func_.name) (line \(func_.line)): \(func_.complexity) [\(func_.rating)]\n"
            }

            let avgComplexity = Double(results.map(\.complexity).reduce(0, +)) / Double(results.count)
            output += "\nAverage complexity: \(String(format: "%.1f", avgComplexity))"

            return .success(output, metadata: [
                "function_count": results.count,
                "avg_complexity": avgComplexity
            ])
        } else {
            return .failure("file_path is required for complexity analysis")
        }
    }

    private func fullAnalysis(context: ToolContext) async throws -> ToolResult {
        var sections: [String] = ["Full Project Analysis\n" + String(repeating: "=", count: 40)]

        // Metrics
        if let metrics = try? await ContextAnalysisService.shared.getCodeMetrics() {
            sections.append("""

            Code Metrics:
              Files: \(metrics.totalFiles) | Lines: \(metrics.totalLines) | Code: \(metrics.codeLines)
              Comments: \(metrics.commentLines) (\(String(format: "%.1f", metrics.commentRatio))%)
            """)
        }

        // Framework dependencies
        if let deps = try? await ContextAnalysisService.shared.getFrameworkDependencies(), !deps.isEmpty {
            sections.append("\nDependencies (\(deps.count)):")
            for dep in deps {
                let v = dep.version.map { " v\($0)" } ?? ""
                sections.append("  \(dep.name)\(v)")
            }
        }

        // Lint
        if let violations = try? await ContextAnalysisService.shared.runSwiftLint(), !violations.isEmpty {
            let errors = violations.filter { $0.isError }.count
            let warnings = violations.filter { $0.isWarning }.count
            sections.append("\nSwiftLint: \(errors) errors, \(warnings) warnings")
        }

        // Symbol index summary
        if let index = try? await ContextAnalysisService.shared.indexProject() {
            sections.append("""

            Symbol Index:
              Classes: \(index.classes.count) | Structs: \(index.structs.count)
              Protocols: \(index.protocols.count) | Functions: \(index.functions.count)
              Total Symbols: \(index.totalSymbols)
            """)
        }

        return .success(sections.joined(separator: "\n"))
    }
}
