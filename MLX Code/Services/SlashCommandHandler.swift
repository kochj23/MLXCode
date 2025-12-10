//
//  SlashCommandHandler.swift
//  MLX Code
//
//  Slash command system for quick actions
//  Created on 2025-12-09
//

import Foundation

/// Handles slash commands (/commit, /test, /fix, etc.)
@MainActor
class SlashCommandHandler: ObservableObject {
    static let shared = SlashCommandHandler()

    @Published var isExecuting: Bool = false
    @Published var currentCommand: SlashCommand?

    private init() {}

    // MARK: - Command Execution

    /// Parses and executes a slash command
    /// - Parameter input: User input (e.g., "/commit" or "/test MyClass")
    /// - Returns: Command result
    func execute(_ input: String) async throws -> String {
        guard input.hasPrefix("/") else {
            throw SlashCommandError.notACommand
        }

        isExecuting = true
        defer { isExecuting = false }

        // Parse command
        let components = input.dropFirst().components(separatedBy: " ")
        guard let commandName = components.first else {
            throw SlashCommandError.invalidSyntax
        }

        let args = Array(components.dropFirst())

        // Find and execute command
        guard let command = SlashCommand.allCommands.first(where: { $0.name == commandName }) else {
            throw SlashCommandError.unknownCommand(commandName)
        }

        currentCommand = command
        return try await command.handler(args)
    }

    /// Gets command suggestions for input
    /// - Parameter input: Partial command
    /// - Returns: Matching commands
    func getSuggestions(for input: String) -> [SlashCommand] {
        guard input.hasPrefix("/") else { return [] }

        let query = String(input.dropFirst()).lowercased()
        if query.isEmpty {
            return SlashCommand.allCommands
        }

        return SlashCommand.allCommands.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }
}

// MARK: - Slash Commands

