//
//  PromptTemplates.swift
//  MLX Code
//
//  Curated prompt template library for common coding tasks.
//  Templates are pre-engineered for local LLMs (qwen3, phi4, etc.) —
//  they use explicit output rules and short context windows efficiently.
//
//  Written by Jordan Koch.
//

import Foundation

// MARK: - Template Model

struct PromptTemplate: Identifiable, Codable, Hashable {
    static func == (lhs: PromptTemplate, rhs: PromptTemplate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let name: String
    let category: TemplateCategory
    let description: String
    let icon: String
    let template: String          // Use {{VARIABLE}} for user-filled slots
    let variables: [TemplateVar]  // Slots to fill before sending
    let tags: [String]

    enum TemplateCategory: String, Codable, CaseIterable {
        case review       = "Review"
        case debug        = "Debug"
        case generate     = "Generate"
        case refactor     = "Refactor"
        case document     = "Document"
        case test         = "Test"
        case security     = "Security"
        case performance  = "Performance"
        case deploy       = "Deploy"
        case git          = "Git"
    }

    struct TemplateVar: Codable, Identifiable {
        var id: String { name }
        let name: String
        let label: String
        let placeholder: String
        let required: Bool
    }

    /// Render template by substituting filled variable values
    func render(with values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}

// MARK: - Template Library

struct PromptTemplateLibrary {

    static let all: [PromptTemplate] = [
        swiftCodeReview,
        bugFix,
        featureImplementation,
        refactorFile,
        addUnitTests,
        addDocumentation,
        securityAudit,
        performanceProfile,
        explainCode,
        createAPIEndpoint,
        migrationPlan,
        reviewPR,
        debugBuildError,
        addErrorHandling,
        createDataModel,
    ]

    static func templates(for category: PromptTemplate.TemplateCategory) -> [PromptTemplate] {
        all.filter { $0.category == category }
    }

    static func template(id: String) -> PromptTemplate? {
        all.first { $0.id == id }
    }

    // MARK: - Review

    static let swiftCodeReview = PromptTemplate(
        id: "swift-code-review",
        name: "Swift Code Review",
        category: .review,
        description: "Full review: memory, security, style, and correctness",
        icon: "checkmark.seal",
        template: """
        # Code Review: {{FILE_PATH}}

        Read the file at {{FILE_PATH}} and perform a thorough review.

        Check for:
        1. Memory management — retain cycles, weak/unowned in closures, ARC issues
        2. Security — injection risks, hardcoded secrets, unvalidated inputs, data exposure
        3. Error handling — silent failures, missing catch blocks, non-actionable user errors
        4. Swift style — access control, value vs. reference types, protocol conformance
        5. Logic bugs and edge cases (nil, empty, boundary values)
        6. Performance — N+1 patterns, unnecessary allocations in loops

        Rate each issue: CRITICAL / HIGH / MEDIUM / LOW.
        Suggest specific fixes with corrected code where relevant.
        """,
        variables: [
            .init(name: "FILE_PATH", label: "File", placeholder: "e.g. Sources/MyView.swift", required: true)
        ],
        tags: ["swift", "review", "security", "memory"]
    )

    static let reviewPR = PromptTemplate(
        id: "review-pr",
        name: "Review PR / Diff",
        category: .review,
        description: "Review uncommitted or staged changes for correctness and issues",
        icon: "arrow.triangle.pull",
        template: """
        # Pull Request Review

        Show the current git diff (staged + unstaged), then review all changes:

        For each changed file:
        - What does this change do?
        - Are there any bugs introduced?
        - Are there security or memory concerns?
        - Does it follow project conventions?

        Summarise with: ✅ Approve / ⚠️ Approve with comments / ❌ Request changes
        Provide actionable suggestions for every issue found.
        """,
        variables: [],
        tags: ["git", "review", "diff"]
    )

    // MARK: - Debug

    static let bugFix = PromptTemplate(
        id: "bug-fix",
        name: "Fix a Bug",
        category: .debug,
        description: "Root-cause analysis and targeted fix with regression test",
        icon: "ant",
        template: """
        # Bug Fix

        Bug: {{DESCRIPTION}}
        {{#FILE}}File: {{FILE}}{{/FILE}}

        Steps:
        1. Read all relevant files (never propose changes to unread code)
        2. Identify the root cause — show reasoning
        3. Check for similar patterns elsewhere in the codebase
        4. Implement the minimal fix that doesn't change behaviour elsewhere
        5. Verify it builds without warnings or errors
        6. Add a regression test to prevent recurrence

        If the fix involves breaking changes, explain the risk before proceeding.
        """,
        variables: [
            .init(name: "DESCRIPTION", label: "Bug description",  placeholder: "What's going wrong?",   required: true),
            .init(name: "FILE",        label: "Affected file",     placeholder: "Optional: path/to/file.swift", required: false),
        ],
        tags: ["debug", "fix", "regression"]
    )

    static let debugBuildError = PromptTemplate(
        id: "debug-build-error",
        name: "Fix Build Error",
        category: .debug,
        description: "Diagnose and fix Xcode build errors or warnings",
        icon: "hammer.badge.exclamationmark",
        template: """
        # Build Error

        Build the project and fix all errors and warnings.

        Process:
        1. Run `xcodebuild` and capture the full output
        2. Parse each error and warning (file, line, message)
        3. Fix errors in order of dependency (fix upstream errors first)
        4. Treat warnings as errors — fix them all
        5. Rebuild to confirm zero errors and zero warnings
        6. If a fix is non-obvious, explain the root cause

        Target scheme: {{SCHEME}}
        """,
        variables: [
            .init(name: "SCHEME", label: "Xcode scheme", placeholder: "e.g. MyApp", required: true)
        ],
        tags: ["build", "xcode", "error"]
    )

    // MARK: - Generate

    static let featureImplementation = PromptTemplate(
        id: "feature-implementation",
        name: "Implement Feature",
        category: .generate,
        description: "Design, implement, test, and document a new feature",
        icon: "sparkles",
        template: """
        # Feature: {{FEATURE}}

        {{#CONTEXT}}Context: {{CONTEXT}}{{/CONTEXT}}

        Implementation checklist:
        1. Read existing related code — never guess structure
        2. Design the approach and explain before writing code
        3. Implement following Swift conventions (value types, protocols, weak refs)
        4. Never hardcode secrets — use Keychain
        5. Validate all user inputs
        6. Add unit tests for the new functionality
        7. Add doc comments (///) for public API — document WHY, not WHAT
        8. Build and confirm zero warnings
        9. Add new files to the Xcode project target

        Do not add features, abstractions, or configurability beyond what's described.
        """,
        variables: [
            .init(name: "FEATURE",  label: "Feature description", placeholder: "What to build",          required: true),
            .init(name: "CONTEXT",  label: "Context",              placeholder: "Related files or notes",  required: false),
        ],
        tags: ["feature", "swift", "implementation"]
    )

    static let createAPIEndpoint = PromptTemplate(
        id: "create-api-endpoint",
        name: "Add API Endpoint",
        category: .generate,
        description: "Add a new HTTP endpoint to the existing NovaAPIServer",
        icon: "network.badge.shield.half.filled",
        template: """
        # New API Endpoint: {{METHOD}} {{PATH}}

        Description: {{DESCRIPTION}}

        Add this endpoint to NovaAPIServer.swift:
        1. Add the route to `handleRoute()` following existing patterns
        2. Create a `handle{{HANDLER_NAME}}()` method
        3. Return `(Int, Any)` — status code + JSON-serialisable dict
        4. Handle errors gracefully with descriptive messages
        5. Add the endpoint to /api/docs if it exists

        Request format: {{REQUEST_FORMAT}}
        Response format: {{RESPONSE_FORMAT}}
        """,
        variables: [
            .init(name: "METHOD",          label: "HTTP method",    placeholder: "GET / POST",             required: true),
            .init(name: "PATH",            label: "Path",            placeholder: "/api/my/endpoint",      required: true),
            .init(name: "DESCRIPTION",     label: "What it does",   placeholder: "Brief description",     required: true),
            .init(name: "HANDLER_NAME",    label: "Handler name",   placeholder: "e.g. MyFeature",        required: true),
            .init(name: "REQUEST_FORMAT",  label: "Request body",   placeholder: "{\"key\": \"value\"}",  required: false),
            .init(name: "RESPONSE_FORMAT", label: "Response body",  placeholder: "{\"key\": \"value\"}",  required: false),
        ],
        tags: ["api", "server", "endpoint"]
    )

    static let createDataModel = PromptTemplate(
        id: "create-data-model",
        name: "Create Data Model",
        category: .generate,
        description: "Design a Swift struct/class with Codable, validation, and tests",
        icon: "cylinder",
        template: """
        # New Data Model: {{MODEL_NAME}}

        Description: {{DESCRIPTION}}
        Fields: {{FIELDS}}

        Create {{MODEL_NAME}}.swift with:
        1. Struct or class (prefer struct for value semantics)
        2. Codable conformance with CodingKeys where needed
        3. Identifiable if it will appear in SwiftUI lists
        4. Sensible default values and init
        5. Input validation (no silent truncation)
        6. Add to Xcode project target
        7. Unit tests in {{MODEL_NAME}}Tests.swift
        """,
        variables: [
            .init(name: "MODEL_NAME",  label: "Model name",   placeholder: "e.g. UserProfile", required: true),
            .init(name: "DESCRIPTION", label: "What it represents", placeholder: "Brief description", required: true),
            .init(name: "FIELDS",      label: "Fields",       placeholder: "name: String, age: Int, ...", required: true),
        ],
        tags: ["model", "codable", "swift"]
    )

    // MARK: - Refactor

    static let refactorFile = PromptTemplate(
        id: "refactor-file",
        name: "Refactor File",
        category: .refactor,
        description: "Clean up a file for clarity, performance, and maintainability",
        icon: "arrow.triangle.2.circlepath",
        template: """
        # Refactor: {{FILE_PATH}}

        Goal: {{GOAL}}

        Rules:
        - Read the current code completely before touching anything
        - Single responsibility per function
        - Maximum 3 nesting levels
        - No magic numbers — use named constants
        - Delete commented-out code (git history preserves it)
        - Prefer clarity over cleverness
        - Do NOT change external behaviour
        - Existing tests must still pass
        - Build clean with zero warnings after changes
        """,
        variables: [
            .init(name: "FILE_PATH", label: "File to refactor", placeholder: "path/to/file.swift",        required: true),
            .init(name: "GOAL",      label: "Refactoring goal", placeholder: "e.g. Reduce complexity", required: true),
        ],
        tags: ["refactor", "cleanup", "swift"]
    )

    // MARK: - Document

    static let addDocumentation = PromptTemplate(
        id: "add-documentation",
        name: "Add Documentation",
        category: .document,
        description: "Add Swift doc comments to public API — focuses on WHY",
        icon: "doc.text",
        template: """
        # Documentation: {{FILE_PATH}}

        Read {{FILE_PATH}} and add documentation:
        - Use `///` Swift doc format
        - Document WHY, not WHAT — the code shows what it does
        - Include `- Parameters:` and `- Returns:` for non-obvious functions
        - Document security-sensitive code, complex algorithms, and workarounds
        - Add example usage for public APIs
        - Credit author as "Jordan Koch"
        - Do NOT add docs to trivial getters or obvious one-liners

        After adding docs, build to confirm no warnings.
        """,
        variables: [
            .init(name: "FILE_PATH", label: "File", placeholder: "path/to/file.swift", required: true)
        ],
        tags: ["docs", "comments", "swift"]
    )

    // MARK: - Test

    static let addUnitTests = PromptTemplate(
        id: "add-unit-tests",
        name: "Add Unit Tests",
        category: .test,
        description: "Comprehensive XCTest suite for a file or feature",
        icon: "checkmark.rectangle.stack",
        template: """
        # Unit Tests: {{TARGET}}

        Read {{TARGET}} and write a complete XCTest suite.

        Coverage:
        - Happy path (normal operation)
        - Edge cases: nil, empty, boundary values, max values
        - Error conditions: invalid input, timeout, network failure
        - Known bug scenarios (regression tests)

        Standards:
        - Tests must be independent — no ordering dependencies
        - Name tests descriptively: `test_functionName_whenCondition_expectsResult`
        - One assertion per test when practical
        - Test behaviour, not implementation details
        - Mock external dependencies with protocols
        - Add the test file to Xcode's test target

        Run the suite after writing to confirm all pass.
        """,
        variables: [
            .init(name: "TARGET", label: "File or feature to test", placeholder: "path/to/file.swift", required: true)
        ],
        tags: ["tests", "xctest", "tdd"]
    )

    // MARK: - Security

    static let securityAudit = PromptTemplate(
        id: "security-audit",
        name: "Security Audit",
        category: .security,
        description: "Full OWASP-aligned security scan of a file or module",
        icon: "lock.shield",
        template: """
        # Security Audit: {{SCOPE}}

        Audit {{SCOPE}} against the OWASP Mobile Top 10:

        1. Improper credential usage — hardcoded secrets, insecure storage
        2. Inadequate supply chain security — dependency risks
        3. Insecure authentication / authorisation
        4. Insufficient input validation — injection, XSS risks
        5. Insecure communication — plain HTTP, missing TLS pinning
        6. Inadequate privacy controls — PII exposure, logging issues
        7. Insufficient binary protections
        8. Security misconfiguration — debug flags in release
        9. Insecure data storage — unencrypted files, insecure keychain usage
        10. Insufficient cryptography — weak algorithms, key mismanagement

        Rate each finding: CRITICAL / HIGH / MEDIUM / LOW / INFO.
        Provide specific remediation steps and corrected code snippets.
        Scan for credential leaks before suggesting any git operations.
        """,
        variables: [
            .init(name: "SCOPE", label: "File or module", placeholder: "path/to/file.swift or module name", required: true)
        ],
        tags: ["security", "owasp", "audit"]
    )

    static let addErrorHandling = PromptTemplate(
        id: "add-error-handling",
        name: "Add Error Handling",
        category: .security,
        description: "Harden a file with proper Swift error handling and logging",
        icon: "exclamationmark.shield",
        template: """
        # Error Handling: {{FILE_PATH}}

        Read {{FILE_PATH}} and harden it:
        1. Replace force-try (`try!`) with proper do/catch
        2. Replace force-unwrap (`!`) with guard/if-let or nil coalescing
        3. Add logging for all caught errors with context (file, function, error)
        4. User-facing errors must be actionable ("Try again" not "Error 500")
        5. Never expose stack traces or internal details to the user
        6. Silent failures are unacceptable — log everything at minimum
        7. Network calls must have timeout handling and retry logic

        After hardening, build clean with zero warnings.
        """,
        variables: [
            .init(name: "FILE_PATH", label: "File", placeholder: "path/to/file.swift", required: true)
        ],
        tags: ["error-handling", "robustness", "swift"]
    )

    // MARK: - Performance

    static let performanceProfile = PromptTemplate(
        id: "performance-profile",
        name: "Performance Analysis",
        category: .performance,
        description: "Profile and optimise — no premature optimisation",
        icon: "gauge.with.dots.needle.67percent",
        template: """
        # Performance Analysis: {{SCOPE}}

        Analyse {{SCOPE}} for performance issues.

        Profile first:
        1. Read the code and identify candidates (loops, network calls, UI updates)
        2. Check for N+1 query patterns
        3. Find unnecessary allocations in hot paths
        4. Spot main-thread blocking operations
        5. Identify unthrottled timers or observers

        Only optimise what profiling confirms is slow.
        For each optimisation:
        - State the measured baseline
        - Implement the fix
        - State the expected improvement
        - Verify it builds and tests still pass

        Do NOT optimise speculatively.
        """,
        variables: [
            .init(name: "SCOPE", label: "File or feature to profile", placeholder: "path/to/file.swift", required: true)
        ],
        tags: ["performance", "profiling", "optimisation"]
    )

    // MARK: - Deploy

    static let migrationPlan = PromptTemplate(
        id: "migration-plan",
        name: "Migration Plan",
        category: .deploy,
        description: "Plan and execute a breaking change or schema migration",
        icon: "arrow.right.doc.on.clipboard",
        template: """
        # Migration Plan: {{TITLE}}

        Context: {{CONTEXT}}

        Generate a safe migration plan:
        1. Document the current state (read all relevant files)
        2. Identify every call-site affected by the change
        3. List breaking changes and impacted consumers
        4. Propose migration path with backward compatibility notes
        5. Define rollback procedure
        6. Implement in this order:
           a. New implementation (keep old alongside)
           b. Migrate consumers one by one
           c. Remove old implementation
        7. Update all documentation and release notes
        8. Run full test suite after each migration step

        Confirm nothing is deleted until all consumers are migrated.
        """,
        variables: [
            .init(name: "TITLE",   label: "Migration title",   placeholder: "e.g. Rename AuthManager",  required: true),
            .init(name: "CONTEXT", label: "What's changing",    placeholder: "Brief description",        required: true),
        ],
        tags: ["migration", "refactor", "breaking-change"]
    )

    // MARK: - Explain

    static let explainCode = PromptTemplate(
        id: "explain-code",
        name: "Explain Code",
        category: .document,
        description: "Plain-English explanation of a complex file or function",
        icon: "questionmark.circle",
        template: """
        # Explain: {{FILE_PATH}}

        Read {{FILE_PATH}} and explain it clearly:
        1. What is the purpose of this file / module?
        2. What does each significant function or class do?
        3. What are the key data flows and state mutations?
        4. Are there any non-obvious design decisions worth understanding?
        5. What are the known limitations or caveats?

        Write for an experienced Swift developer who hasn't seen this code before.
        Use concrete examples where helpful.
        """,
        variables: [
            .init(name: "FILE_PATH", label: "File to explain", placeholder: "path/to/file.swift", required: true)
        ],
        tags: ["explain", "documentation", "understanding"]
    )
}
