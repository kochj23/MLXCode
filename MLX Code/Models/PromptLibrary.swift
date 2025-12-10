//
//  PromptLibrary.swift
//  MLX Code
//
//  Library of reusable prompt templates
//  Created on 2025-12-09
//

import Foundation

/// Library of prompt templates
struct PromptLibrary {
    static let shared = PromptLibrary()

    /// All available prompts
    let prompts: [PromptTemplate]

    private init() {
        self.prompts = Self.defaultPrompts
    }

    private static var defaultPrompts: [PromptTemplate] {
        [
            // Code Quality
            PromptTemplate(
                name: "Code Review",
                category: .codeQuality,
                template: """
                Review this code for:
                - Best practices
                - Potential bugs
                - Performance issues
                - Security vulnerabilities
                - Memory leaks (Swift/ObjC)

                {CODE}

                Provide specific, actionable feedback.
                """,
                variables: ["CODE"],
                icon: "eye"
            ),

            PromptTemplate(
                name: "Refactor for Readability",
                category: .codeQuality,
                template: """
                Refactor this code to improve readability:

                {CODE}

                Focus on:
                - Clear variable names
                - Logical structure
                - Reduced complexity
                - Better comments

                Provide refactored code with explanation.
                """,
                variables: ["CODE"],
                icon: "arrow.triangle.2.circlepath"
            ),

            // Testing
            PromptTemplate(
                name: "Generate Unit Tests",
                category: .testing,
                template: """
                Generate comprehensive unit tests for this code:

                {CODE}

                Include:
                - Happy path tests
                - Edge cases
                - Error conditions
                - Descriptive test names

                Use XCTest for Swift, pytest for Python.
                """,
                variables: ["CODE"],
                icon: "checkmark.square"
            ),

            PromptTemplate(
                name: "Test Coverage Analysis",
                category: .testing,
                template: """
                Analyze test coverage for this code:

                Code:
                {CODE}

                Tests:
                {TESTS}

                Identify:
                - Untested code paths
                - Missing edge cases
                - Suggested additional tests
                """,
                variables: ["CODE", "TESTS"],
                icon: "chart.bar"
            ),

            // Documentation
            PromptTemplate(
                name: "Generate Documentation",
                category: .documentation,
                template: """
                Generate comprehensive documentation for:

                {CODE}

                Include:
                - Purpose and overview
                - Parameters/arguments
                - Return values
                - Usage examples
                - Important notes

                Use appropriate doc comment format (/// for Swift, docstrings for Python).
                """,
                variables: ["CODE"],
                icon: "doc.text"
            ),

            PromptTemplate(
                name: "Explain Code",
                category: .documentation,
                template: """
                Explain this code in simple, clear terms:

                {CODE}

                Cover:
                1. What it does
                2. How it works
                3. Key concepts
                4. Potential improvements
                """,
                variables: ["CODE"],
                icon: "text.bubble"
            ),

            // Git
            PromptTemplate(
                name: "Commit Message",
                category: .git,
                template: """
                Generate a commit message for these changes:

                {DIFF}

                Follow conventional commits format:
                <type>: <subject>

                <optional body>

                Types: feat, fix, docs, style, refactor, test, chore
                """,
                variables: ["DIFF"],
                icon: "arrow.up.doc"
            ),

            PromptTemplate(
                name: "PR Description",
                category: .git,
                template: """
                Generate a pull request description:

                Commits:
                {COMMITS}

                Diff:
                {DIFF}

                Include:
                ## Summary
                - Key changes

                ## Testing
                - How to test

                ## Notes
                - Important details
                """,
                variables: ["COMMITS", "DIFF"],
                icon: "arrow.triangle.branch"
            ),

            // Architecture
            PromptTemplate(
                name: "Design Pattern Suggestion",
                category: .architecture,
                template: """
                Suggest appropriate design patterns for:

                {DESCRIPTION}

                Current code:
                {CODE}

                Recommend:
                - Applicable patterns (MVC, MVVM, etc.)
                - Implementation approach
                - Trade-offs
                - Example code
                """,
                variables: ["DESCRIPTION", "CODE"],
                icon: "building.2"
            ),

            PromptTemplate(
                name: "Architecture Review",
                category: .architecture,
                template: """
                Review the architecture of this system:

                {DESCRIPTION}

                Files:
                {FILES}

                Evaluate:
                - Separation of concerns
                - Scalability
                - Maintainability
                - Testability
                - Suggested improvements
                """,
                variables: ["DESCRIPTION", "FILES"],
                icon: "square.stack.3d.up"
            ),

            // Debugging
            PromptTemplate(
                name: "Debug Error",
                category: .debugging,
                template: """
                Help debug this error:

                Error: {ERROR}

                Code:
                {CODE}

                Provide:
                1. Likely cause
                2. How to fix
                3. How to prevent in future
                4. Alternative approaches
                """,
                variables: ["ERROR", "CODE"],
                icon: "ant"
            ),

            PromptTemplate(
                name: "Performance Analysis",
                category: .debugging,
                template: """
                Analyze performance of this code:

                {CODE}

                Identify:
                - Bottlenecks
                - Unnecessary operations
                - Memory issues
                - Optimization opportunities

                Provide concrete improvements with code examples.
                """,
                variables: ["CODE"],
                icon: "bolt"
            ),

            // Security
            PromptTemplate(
                name: "Security Audit",
                category: .security,
                template: """
                Perform security audit on:

                {CODE}

                Check for:
                - SQL injection
                - XSS vulnerabilities
                - Command injection
                - Path traversal
                - Insecure data handling
                - Authentication issues

                For each issue: Severity, exploit scenario, fix.
                """,
                variables: ["CODE"],
                icon: "shield.checkered"
            )
        ]
    }

    /// Finds prompts by category
    func prompts(in category: PromptCategory) -> [PromptTemplate] {
        return prompts.filter { $0.category == category }
    }

    /// Searches prompts by name or keywords
    func search(_ query: String) -> [PromptTemplate] {
        let lowercaseQuery = query.lowercased()
        return prompts.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.template.lowercased().contains(lowercaseQuery)
        }
    }
}

/// Prompt category
enum PromptCategory: String, CaseIterable {
    case codeQuality = "Code Quality"
    case testing = "Testing"
    case documentation = "Documentation"
    case git = "Git"
    case architecture = "Architecture"
    case debugging = "Debugging"
    case security = "Security"

    var icon: String {
        switch self {
        case .codeQuality: return "star"
        case .testing: return "checkmark.square"
        case .documentation: return "doc.text"
        case .git: return "arrow.triangle.branch"
        case .architecture: return "building.2"
        case .debugging: return "ant"
        case .security: return "shield"
        }
    }
}
