//
//  BuildErrorParser.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Parses xcodebuild output and extracts errors, warnings, and notes
/// Provides categorization and suggestions for common issues
struct BuildErrorParser {
    /// Parses xcodebuild output
    /// - Parameter output: Raw xcodebuild output
    /// - Returns: Array of build issues
    static func parse(_ output: String) -> [BuildIssue] {
        var issues: [BuildIssue] = []
        let lines = output.components(separatedBy: .newlines)

        var currentIssue: BuildIssue?
        var lineIndex = 0

        for line in lines {
            lineIndex += 1

            // Parse error lines
            if let issue = parseErrorLine(line) {
                if let existing = currentIssue {
                    issues.append(existing)
                }
                currentIssue = issue
            }
            // Parse warning lines
            else if let issue = parseWarningLine(line) {
                if let existing = currentIssue {
                    issues.append(existing)
                }
                currentIssue = issue
            }
            // Parse note lines (usually follow errors/warnings)
            else if let note = parseNoteLine(line) {
                if var existing = currentIssue {
                    existing.notes.append(note)
                    currentIssue = existing
                } else {
                    issues.append(note)
                }
            }
            // Check if this is a continuation of the previous issue
            else if currentIssue != nil && !line.isEmpty && line.hasPrefix(" ") {
                // This is additional context for the current issue
                currentIssue?.message += "\n" + line.trimmingCharacters(in: .whitespaces)
            }
            // If we encounter a non-continuation line, save current issue
            else if let existing = currentIssue {
                issues.append(existing)
                currentIssue = nil
            }
        }

        // Add final issue if exists
        if let existing = currentIssue {
            issues.append(existing)
        }

        // Add suggestions for common issues
        return issues.map { issue in
            var enhancedIssue = issue
            enhancedIssue.suggestion = suggestFix(for: issue)
            return enhancedIssue
        }
    }

    /// Parses a single error line
    /// - Parameter line: Line to parse
    /// - Returns: BuildIssue if line contains an error
    private static func parseErrorLine(_ line: String) -> BuildIssue? {
        // Swift/Objective-C error format:
        // /path/to/file.swift:10:5: error: message here
        let errorPattern = #"^(.+?):(\d+):(\d+):\s*error:\s*(.+)$"#

        if let regex = try? NSRegularExpression(pattern: errorPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let filePath = extractString(from: line, match: match, group: 1)
            let lineNumber = extractInt(from: line, match: match, group: 2)
            let column = extractInt(from: line, match: match, group: 3)
            let message = extractString(from: line, match: match, group: 4)

            return BuildIssue(
                id: UUID(),
                severity: .error,
                filePath: filePath,
                line: lineNumber,
                column: column,
                message: message,
                notes: [],
                suggestion: nil
            )
        }

        // Linker error format (no file location)
        // ld: error: message here
        if line.contains("error:") && !line.contains(":") {
            let components = line.components(separatedBy: "error:")
            if components.count >= 2 {
                return BuildIssue(
                    id: UUID(),
                    severity: .error,
                    filePath: nil,
                    line: nil,
                    column: nil,
                    message: components[1].trimmingCharacters(in: .whitespaces),
                    notes: [],
                    suggestion: nil
                )
            }
        }

        return nil
    }

    /// Parses a single warning line
    /// - Parameter line: Line to parse
    /// - Returns: BuildIssue if line contains a warning
    private static func parseWarningLine(_ line: String) -> BuildIssue? {
        // Swift/Objective-C warning format:
        // /path/to/file.swift:10:5: warning: message here
        let warningPattern = #"^(.+?):(\d+):(\d+):\s*warning:\s*(.+)$"#

        if let regex = try? NSRegularExpression(pattern: warningPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let filePath = extractString(from: line, match: match, group: 1)
            let lineNumber = extractInt(from: line, match: match, group: 2)
            let column = extractInt(from: line, match: match, group: 3)
            let message = extractString(from: line, match: match, group: 4)

            return BuildIssue(
                id: UUID(),
                severity: .warning,
                filePath: filePath,
                line: lineNumber,
                column: column,
                message: message,
                notes: [],
                suggestion: nil
            )
        }

        return nil
    }

    /// Parses a single note line
    /// - Parameter line: Line to parse
    /// - Returns: BuildIssue if line contains a note
    private static func parseNoteLine(_ line: String) -> BuildIssue? {
        // Swift/Objective-C note format:
        // /path/to/file.swift:10:5: note: message here
        let notePattern = #"^(.+?):(\d+):(\d+):\s*note:\s*(.+)$"#

        if let regex = try? NSRegularExpression(pattern: notePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let filePath = extractString(from: line, match: match, group: 1)
            let lineNumber = extractInt(from: line, match: match, group: 2)
            let column = extractInt(from: line, match: match, group: 3)
            let message = extractString(from: line, match: match, group: 4)

            return BuildIssue(
                id: UUID(),
                severity: .note,
                filePath: filePath,
                line: lineNumber,
                column: column,
                message: message,
                notes: [],
                suggestion: nil
            )
        }

        return nil
    }

