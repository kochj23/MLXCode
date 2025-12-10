//
//  PromptTemplate.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Reusable prompt template for common coding tasks
///
/// ## Usage
/// ```swift
/// let template = PromptTemplate.swiftUIView
/// let prompt = template.renderWithVariables(["name": "UserProfile"])
/// ```
///
/// ## Memory Safety
/// All templates are value types (struct) - no retain cycle risks
struct PromptTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var description: String
    var template: String
    var variables: [TemplateVariable]
    var tags: [String]
    var isBuiltIn: Bool
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        description: String,
        template: String,
        variables: [TemplateVariable] = [],
        tags: [String] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.template = template
        self.variables = variables
        self.tags = tags
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.useCount = 0
    }

    /// Renders the template with provided variable values
    /// - Parameter values: Dictionary mapping variable names to values
    /// - Returns: Rendered prompt string
    func render(with values: [String: String] = [:]) -> String {
        var result = template

        // Replace variables
        for variable in variables {
            let placeholder = "{{\(variable.name)}}"
            let value = values[variable.name] ?? variable.defaultValue ?? ""
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        return result
    }

    /// Increments use count and updates last used timestamp
    mutating func recordUsage() {
        useCount += 1
        lastUsedAt = Date()
    }
}

// MARK: - Template Variable

/// Variable placeholder in a prompt template
struct TemplateVariable: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var defaultValue: String?
    var placeholder: String?
    var isRequired: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        defaultValue: String? = nil,
        placeholder: String? = nil,
        isRequired: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.placeholder = placeholder
        self.isRequired = isRequired
    }
}

// MARK: - Template Category

/// Category for organizing templates
enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case codeGeneration = "Code Generation"
    case refactoring = "Refactoring"
    case testing = "Testing"
    case documentation = "Documentation"
    case debugging = "Debugging"
    case git = "Git"
    case performance = "Performance"
    case security = "Security"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .codeGeneration: return "doc.text"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .testing: return "checkmark.circle"
        case .documentation: return "book"
        case .debugging: return "ant"
        case .git: return "arrow.branch"
        case .performance: return "speedometer"
        case .security: return "lock.shield"
        case .custom: return "star"
        }
    }
}

// MARK: - Built-in Templates

extension PromptTemplate {
    /// All built-in templates
    static var builtInTemplates: [PromptTemplate] {
        [
            // Code Generation
            swiftUIViewTemplate,
            mvvmModelTemplate,
            unitTestTemplate,
            viewModelTemplate,
            networkServiceTemplate,

            // Refactoring
            extractFunctionTemplate,
            asyncAwaitConversionTemplate,
            combineToAsyncTemplate,

            // Documentation
            docCommentsTemplate,
            readmeTemplate,
            changelogTemplate,

            // Debugging
            explainErrorTemplate,
            suggestFixTemplate,

            // Git
            commitMessageTemplate,
            pullRequestTemplate,

            // Performance
            optimizeCodeTemplate,
            memoryLeakCheckTemplate,

            // Security
            securityAuditTemplate,
            inputValidationTemplate
        ]
    }

    // MARK: Code Generation Templates

    static var swiftUIViewTemplate: PromptTemplate {
        PromptTemplate(
            name: "SwiftUI View",
            category: .codeGeneration,
            description: "Generate a complete SwiftUI view",
            template: """
            Create a SwiftUI view named {{name}} with the following requirements:
            {{requirements}}

            Please include:
            - Proper view structure
            - State management if needed
            - Preview provider
            - Documentation comments
            """,
            variables: [
                TemplateVariable(name: "name", description: "View name", placeholder: "MyCustomView"),
                TemplateVariable(name: "requirements", description: "View requirements", placeholder: "Display a list of items")
            ],
            tags: ["swift", "swiftui", "view"],
            isBuiltIn: true
        )
    }

    static var mvvmModelTemplate: PromptTemplate {
        PromptTemplate(
            name: "MVVM Model",
            category: .codeGeneration,
            description: "Generate MVVM model, view model, and view",
            template: """
            Create a complete MVVM implementation for {{feature}}:

            1. Model - Data structure with Codable conformance
            2. ViewModel - ObservableObject with @Published properties
            3. View - SwiftUI view displaying the data

            Requirements:
            {{requirements}}

            Please ensure proper memory management with [weak self] in closures.
            """,
            variables: [
                TemplateVariable(name: "feature", description: "Feature name", placeholder: "UserProfile"),
                TemplateVariable(name: "requirements", description: "Specific requirements")
            ],
            tags: ["mvvm", "architecture", "swiftui"],
            isBuiltIn: true
        )
    }

    static var unitTestTemplate: PromptTemplate {
        PromptTemplate(
            name: "Unit Tests",
            category: .testing,
            description: "Generate comprehensive unit tests",
            template: """
            Write comprehensive unit tests for {{className}}.

            Test the following scenarios:
            {{scenarios}}

            Use XCTest framework and include:
            - Setup and teardown
            - Happy path tests
            - Edge cases
            - Error cases
            - Async tests if needed
            """,
            variables: [
                TemplateVariable(name: "className", description: "Class to test", placeholder: "ChatViewModel"),
                TemplateVariable(name: "scenarios", description: "Scenarios to test", placeholder: "message sending, error handling")
            ],
            tags: ["testing", "xctest"],
            isBuiltIn: true
        )
    }