/// Available slash commands
struct SlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let usage: String
    let category: CommandCategory
    let handler: ([String]) async throws -> String

    enum CommandCategory: String {
        case git = "Git"
        case code = "Code"
        case project = "Project"
        case ai = "AI"
        case system = "System"
    }

    static var allCommands: [SlashCommand] {
        [
            // Git Commands
            SlashCommand(
                name: "commit",
                description: "Generate AI commit message from staged changes",
                usage: "/commit",
                category: .git,
                handler: commitHandler
            ),

            SlashCommand(
                name: "pr",
                description: "Generate pull request description",
                usage: "/pr [base-branch]",
                category: .git,
                handler: prHandler
            ),

            SlashCommand(
                name: "review",
                description: "AI code review of current changes",
                usage: "/review",
                category: .git,
                handler: reviewHandler
            ),

            // Code Commands
            SlashCommand(
                name: "test",
                description: "Generate tests for current file or selection",
                usage: "/test [file-path]",
                category: .code,
                handler: testHandler
            ),

            SlashCommand(
                name: "docs",
                description: "Generate documentation",
                usage: "/docs [file-path]",
                category: .code,
                handler: docsHandler
            ),

            SlashCommand(
                name: "refactor",
                description: "Suggest refactoring improvements",
                usage: "/refactor [file-path]",
                category: .code,
                handler: refactorHandler
            ),

            SlashCommand(
                name: "explain",
                description: "Explain selected code or file",
                usage: "/explain [file-path]",
                category: .code,
                handler: explainHandler
            ),

            SlashCommand(
                name: "optimize",
                description: "Optimize code for performance",
                usage: "/optimize [file-path]",
                category: .code,
                handler: optimizeHandler
            ),

            // Project Commands
            SlashCommand(
                name: "index",
                description: "Index current project for search",
                usage: "/index [project-path]",
                category: .project,
                handler: indexHandler
            ),

            SlashCommand(
                name: "search",
                description: "Search project semantically",
                usage: "/search <query>",
                category: .project,
                handler: searchHandler
            ),

            SlashCommand(
                name: "fix",
                description: "Build project and fix all errors",
                usage: "/fix",
                category: .project,
                handler: fixHandler
            ),

            // AI Commands
            SlashCommand(
                name: "plan",
                description: "Create execution plan for task",
                usage: "/plan <task description>",
                category: .ai,
                handler: planHandler
            ),

            SlashCommand(
                name: "agent",
                description: "Run autonomous agent on task",
                usage: "/agent <task>",
                category: .ai,
                handler: agentHandler
            ),

            // System Commands
            SlashCommand(
                name: "help",
                description: "Show all available commands",
                usage: "/help [command]",
                category: .system,
                handler: helpHandler
            ),

            SlashCommand(
                name: "clear",
                description: "Clear conversation history",
                usage: "/clear",
                category: .system,
                handler: clearHandler
            )
        ]
    }

    // MARK: - Command Handlers

    private static func commitHandler(_ args: [String]) async throws -> String {
        let repoPath = FileManager.default.currentDirectoryPath
        return try await GitAIService.shared.generateCommitMessage(repoPath: repoPath)
    }

    private static func prHandler(_ args: [String]) async throws -> String {
        let repoPath = FileManager.default.currentDirectoryPath
        let baseBranch = args.first ?? "main"
        let (title, description) = try await GitAIService.shared.generatePRDescription(
            repoPath: repoPath,
            baseBranch: baseBranch
        )
        return "**\(title)**\n\n\(description)"
    }

    private static func reviewHandler(_ args: [String]) async throws -> String {
        let repoPath = FileManager.default.currentDirectoryPath
        return try await GitAIService.shared.reviewChanges(repoPath: repoPath)
    }

    private static func testHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }

        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await SmartCodeActions.shared.generateTests(code, language: "swift")
    }

    private static func docsHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }

        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await SmartCodeActions.shared.generateDocumentation(code)
    }

    private static func refactorHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }

        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await SmartCodeActions.shared.refactorCode(code)
    }

    private static func explainHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }

        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await SmartCodeActions.shared.explainCode(code)
    }

    private static func optimizeHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }

        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await SmartCodeActions.shared.optimizeCode(code)
    }

    private static func indexHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? FileManager.default.currentDirectoryPath
        let count = try await CodebaseIndexer.shared.indexDirectory(projectPath)
        return "✅ Indexed \(count) files in \(projectPath)"
    }

    private static func searchHandler(_ args: [String]) async throws -> String {
        guard !args.isEmpty else {
            throw SlashCommandError.missingArgument("query")
        }

        let query = args.joined(separator: " ")
        let results = await CodebaseIndexer.shared.search(query, limit: 10)

        var output = "Found \(results.count) results for '\(query)':\n\n"
        for (file, score) in results {
            output += "• \(file.path) (score: \(String(format: "%.1f", score)))\n"
        }

        return output
    }

    private static func fixHandler(_ args: [String]) async throws -> String {
        return "Building project and fixing errors...\n(Feature coming soon)"
    }

    private static func planHandler(_ args: [String]) async throws -> String {
        guard !args.isEmpty else {
            throw SlashCommandError.missingArgument("task description")
        }

        let task = args.joined(separator: " ")

        let prompt = """
        Create a detailed execution plan for this task:

        \(task)

        Break it down into specific, actionable steps.
        For each step, specify what needs to be done and any files/commands involved.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func agentHandler(_ args: [String]) async throws -> String {
        guard !args.isEmpty else {
            throw SlashCommandError.missingArgument("task")
        }

        let task = args.joined(separator: " ")

        // TODO: Implement AutonomousAgent
        return """
        **Agent Mode** (Coming Soon)

        Task: \(task)

        Autonomous agent execution is not yet implemented.
        This feature will allow the LLM to independently execute multi-step tasks.
        """
    }

    private static func helpHandler(_ args: [String]) async throws -> String {
        if let commandName = args.first {
            // Help for specific command
            if let command = SlashCommand.allCommands.first(where: { $0.name == commandName }) {
                return """
                **\(command.name)** - \(command.description)

                Usage: \(command.usage)
                Category: \(command.category.rawValue)
                """
            } else {
                throw SlashCommandError.unknownCommand(commandName)
            }
        }

        // List all commands
        var help = "**Available Slash Commands:**\n\n"

        for category in [CommandCategory.git, .code, .project, .ai, .system] {
            let commands = SlashCommand.allCommands.filter { $0.category == category }
            if !commands.isEmpty {
                help += "**\(category.rawValue):**\n"
                for command in commands {
                    help += "  `/\(command.name)` - \(command.description)\n"
                }
                help += "\n"
            }
        }

        help += "Type `/help <command>` for detailed usage."
        return help
    }

    private static func clearHandler(_ args: [String]) async throws -> String {
        // Will be handled by ChatViewModel
        return "Conversation cleared"
    }
}

// MARK: - Errors

enum SlashCommandError: LocalizedError {
    case notACommand
    case invalidSyntax
    case unknownCommand(String)
    case missingArgument(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notACommand:
            return "Not a slash command"
        case .invalidSyntax:
            return "Invalid command syntax"
        case .unknownCommand(let name):
            return "Unknown command: /\(name)\n\nType /help to see available commands"
        case .missingArgument(let arg):
            return "Missing required argument: \(arg)"
        case .executionFailed(let details):
            return "Command failed: \(details)"
        }
    }
}