    /// Suggests a fix for a build issue
    /// - Parameter issue: The build issue
    /// - Returns: Suggestion text or nil
    private static func suggestFix(for issue: BuildIssue) -> String? {
        let message = issue.message.lowercased()

        // Common Swift errors
        if message.contains("cannot find") && message.contains("in scope") {
            return "Check if the identifier is imported, spelled correctly, or needs to be declared."
        }

        if message.contains("use of unresolved identifier") {
            return "The identifier is not declared. Check spelling, imports, and access levels."
        }

        if message.contains("type") && message.contains("does not conform to protocol") {
            return "Implement the required protocol methods or use a type extension."
        }

        if message.contains("ambiguous use of") {
            return "Add explicit type annotations or qualify the identifier with its module name."
        }

        if message.contains("cannot convert value of type") {
            return "Cast the value to the expected type or create a conversion method."
        }

        if message.contains("missing return") {
            return "Add a return statement with the expected type."
        }

        if message.contains("immutable value") && (message.contains("let") || message.contains("change")) {
            return "Change 'let' to 'var' to make the value mutable."
        }

        if message.contains("value of optional type") && message.contains("must be unwrapped") {
            return "Use optional binding (if let), force unwrapping (!), or nil coalescing (??)."
        }

        if message.contains("self") && message.contains("closure") {
            return "Use [weak self] or [unowned self] to prevent retain cycles."
        }

        // Memory management issues
        if message.contains("retain cycle") || message.contains("strong reference cycle") {
            return "Use [weak self] in closures or make delegate properties weak."
        }

        // Common Objective-C errors
        if message.contains("use of undeclared identifier") {
            return "Check if the header is imported or the identifier is declared."
        }

        if message.contains("property") && message.contains("not found") {
            return "Check if the property is declared in the class interface or category."
        }

        if message.contains("no visible @interface") {
            return "Import the header file or forward declare the class."
        }

        // Linker errors
        if message.contains("undefined symbol") || message.contains("undefined reference") {
            return "Check if the framework is linked or the symbol is exported."
        }

        if message.contains("duplicate symbol") {
            return "Remove duplicate implementations or check for multiple inclusions."
        }

        // Build configuration issues
        if message.contains("no such module") {
            return "Check if the module is added to the project and target dependencies."
        }

        if message.contains("framework not found") {
            return "Add the framework to the project's Link Binary With Libraries build phase."
        }

        // Swift specific warnings
        if message.contains("variable") && message.contains("never used") {
            return "Remove the unused variable or prefix it with '_' to indicate it's intentionally unused."
        }

        if message.contains("result of") && message.contains("is unused") {
            return "Use the result, assign it to '_', or add @discardableResult to the function."
        }

        if message.contains("expression of type") && message.contains("unused") {
            return "Assign the result to a variable or use '@discardableResult'."
        }

        return nil
    }

    // MARK: - Helper Methods

    /// Extracts a string from a regex match
    /// - Parameters:
    ///   - string: Source string
    ///   - match: Regex match
    ///   - group: Capture group index
    /// - Returns: Extracted string
    private static func extractString(from string: String, match: NSTextCheckingResult, group: Int) -> String {
        guard let range = Range(match.range(at: group), in: string) else {
            return ""
        }
        return String(string[range])
    }

    /// Extracts an integer from a regex match
    /// - Parameters:
    ///   - string: Source string
    ///   - match: Regex match
    ///   - group: Capture group index
    /// - Returns: Extracted integer or nil
    private static func extractInt(from string: String, match: NSTextCheckingResult, group: Int) -> Int? {
        let str = extractString(from: string, match: match, group: group)
        return Int(str)
    }

    /// Categorizes errors by type
    /// - Parameter issues: Array of build issues
    /// - Returns: Dictionary categorized by error type
    static func categorize(_ issues: [BuildIssue]) -> [BuildIssueCategory: [BuildIssue]] {
        var categorized: [BuildIssueCategory: [BuildIssue]] = [:]

        for issue in issues {
            let category = categorizeIssue(issue)
            if categorized[category] == nil {
                categorized[category] = []
            }
            categorized[category]?.append(issue)
        }

        return categorized
    }