    static var viewModelTemplate: PromptTemplate {
        PromptTemplate(
            name: "View Model",
            category: .codeGeneration,
            description: "Generate an ObservableObject view model",
            template: """
            Create a SwiftUI ViewModel class named {{name}}ViewModel for {{description}}.

            Properties needed:
            {{properties}}

            Methods needed:
            {{methods}}

            Requirements:
            - Use @MainActor for thread safety
            - Use @Published for observable properties
            - Include proper error handling
            - Use [weak self] in closures
            - Add comprehensive documentation
            """,
            variables: [
                TemplateVariable(name: "name", description: "Feature name", placeholder: "Settings"),
                TemplateVariable(name: "description", description: "What it does"),
                TemplateVariable(name: "properties", description: "Required properties"),
                TemplateVariable(name: "methods", description: "Required methods")
            ],
            tags: ["viewmodel", "swiftui", "mvvm"],
            isBuiltIn: true
        )
    }

    static var networkServiceTemplate: PromptTemplate {
        PromptTemplate(
            name: "Network Service",
            category: .codeGeneration,
            description: "Generate a network service with URLSession",
            template: """
            Create a network service for {{apiName}} API.

            Endpoints:
            {{endpoints}}

            Requirements:
            - Use async/await
            - Include proper error handling
            - Add request/response models with Codable
            - Include authentication if needed
            - Add comprehensive documentation
            - Follow secure coding practices
            """,
            variables: [
                TemplateVariable(name: "apiName", description: "API name", placeholder: "GitHub"),
                TemplateVariable(name: "endpoints", description: "API endpoints to implement")
            ],
            tags: ["networking", "api", "urlsession"],
            isBuiltIn: true
        )
    }

    // MARK: Refactoring Templates

