//
//  SmartCodeActions.swift
//  MLX Code
//
//  AI-powered code actions (explain, test, refactor, debug)
//  Created on 2025-12-09
//

import Foundation

/// Smart code analysis and transformation
actor SmartCodeActions {
    static let shared = SmartCodeActions()

    private init() {}

    // MARK: - Code Explanation

    /// Explains code in simple terms
    /// - Parameters:
    ///   - code: Code snippet to explain
    ///   - context: Optional surrounding context
    /// - Returns: Explanation
    func explainCode(_ code: String, context: String? = nil) async throws -> String {
        var prompt = "Explain this code in simple, clear terms:\n\n```\n\(code)\n```\n\n"

        if let context = context {
            prompt += "Context:\n\(context)\n\n"
        }

        prompt += """
        Explain:
        1. What it does
        2. How it works
        3. Key concepts used
        4. Potential issues or improvements
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Test Generation

    /// Generates unit tests for code
    /// - Parameters:
    ///   - code: Code to test
    ///   - language: Programming language
    /// - Returns: Generated test code
    func generateTests(_ code: String, language: String = "swift") async throws -> String {
        let prompt = """
        Generate comprehensive unit tests for this \(language) code:

        ```\(language)
        \(code)
        ```

        Requirements:
        - Test happy path
        - Test edge cases
        - Test error conditions
        - Use XCTest for Swift, pytest for Python
        - Include descriptive test names
        - Add comments explaining what each test validates

        Generate complete, runnable test code.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Code Refactoring

    /// Suggests refactoring improvements
    /// - Parameter code: Code to refactor
    /// - Returns: Refactored code with explanation
    func refactorCode(_ code: String) async throws -> String {
        let prompt = """
        Refactor this code to improve:
        - Readability
        - Performance
        - Maintainability
        - Following best practices

        Original code:
        ```
        \(code)
        ```

        Provide:
        1. Refactored code
        2. Explanation of changes
        3. Why improvements matter
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Bug Detection

    /// Finds potential bugs in code
    /// - Parameter code: Code to analyze
    /// - Returns: List of potential issues
    func findBugs(_ code: String) async throws -> String {
        let prompt = """
        Analyze this code for potential bugs, issues, and improvements:

        ```
        \(code)
        ```

        Check for:
        - Logic errors
        - Memory leaks (for Swift/ObjC: retain cycles, weak references)
        - Thread safety issues
        - Nil/null handling
        - Edge cases
        - Performance bottlenecks
        - Security vulnerabilities

        For each issue, provide:
        1. Line number (if identifiable)
        2. Severity (Critical/High/Medium/Low)
        3. Description
        4. Suggested fix
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Documentation Generation

    /// Generates documentation for code
    /// - Parameter code: Code to document
    /// - Returns: Documentation comments
    func generateDocumentation(_ code: String) async throws -> String {
        let prompt = """
        Generate comprehensive documentation comments for this code:

        ```
        \(code)
        ```

        Include:
        - Summary of what it does
        - Parameter descriptions
        - Return value description
        - Throws documentation (if applicable)
        - Usage examples
        - Important notes

        Use appropriate documentation format (/// for Swift, docstrings for Python).
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Code Optimization

    /// Suggests performance optimizations
    /// - Parameter code: Code to optimize
    /// - Returns: Optimized version with explanation
    func optimizeCode(_ code: String) async throws -> String {
        let prompt = """
        Optimize this code for better performance:

        ```
        \(code)
        ```

        Consider:
        - Algorithm efficiency
        - Memory usage
        - Unnecessary allocations
        - Caching opportunities
        - Lazy evaluation
        - Parallel processing

        Provide optimized code and explain improvements.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Code Completion

    /// Completes partial code intelligently
    /// - Parameters:
    ///   - partialCode: Incomplete code
    ///   - context: Surrounding code context
    /// - Returns: Completed code
    func completeCode(_ partialCode: String, context: String? = nil) async throws -> String {
        var prompt = "Complete this code:\n\n```\n\(partialCode)\n```\n\n"

        if let context = context {
            prompt += "Context:\n```\n\(context)\n```\n\n"
        }

        prompt += "Provide only the completion, maintaining style and patterns from context."

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Code Translation

    /// Translates code between languages
    /// - Parameters:
    ///   - code: Source code
    ///   - fromLanguage: Source language
    ///   - toLanguage: Target language
    /// - Returns: Translated code
    func translateCode(_ code: String, from fromLanguage: String, to toLanguage: String) async throws -> String {
        let prompt = """
        Translate this \(fromLanguage) code to \(toLanguage):

        ```\(fromLanguage)
        \(code)
        ```

        Maintain:
        - Functionality
        - Logic flow
        - Comments (translated)
        - Best practices for target language

        Provide complete, runnable \(toLanguage) code.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Security Analysis

    /// Analyzes code for security vulnerabilities
    /// - Parameter code: Code to analyze
    /// - Returns: Security analysis report
    func analyzeSecurityRisks(_ code: String) async throws -> String {
        let prompt = """
        Perform security analysis on this code:

        ```
        \(code)
        ```

        Check for:
        - SQL injection risks
        - XSS vulnerabilities
        - Command injection
        - Path traversal
        - Insecure data handling
        - Hardcoded secrets
        - Unsafe deserialization
        - Authentication/authorization issues

        For each finding:
        1. Severity (Critical/High/Medium/Low)
        2. Description
        3. Exploit scenario
        4. Remediation steps
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Code Review

    /// Performs comprehensive code review
    /// - Parameter code: Code to review
    /// - Returns: Review feedback
    func reviewCode(_ code: String) async throws -> String {
        let prompt = """
        Perform a thorough code review:

        ```
        \(code)
        ```

        Review for:
        - Code quality and readability
        - Best practices adherence
        - Error handling
        - Edge cases
        - Performance considerations
        - Testing requirements
        - Documentation completeness
        - SOLID principles

        Provide constructive, actionable feedback.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }
}