    /// Categorizes a single issue
    /// - Parameter issue: Build issue to categorize
    /// - Returns: Issue category
    private static func categorizeIssue(_ issue: BuildIssue) -> BuildIssueCategory {
        let message = issue.message.lowercased()

        if message.contains("undefined symbol") || message.contains("linker") || message.contains("ld:") {
            return .linker
        }

        if message.contains("syntax") || message.contains("expected") {
            return .syntax
        }

        if message.contains("type") || message.contains("cannot convert") {
            return .type
        }

        if message.contains("retain cycle") || message.contains("weak") || message.contains("memory") {
            return .memory
        }

        if message.contains("unused") || message.contains("never") {
            return .unused
        }

        if message.contains("deprecated") {
            return .deprecation
        }

        return .other
    }

    /// Generates a summary of build issues
    /// - Parameter issues: Array of build issues
    /// - Returns: Summary text
    static func generateSummary(_ issues: [BuildIssue]) -> String {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let noteCount = issues.filter { $0.severity == .note }.count

        var summary = ""

        if errorCount > 0 {
            summary += "⛔ \(errorCount) error\(errorCount == 1 ? "" : "s")"
        }

        if warningCount > 0 {
            if !summary.isEmpty { summary += ", " }
            summary += "⚠️ \(warningCount) warning\(warningCount == 1 ? "" : "s")"
        }

        if noteCount > 0 {
            if !summary.isEmpty { summary += ", " }
            summary += "ℹ️ \(noteCount) note\(noteCount == 1 ? "" : "s")"
        }

        if summary.isEmpty {
            summary = "✅ Build succeeded with no issues"
        }

        return summary
    }
}

// MARK: - Data Structures

/// Represents a build issue (error, warning, or note)
struct BuildIssue: Identifiable, Codable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Severity level
    let severity: BuildIssueSeverity

    /// File path where issue occurred
    let filePath: String?

    /// Line number
    let line: Int?

    /// Column number
    let column: Int?

    /// Error/warning message
    var message: String

    /// Additional notes
    var notes: [BuildIssue]

    /// Suggested fix
    var suggestion: String?

    /// Short file name
    var fileName: String? {
        guard let path = filePath else { return nil }
        return (path as NSString).lastPathComponent
    }

    /// Location string (file:line:column)
    var location: String {
        var parts: [String] = []

        if let file = fileName {
            parts.append(file)
        }

        if let line = line {
            parts.append(String(line))
        }

        if let column = column {
            parts.append(String(column))
        }

        return parts.joined(separator: ":")
    }

    /// Severity icon
    var icon: String {
        switch severity {
        case .error:
            return "⛔"
        case .warning:
            return "⚠️"
        case .note:
            return "ℹ️"
        }
    }

    static func == (lhs: BuildIssue, rhs: BuildIssue) -> Bool {
        lhs.id == rhs.id
    }
}

/// Build issue severity levels
enum BuildIssueSeverity: String, Codable, CaseIterable {
    case error
    case warning
    case note

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .error:
            return "red"
        case .warning:
            return "orange"
        case .note:
            return "blue"
        }
    }
}

/// Build issue categories
enum BuildIssueCategory: String, CaseIterable {
    case linker = "Linker Errors"
    case syntax = "Syntax Errors"
    case type = "Type Errors"
    case memory = "Memory Issues"
    case unused = "Unused Code"
    case deprecation = "Deprecations"
    case other = "Other Issues"
}

// MARK: - Extensions

extension Array where Element == BuildIssue {
    /// Filters issues by severity
    /// - Parameter severity: Severity to filter
    /// - Returns: Filtered array
    func filter(by severity: BuildIssueSeverity) -> [BuildIssue] {
        filter { $0.severity == severity }
    }

    /// Filters issues by file
    /// - Parameter file: File path to filter
    /// - Returns: Filtered array
    func filter(byFile file: String) -> [BuildIssue] {
        filter { $0.filePath == file }
    }

    /// Groups issues by file
    /// - Returns: Dictionary grouped by file path
    func groupedByFile() -> [String: [BuildIssue]] {
        var grouped: [String: [BuildIssue]] = [:]

        for issue in self {
            let key = issue.filePath ?? "Unknown"
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(issue)
        }

        return grouped
    }

    /// Gets error count
    var errorCount: Int {
        filter(by: .error).count
    }

    /// Gets warning count
    var warningCount: Int {
        filter(by: .warning).count
    }

    /// Gets note count
    var noteCount: Int {
        filter(by: .note).count
    }

    /// Whether array contains errors
    var hasErrors: Bool {
        errorCount > 0
    }

    /// Whether array contains warnings
    var hasWarnings: Bool {
        warningCount > 0
    }
}
