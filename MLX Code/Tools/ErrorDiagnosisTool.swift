//
//  ErrorDiagnosisTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for diagnosing and fixing Xcode build errors
class ErrorDiagnosisTool: BaseTool {
    init() {
        super.init(
            name: "error_diagnosis",
            description: """
            Diagnose and suggest fixes for Xcode build errors and warnings.
            Can analyze error messages, suggest solutions, and optionally apply fixes automatically.
            """,
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Operation: analyze_errors, suggest_fix, apply_fix, explain_error",
                        enum: ["analyze_errors", "suggest_fix", "apply_fix", "explain_error"]
                    ),
                    "error_message": ParameterProperty(
                        type: "string",
                        description: "The error message to diagnose (optional if analyzing build output)"
                    ),
                    "file_path": ParameterProperty(
                        type: "string",
                        description: "File path where error occurred (optional)"
                    ),
                    "line_number": ParameterProperty(
                        type: "integer",
                        description: "Line number where error occurred (optional)"
                    ),
                    "auto_fix": ParameterProperty(
                        type: "boolean",
                        description: "Automatically apply suggested fixes (default: false)"
                    ),
                    "build_log": ParameterProperty(
                        type: "string",
                        description: "Full build log to analyze (optional)"
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
        case "analyze_errors":
            return try await analyzeErrors(parameters: parameters, context: context)
        case "suggest_fix":
            return try await suggestFix(parameters: parameters, context: context)
        case "apply_fix":
            return try await applyFix(parameters: parameters, context: context)
        case "explain_error":
            return try await explainError(parameters: parameters, context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func analyzeErrors(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        // Get build log from most recent build
        let workingDir = context.workingDirectory
        let buildLogPath = parameters["build_log"] as? String

        var errors: [BuildError] = []

        if let logPath = buildLogPath {
            // Parse provided build log
            let logContent = try await FileService.shared.read(path: logPath)
            errors = parseBuildErrors(from: logContent)
        } else {
            // Run build and capture errors
            let buildResult = try await runBuild(in: workingDir)
            errors = parseBuildErrors(from: buildResult.output)
        }

        // Categorize errors
        let categorized = categorizeErrors(errors)

        var result = "# Build Error Analysis\n\n"
        result += "**Total Errors**: \(errors.filter { $0.severity == .error }.count)\n"
        result += "**Total Warnings**: \(errors.filter { $0.severity == .warning }.count)\n\n"

        // Group by category
        for (category, categoryErrors) in categorized {
            result += "## \(category.rawValue)\n"
            result += "Count: \(categoryErrors.count)\n\n"

            for error in categoryErrors.prefix(5) {
                result += "### \(error.file ?? "Unknown"):\(error.line ?? 0)\n"
                result += "```\n\(error.message)\n```\n"
                result += "**Likely cause**: \(error.suggestedCause ?? "Unknown")\n\n"
            }

            if categoryErrors.count > 5 {
                result += "*... and \(categoryErrors.count - 5) more*\n\n"
            }
        }

        return .success(result, metadata: [
            "total_errors": errors.filter { $0.severity == .error }.count,
            "total_warnings": errors.filter { $0.severity == .warning }.count,
            "categories": Array(categorized.keys.map { $0.rawValue })
        ])
    }

    private func suggestFix(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let errorMessage = parameters["error_message"] as? String else {
            throw ToolError.missingParameter("Missing error_message parameter")
        }

        let filePath = parameters["file_path"] as? String
        let lineNumber = parameters["line_number"] as? Int

        // Analyze error and suggest fix
        let diagnosis = diagnoseError(message: errorMessage, file: filePath, line: lineNumber)

        var result = "# Error Diagnosis\n\n"
        result += "**Error**: \(errorMessage)\n\n"

        if let file = filePath {
            result += "**File**: \(file)\n"
        }
        if let line = lineNumber {
            result += "**Line**: \(line)\n"
        }

        result += "\n## Diagnosis\n"
        result += "\(diagnosis.explanation)\n\n"

        result += "## Suggested Fix\n"
        result += "```swift\n\(diagnosis.suggestedFix)\n```\n\n"

        result += "## Confidence\n"
        result += "\(Int(diagnosis.confidence * 100))%\n\n"

        if !diagnosis.steps.isEmpty {
            result += "## Steps to Fix\n"
            for (index, step) in diagnosis.steps.enumerated() {
                result += "\(index + 1). \(step)\n"
            }
        }

        return .success(result, metadata: [
            "confidence": diagnosis.confidence,
            "fix_available": true,
            "category": diagnosis.category.rawValue
        ])
    }

    private func applyFix(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let errorMessage = parameters["error_message"] as? String,
              let filePath = parameters["file_path"] as? String,
              let lineNumber = parameters["line_number"] as? Int else {
            throw ToolError.missingParameter("Missing required parameters for apply_fix")
        }

        // Diagnose error
        let diagnosis = diagnoseError(message: errorMessage, file: filePath, line: lineNumber)

        guard diagnosis.confidence > 0.7 else {
            return .failure("Confidence too low to auto-fix (\(Int(diagnosis.confidence * 100))%). Manual review recommended.")
        }

        // Read file
        let fullPath = resolveFilePath(filePath, workingDirectory: context.workingDirectory)
        let content = try await FileService.shared.read(path: fullPath)
        let lines = content.components(separatedBy: .newlines)

        guard lineNumber > 0 && lineNumber <= lines.count else {
            throw ToolError.executionFailed("Invalid line number: \(lineNumber)")
        }

        // Apply fix
        var newLines = lines
        let fixLines = diagnosis.suggestedFix.components(separatedBy: .newlines)

        // Replace the error line with the fix
        newLines.replaceSubrange(lineNumber - 1...lineNumber - 1, with: fixLines)

        // Write back
        let newContent = newLines.joined(separator: "\n")
        try await FileService.shared.write(content: newContent, to: fullPath)

        var result = "# Fix Applied\n\n"
        result += "**File**: \(filePath)\n"
        result += "**Line**: \(lineNumber)\n"
        result += "**Confidence**: \(Int(diagnosis.confidence * 100))%\n\n"
        result += "## Original\n```swift\n\(lines[lineNumber - 1])\n```\n\n"
        result += "## Fixed\n```swift\n\(diagnosis.suggestedFix)\n```\n\n"
        result += "✅ Fix has been applied. Please rebuild to verify.\n"

        return .success(result)
    }

    private func explainError(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let errorMessage = parameters["error_message"] as? String else {
            throw ToolError.missingParameter("Missing error_message parameter")
        }

        let explanation = explainErrorMessage(errorMessage)

        var result = "# Error Explanation\n\n"
        result += "**Error**: \(errorMessage)\n\n"
        result += "## What This Means\n"
        result += "\(explanation.plainEnglish)\n\n"
        result += "## Common Causes\n"
        for (index, cause) in explanation.commonCauses.enumerated() {
            result += "\(index + 1). \(cause)\n"
        }
        result += "\n## How to Fix\n"
        result += "\(explanation.howToFix)\n"

        return .success(result)
    }

    // MARK: - Helper Methods

    private func runBuild(in directory: String) async throws -> (output: String, exitCode: Int) {
        let projectPath = findXcodeProject(in: directory)
        guard let project = projectPath else {
            throw ToolError.executionFailed("No Xcode project found in \(directory)")
        }

        let isWorkspace = project.hasSuffix(".xcworkspace")
        let flag = isWorkspace ? "-workspace" : "-project"

        let buildCommand = """
        cd "\(directory)" && xcodebuild \(flag) "\(project)" -scheme "\(getDefaultScheme(project))" clean build 2>&1
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", buildCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (output, Int(process.terminationStatus))
    }

    private func parseBuildErrors(from output: String) -> [BuildError] {
        var errors: [BuildError] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if let error = parseBuildErrorLine(line) {
                errors.append(error)
            }
        }

        return errors
    }

    private func parseBuildErrorLine(_ line: String) -> BuildError? {
        // Match patterns like:
        // /path/to/file.swift:42:10: error: cannot find 'foo' in scope
        // /path/to/file.swift:42:10: warning: unused variable 'bar'

        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning):\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }

        let file = nsString.substring(with: match.range(at: 1))
        let line = Int(nsString.substring(with: match.range(at: 2))) ?? 0
        let column = Int(nsString.substring(with: match.range(at: 3))) ?? 0
        let severityStr = nsString.substring(with: match.range(at: 4))
        let message = nsString.substring(with: match.range(at: 5))

        let severity: BuildError.Severity = severityStr == "error" ? .error : .warning

        return BuildError(
            file: file,
            line: line,
            column: column,
            severity: severity,
            message: message,
            category: categorizeErrorMessage(message),
            suggestedCause: inferCause(from: message)
        )
    }

    private func categorizeErrors(_ errors: [BuildError]) -> [ErrorCategory: [BuildError]] {
        return Dictionary(grouping: errors) { $0.category }
    }

    private func categorizeErrorMessage(_ message: String) -> ErrorCategory {
        let lowercased = message.lowercased()

        if lowercased.contains("cannot find") || lowercased.contains("undeclared") {
            return .undeclaredIdentifier
        } else if lowercased.contains("type") && (lowercased.contains("mismatch") || lowercased.contains("cannot convert")) {
            return .typeMismatch
        } else if lowercased.contains("property") || lowercased.contains("member") {
            return .missingMember
        } else if lowercased.contains("import") {
            return .importError
        } else if lowercased.contains("retain") || lowercased.contains("cycle") {
            return .memoryIssue
        } else if lowercased.contains("thread") || lowercased.contains("actor") {
            return .concurrency
        } else if lowercased.contains("syntax") {
            return .syntaxError
        } else {
            return .other
        }
    }

    private func inferCause(from message: String) -> String? {
        let lowercased = message.lowercased()

        if lowercased.contains("cannot find") {
            return "Variable, function, or type not declared or imported"
        } else if lowercased.contains("type mismatch") {
            return "Assigning wrong type to variable or passing wrong argument type"
        } else if lowercased.contains("unused") {
            return "Variable declared but never used"
        } else if lowercased.contains("@mainactor") {
            return "Accessing MainActor-isolated property from non-MainActor context"
        }

        return nil
    }

    private func diagnoseError(message: String, file: String?, line: Int?) -> ErrorDiagnosis {
        // Simplified diagnosis logic - in production, this would be much more sophisticated
        let category = categorizeErrorMessage(message)

        var diagnosis = ErrorDiagnosis(
            message: message,
            category: category,
            explanation: "",
            suggestedFix: "",
            confidence: 0.5,
            steps: []
        )

        // Pattern-based diagnosis
        if message.contains("cannot find") && message.contains("in scope") {
            diagnosis.explanation = "The compiler cannot find the specified identifier. This usually means it's not declared, not imported, or misspelled."
            diagnosis.suggestedFix = "// Check spelling and ensure proper import\nimport Foundation"
            diagnosis.confidence = 0.8
            diagnosis.steps = [
                "Check if the identifier is spelled correctly",
                "Ensure the module is imported",
                "Verify the identifier is in scope"
            ]
        } else if message.contains("@MainActor") {
            diagnosis.explanation = "Trying to access a MainActor-isolated property from a non-MainActor context."
            diagnosis.suggestedFix = "Task { @MainActor in\n    // Your code here\n}"
            diagnosis.confidence = 0.85
            diagnosis.steps = [
                "Wrap code in Task { @MainActor in ... }",
                "Or mark the containing function as @MainActor"
            ]
        }

        return diagnosis
    }

    private func explainErrorMessage(_ message: String) -> ErrorExplanation {
        let lowercased = message.lowercased()

        if lowercased.contains("cannot find") {
            return ErrorExplanation(
                plainEnglish: "Swift cannot find a variable, function, or type with that name in the current scope.",
                commonCauses: [
                    "Typo in the identifier name",
                    "Missing import statement",
                    "Identifier is in a different file and not accessible",
                    "Identifier is private and cannot be accessed from outside its module"
                ],
                howToFix: "1. Check spelling\n2. Add necessary import\n3. Ensure identifier is public if needed\n4. Verify identifier exists in your project"
            )
        } else if lowercased.contains("type") && lowercased.contains("mismatch") {
            return ErrorExplanation(
                plainEnglish: "You're trying to use a value of one type where a different type is expected.",
                commonCauses: [
                    "Assigning wrong type to a variable",
                    "Passing wrong type as function argument",
                    "Returning wrong type from function"
                ],
                howToFix: "Convert the value to the expected type, or change the type annotation to match the value's type."
            )
        }

        return ErrorExplanation(
            plainEnglish: "A build error occurred.",
            commonCauses: ["Various causes"],
            howToFix: "Review the error message for specific details."
        )
    }

    private func findXcodeProject(in directory: String) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        // Prefer workspace over project
        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return workspace
        }

        return contents.first(where: { $0.hasSuffix(".xcodeproj") })
    }

    private func getDefaultScheme(_ projectPath: String) -> String {
        // Extract scheme name from project name
        let projectName = (projectPath as NSString).deletingPathExtension
        return projectName
    }

    private func resolveFilePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        } else {
            return (workingDirectory as NSString).appendingPathComponent(path)
        }
    }
}

// MARK: - Supporting Types

struct BuildError {
    enum Severity {
        case error
        case warning
    }

    let file: String?
    let line: Int?
    let column: Int?
    let severity: Severity
    let message: String
    let category: ErrorCategory
    let suggestedCause: String?
}

enum ErrorCategory: String {
    case undeclaredIdentifier = "Undeclared Identifier"
    case typeMismatch = "Type Mismatch"
    case missingMember = "Missing Member"
    case importError = "Import Error"
    case memoryIssue = "Memory Issue"
    case concurrency = "Concurrency Issue"
    case syntaxError = "Syntax Error"
    case other = "Other"
}

struct ErrorDiagnosis {
    let message: String
    let category: ErrorCategory
    var explanation: String
    var suggestedFix: String
    var confidence: Double
    var steps: [String]
}

struct ErrorExplanation {
    let plainEnglish: String
    let commonCauses: [String]
    let howToFix: String
}