    static var extractFunctionTemplate: PromptTemplate {
        PromptTemplate(
            name: "Extract Function",
            category: .refactoring,
            description: "Extract code into a reusable function",
            template: """
            Extract the following code into a well-named, reusable function:

            ```swift
            {{code}}
            ```

            Requirements:
            - Choose an appropriate function name
            - Add proper parameters
            - Include return type
            - Add documentation
            - Preserve behavior
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to extract")
            ],
            tags: ["refactoring", "clean-code"],
            isBuiltIn: true
        )
    }

    static var asyncAwaitConversionTemplate: PromptTemplate {
        PromptTemplate(
            name: "Convert to Async/Await",
            category: .refactoring,
            description: "Convert completion handlers to async/await",
            template: """
            Convert this code from completion handlers to async/await:

            ```swift
            {{code}}
            ```

            Please ensure:
            - Proper error propagation
            - Correct async throws declarations
            - Maintain original behavior
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to convert")
            ],
            tags: ["refactoring", "async", "swift"],
            isBuiltIn: true
        )
    }

    static var combineToAsyncTemplate: PromptTemplate {
        PromptTemplate(
            name: "Combine to Async/Await",
            category: .refactoring,
            description: "Convert Combine publishers to async/await",
            template: """
            Convert this Combine code to async/await:

            ```swift
            {{code}}
            ```

            Use AsyncStream or Task where appropriate.
            """,
            variables: [
                TemplateVariable(name: "code", description: "Combine code")
            ],
            tags: ["refactoring", "combine", "async"],
            isBuiltIn: true
        )
    }

    // MARK: Documentation Templates

    static var docCommentsTemplate: PromptTemplate {
        PromptTemplate(
            name: "Documentation Comments",
            category: .documentation,
            description: "Generate comprehensive doc comments",
            template: """
            Add comprehensive documentation comments to this code:

            ```swift
            {{code}}
            ```

            Include:
            - Summary description
            - Parameter descriptions
            - Return value description
            - Throws description if applicable
            - Usage examples
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to document")
            ],
            tags: ["documentation", "comments"],
            isBuiltIn: true
        )
    }

    static var readmeTemplate: PromptTemplate {
        PromptTemplate(
            name: "Generate README",
            category: .documentation,
            description: "Create a comprehensive README",
            template: """
            Generate a comprehensive README.md for {{projectName}}.

            Project description:
            {{description}}

            Include:
            - Overview
            - Installation instructions
            - Usage examples
            - API documentation
            - Contributing guidelines
            - License information
            """,
            variables: [
                TemplateVariable(name: "projectName", description: "Project name"),
                TemplateVariable(name: "description", description: "Project description")
            ],
            tags: ["documentation", "readme"],
            isBuiltIn: true
        )
    }

    static var changelogTemplate: PromptTemplate {
        PromptTemplate(
            name: "Changelog Entry",
            category: .documentation,
            description: "Generate changelog entry",
            template: """
            Generate a changelog entry for version {{version}}.

            Changes:
            {{changes}}

            Use Keep a Changelog format with categories:
            - Added
            - Changed
            - Deprecated
            - Removed
            - Fixed
            - Security
            """,
            variables: [
                TemplateVariable(name: "version", description: "Version number", placeholder: "1.0.0"),
                TemplateVariable(name: "changes", description: "List of changes")
            ],
            tags: ["documentation", "changelog"],
            isBuiltIn: true
        )
    }

    // MARK: Debugging Templates

    static var explainErrorTemplate: PromptTemplate {
        PromptTemplate(
            name: "Explain Error",
            category: .debugging,
            description: "Explain what an error means",
            template: """
            Explain this error message in detail:

            ```
            {{error}}
            ```

            Provide:
            - What the error means
            - Common causes
            - How to fix it
            - Prevention strategies
            """,
            variables: [
                TemplateVariable(name: "error", description: "Error message")
            ],
            tags: ["debugging", "error"],
            isBuiltIn: true
        )
    }

    static var suggestFixTemplate: PromptTemplate {
        PromptTemplate(
            name: "Suggest Fix",
            category: .debugging,
            description: "Suggest fixes for broken code",
            template: """
            This code isn't working as expected:

            ```swift
            {{code}}
            ```

            Problem:
            {{problem}}

            Please:
            1. Identify the issue
            2. Explain why it's not working
            3. Provide a corrected version
            4. Suggest tests to prevent regression
            """,
            variables: [
                TemplateVariable(name: "code", description: "Broken code"),
                TemplateVariable(name: "problem", description: "Description of problem")
            ],
            tags: ["debugging", "fix"],
            isBuiltIn: true
        )
    }

    // MARK: Git Templates

    static var commitMessageTemplate: PromptTemplate {
        PromptTemplate(
            name: "Git Commit Message",
            category: .git,
            description: "Generate conventional commit message",
            template: """
            Generate a Git commit message for these changes:

            {{changes}}

            Use conventional commits format (feat:, fix:, docs:, refactor:, test:, chore:).
            Keep subject line under 72 characters.
            Add detailed body if needed.
            """,
            variables: [
                TemplateVariable(name: "changes", description: "Description of changes")
            ],
            tags: ["git", "commit"],
            isBuiltIn: true
        )
    }

    static var pullRequestTemplate: PromptTemplate {
        PromptTemplate(
            name: "Pull Request Description",
            category: .git,
            description: "Generate PR description",
            template: """
            Create a pull request description for:

            {{changes}}

            Include:
            ## Summary
            [Brief overview]

            ## Changes
            - [List of changes]

            ## Testing
            - [How it was tested]

            ## Screenshots
            [If applicable]
            """,
            variables: [
                TemplateVariable(name: "changes", description: "Changes made")
            ],
            tags: ["git", "pr"],
            isBuiltIn: true
        )
    }

    // MARK: Performance Templates

    static var optimizeCodeTemplate: PromptTemplate {
        PromptTemplate(
            name: "Optimize Code",
            category: .performance,
            description: "Suggest performance optimizations",
            template: """
            Analyze and optimize this code for performance:

            ```swift
            {{code}}
            ```

            Focus on:
            - Time complexity
            - Memory usage
            - Unnecessary allocations
            - Better algorithms
            - Caching opportunities
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to optimize")
            ],
            tags: ["performance", "optimization"],
            isBuiltIn: true
        )
    }

    static var memoryLeakCheckTemplate: PromptTemplate {
        PromptTemplate(
            name: "Memory Leak Check",
            category: .performance,
            description: "Check for memory leaks",
            template: """
            Analyze this code for potential memory leaks:

            ```swift
            {{code}}
            ```

            Check for:
            - Retain cycles in closures
            - Strong delegate references
            - Missing [weak self]
            - Notification observer cleanup
            - Timer invalidation
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to analyze")
            ],
            tags: ["memory", "leaks", "performance"],
            isBuiltIn: true
        )
    }

    // MARK: Security Templates

    static var securityAuditTemplate: PromptTemplate {
        PromptTemplate(
            name: "Security Audit",
            category: .security,
            description: "Audit code for security issues",
            template: """
            Perform a security audit on this code:

            ```swift
            {{code}}
            ```

            Check for:
            - Input validation
            - SQL injection
            - XSS vulnerabilities
            - Hardcoded secrets
            - Insecure data storage
            - Improper error handling
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code to audit")
            ],
            tags: ["security", "audit"],
            isBuiltIn: true
        )
    }

    static var inputValidationTemplate: PromptTemplate {
        PromptTemplate(
            name: "Add Input Validation",
            category: .security,
            description: "Add proper input validation",
            template: """
            Add comprehensive input validation to this code:

            ```swift
            {{code}}
            ```

            Validate:
            - Data types
            - Length limits
            - Format constraints
            - Boundary conditions
            - Sanitize for security
            """,
            variables: [
                TemplateVariable(name: "code", description: "Code needing validation")
            ],
            tags: ["security", "validation"],
            isBuiltIn: true
        )
    }
}
