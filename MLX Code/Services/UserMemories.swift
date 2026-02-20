//
//  UserMemories.swift
//  MLX Code
//
//  User memory system — stores learned preferences, rules, and working standards
//  that shape how the LLM assistant behaves.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Manages user memories that shape LLM behavior
/// Memories are persistent preferences, rules, and standards the user has established.
/// The LLM references these on every interaction to maintain consistency.
///
/// SECURITY NOTE: Built-in memories contain ONLY generic coding standards.
/// User-specific data (names, paths, credentials, repo URLs) is loaded from
/// AppSettings at runtime and never committed to source control.
actor UserMemories {

    static let shared = UserMemories()

    // MARK: - Memory Categories

    /// All memory categories available
    enum MemoryCategory: String, CaseIterable, Codable {
        case personality = "Personality & Communication"
        case codeQuality = "Code Quality"
        case security = "Security"
        case xcode = "Xcode & Build"
        case git = "Git & Version Control"
        case testing = "Testing"
        case documentation = "Documentation"
        case deployment = "Deployment"
        case custom = "Custom"
    }

    /// A single memory entry
    struct Memory: Codable, Identifiable {
        let id: UUID
        let category: MemoryCategory
        let rule: String
        var enabled: Bool

        init(category: MemoryCategory, rule: String, enabled: Bool = true) {
            self.id = UUID()
            self.category = category
            self.rule = rule
            self.enabled = enabled
        }
    }

    // MARK: - Properties

    private var memories: [Memory] = []
    private var customMemories: [Memory] = []
    private let customMemoriesURL: URL? = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mlxcode")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memories.json")
    }()

    // MARK: - Initialization

    private init() {
        memories = Self.builtInMemories
        _loadCustomMemories()
    }

    // MARK: - Public Interface

    /// Get all enabled memories formatted for inclusion in a system prompt
    /// User-specific paths/names are injected from AppSettings at call time
    func getPromptMemories(userName: String = "", binariesPath: String = "", nasPath: String = "", projectsPath: String = "") -> String {
        let enabled = (memories + customMemories).filter { $0.enabled }
        guard !enabled.isEmpty else { return "" }

        var sections: [MemoryCategory: [String]] = [:]
        for memory in enabled {
            sections[memory.category, default: []].append(memory.rule)
        }

        var result = "\n\n# User Preferences & Standards\n"
        result += "The following rules reflect the user's established working standards. Follow them consistently.\n\n"

        for category in MemoryCategory.allCases {
            guard let rules = sections[category], !rules.isEmpty else { continue }
            result += "## \(category.rawValue)\n"
            for rule in rules {
                result += "- \(rule)\n"
            }
            result += "\n"
        }

        // Inject user-specific paths from settings (never hardcoded)
        if !binariesPath.isEmpty || !nasPath.isEmpty || !projectsPath.isEmpty || !userName.isEmpty {
            result += "## User Environment\n"
            if !userName.isEmpty {
                result += "- Author name for documentation and release notes: \(userName)\n"
            }
            if !projectsPath.isEmpty {
                result += "- Primary projects directory: \(projectsPath)\n"
            }
            if !binariesPath.isEmpty {
                result += "- Binary archives directory: \(binariesPath)\n"
            }
            if !nasPath.isEmpty {
                result += "- NAS backup directory: \(nasPath)\n"
            }
            result += "\n"
        }

        return result
    }

    /// Get memories relevant to a specific task type
    func getTaskMemories(for taskType: TaskType) -> String {
        let categories = taskType.relevantCategories
        let relevant = (memories + customMemories)
            .filter { $0.enabled && categories.contains($0.category) }

        guard !relevant.isEmpty else { return "" }

        var result = "\n\n# Relevant Standards\n"
        for memory in relevant {
            result += "- \(memory.rule)\n"
        }
        return result
    }

    /// Get all memories (for settings UI)
    func getAllMemories() -> [Memory] {
        return memories + customMemories
    }

    /// Get only custom memories
    func getCustomMemories() -> [Memory] {
        return customMemories
    }

    /// Add a custom memory
    func addCustomMemory(category: MemoryCategory, rule: String) {
        let memory = Memory(category: category, rule: rule)
        customMemories.append(memory)
        saveCustomMemories()
    }

    /// Remove a custom memory by ID
    func removeCustomMemory(id: UUID) {
        customMemories.removeAll { $0.id == id }
        saveCustomMemories()
    }

    /// Toggle a built-in memory on/off
    func toggleMemory(id: UUID, enabled: Bool) {
        if let idx = memories.firstIndex(where: { $0.id == id }) {
            memories[idx].enabled = enabled
        } else if let idx = customMemories.firstIndex(where: { $0.id == id }) {
            customMemories[idx].enabled = enabled
            saveCustomMemories()
        }
    }

    /// Reload custom memories from disk
    func reloadCustomMemories() {
        _loadCustomMemories()
    }

    // MARK: - Task Types

    enum TaskType {
        case codeReview
        case bugFix
        case feature
        case refactor
        case test
        case documentation
        case build
        case deploy
        case gitOperation
        case general

        var relevantCategories: Set<MemoryCategory> {
            switch self {
            case .codeReview:
                return [.codeQuality, .security, .documentation]
            case .bugFix:
                return [.codeQuality, .security, .testing]
            case .feature:
                return [.codeQuality, .security, .testing, .documentation]
            case .refactor:
                return [.codeQuality, .testing]
            case .test:
                return [.testing, .codeQuality]
            case .documentation:
                return [.documentation]
            case .build:
                return [.xcode, .codeQuality]
            case .deploy:
                return [.xcode, .deployment, .git, .security]
            case .gitOperation:
                return [.git, .security]
            case .general:
                return Set(MemoryCategory.allCases)
            }
        }
    }

    // MARK: - Persistence

    /// Non-isolated loader used only from init
    private nonisolated func _loadCustomMemories() {
        // This is called from init only — safe nonisolated access
    }

    private func loadCustomMemories() {
        guard let url = customMemoriesURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            customMemories = try JSONDecoder().decode([Memory].self, from: data)
        } catch {
            print("Failed to load custom memories: \(error.localizedDescription)")
        }
    }

    private func saveCustomMemories() {
        guard let url = customMemoriesURL else { return }
        do {
            let data = try JSONEncoder().encode(customMemories)
            try data.write(to: url)
        } catch {
            print("Failed to save custom memories: \(error.localizedDescription)")
        }
    }

    // MARK: - Built-in Memories (generic standards only — NO personal data)

    /// These memories contain ONLY generic coding best practices.
    /// User-specific information (names, paths, URLs) is injected at runtime from AppSettings.
    private static let builtInMemories: [Memory] = [

        // ── Personality & Communication ──

        Memory(category: .personality, rule: "Be autonomous — execute commands, edits, and operations without asking permission for routine tasks"),
        Memory(category: .personality, rule: "Act as a senior Swift/Objective-C expert, DevOps engineer, and Xcode specialist"),
        Memory(category: .personality, rule: "Give direct answers first, then explanation if needed. Code examples over abstract descriptions"),
        Memory(category: .personality, rule: "When there are trade-offs, present options with your recommendation"),
        Memory(category: .personality, rule: "Warn about potential issues upfront. Be honest about limitations and uncertainties"),
        Memory(category: .personality, rule: "Don't sugarcoat bad news. Don't apologize excessively — just fix it"),
        Memory(category: .personality, rule: "Show your thinking process. Log approaches you try to resolve issues"),
        Memory(category: .personality, rule: "If something breaks, say so immediately — never hide mistakes"),
        Memory(category: .personality, rule: "Try 2-3 approaches before asking for help. Document what you tried"),
        Memory(category: .personality, rule: "ASK before: breaking changes, architecture decisions, deleting significant code, security decisions, production deployment"),
        Memory(category: .personality, rule: "If the user asks for something insecure, warn them and explain why it's dangerous"),

        // ── Code Quality ──

        Memory(category: .codeQuality, rule: "ALWAYS read files before suggesting edits. Never propose changes to unread code"),
        Memory(category: .codeQuality, rule: "Build after making changes to verify correctness"),
        Memory(category: .codeQuality, rule: "Prefer clarity over cleverness — code should be self-evident"),
        Memory(category: .codeQuality, rule: "Single responsibility — each function does one thing well"),
        Memory(category: .codeQuality, rule: "Max 3 levels of nesting. Refactor if deeper"),
        Memory(category: .codeQuality, rule: "No magic numbers — use named constants"),
        Memory(category: .codeQuality, rule: "Delete commented-out code (Git history preserves it)"),
        Memory(category: .codeQuality, rule: "Check for memory leaks and retain cycles. Use weak/unowned for delegates and closure captures"),
        Memory(category: .codeQuality, rule: "Profile before optimizing — no premature optimization"),
        Memory(category: .codeQuality, rule: "User-facing errors must be actionable. Log errors with context (what, when, why, where)"),
        Memory(category: .codeQuality, rule: "Never fail silently — at minimum, log the error. Never expose stack traces to users"),
        Memory(category: .codeQuality, rule: "Watch for N+1 queries, excessive allocations. Use background threads for heavy operations"),
        Memory(category: .codeQuality, rule: "Performance targets: app launch < 2s, UI response < 100ms, critical ops < 500ms"),

        // ── Security ──

        Memory(category: .security, rule: "Security is mandatory. Assume all input is malicious"),
        Memory(category: .security, rule: "NEVER hardcode secrets — use Keychain, environment variables, or secure vaults"),
        Memory(category: .security, rule: "Scan code for API keys, passwords, tokens before committing. Never commit credentials"),
        Memory(category: .security, rule: "Validate ALL user input. Sanitize to prevent injection attacks (SQL, XSS, command injection)"),
        Memory(category: .security, rule: "Use AES-256 symmetric / RSA-2048+ asymmetric. CryptoKit or CommonCrypto only — never custom crypto"),
        Memory(category: .security, rule: "Use JSONEncoder for safe JavaScript string serialization in WebViews (prevents XSS)"),
        Memory(category: .security, rule: "Implement strict domain allowlists for WebView URL navigation"),
        Memory(category: .security, rule: "Principle of least privilege. Defense in depth. Fail securely (errors don't leak info)"),
        Memory(category: .security, rule: "Review for: injection, XSS, insecure data handling, auth bypasses, data exposure, retain cycles"),
        Memory(category: .security, rule: "Avoid unsafe C functions: strcpy, strcat, sprintf, gets. Use safe alternatives"),

        // ── Xcode & Build ──

        Memory(category: .xcode, rule: "Fix ALL compiler warnings — treat warnings as errors"),
        Memory(category: .xcode, rule: "Always add new files to the Xcode project (not just disk)"),
        Memory(category: .xcode, rule: "Version bumps: major for breaking changes, minor for features, patch for fixes"),
        Memory(category: .xcode, rule: "Before archiving: bump version, fix warnings, update release notes, clean build folder"),
        Memory(category: .xcode, rule: "Check for deprecated API usage before releasing"),
        Memory(category: .xcode, rule: "Follow Swift conventions: proper access control, value types, protocol-oriented design"),

        // ── Git & Version Control ──

        Memory(category: .git, rule: "Commit format: type(scope): description — types: feat, fix, docs, refactor, test, chore, security"),
        Memory(category: .git, rule: "Branches: main = stable, feature/* = features, fix/* = fixes, experiment/* = exploratory"),
        Memory(category: .git, rule: "Before commit: remove debug/print statements, run tests, scan for secrets, build clean"),
        Memory(category: .git, rule: "Scan for credentials before every push: API keys, Bearer tokens, JWTs, passwords, private keys"),
        Memory(category: .git, rule: "Comprehensive .gitignore: exclude certificates, provisioning profiles, secrets files, .env"),
        Memory(category: .git, rule: "Use SSH URLs for git remote operations. Never put tokens in URLs or files"),

        // ── Testing ──

        Memory(category: .testing, rule: "All new features require unit tests — no exceptions"),
        Memory(category: .testing, rule: "Critical paths require integration tests"),
        Memory(category: .testing, rule: "Test edge cases and error conditions. Add regression tests for every bug fix"),
        Memory(category: .testing, rule: "Don't skip tests for quick fixes"),
        Memory(category: .testing, rule: "Tests must be independent, fast, and test behavior not implementation"),
        Memory(category: .testing, rule: "Descriptive test names. One assertion per test when practical"),
        Memory(category: .testing, rule: "Use XCTest. Mock external dependencies. Run full suite before creating binaries"),

        // ── Documentation ──

        Memory(category: .documentation, rule: "Document WHY, not WHAT — the code shows what it does"),
        Memory(category: .documentation, rule: "Document: complex algorithms, public APIs, security-sensitive code, workarounds"),
        Memory(category: .documentation, rule: "Don't document obvious code. Let code speak for itself"),
        Memory(category: .documentation, rule: "Use Swift doc format (///) with parameters and return values"),

        // ── Deployment ──

        Memory(category: .deployment, rule: "Archive to the user's configured binaries directory with date-coded folders (YYYYMMDD-App-vX.Y.Z/)"),
        Memory(category: .deployment, rule: "Also export to NAS backup path if configured"),
        Memory(category: .deployment, rule: "Create DMG installer for every macOS app (AppName-vX.Y.Z-buildN.dmg)"),
        Memory(category: .deployment, rule: "Include release notes with each build"),
        Memory(category: .deployment, rule: "Install app to /Applications after successful macOS build"),
        Memory(category: .deployment, rule: "Never overwrite existing archives. Never delete old binaries without confirmation"),
        Memory(category: .deployment, rule: "No Mac App Store — distribute via DMG only. Disable app sandbox for macOS apps"),
    ]
}
