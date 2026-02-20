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

            // Build & Deploy Commands
            SlashCommand(
                name: "build",
                description: "Build the current Xcode project",
                usage: "/build [scheme]",
                category: .project,
                handler: buildHandler
            ),

            SlashCommand(
                name: "deploy",
                description: "Full pipeline: build, archive, DMG, install, export",
                usage: "/deploy [scheme]",
                category: .project,
                handler: deployHandler
            ),

            SlashCommand(
                name: "archive",
                description: "Archive the current Xcode project",
                usage: "/archive [scheme]",
                category: .project,
                handler: archiveHandler
            ),

            // GitHub Commands
            SlashCommand(
                name: "github",
                description: "Show GitHub repository overview",
                usage: "/github [repo-path]",
                category: .git,
                handler: githubHandler
            ),

            SlashCommand(
                name: "issues",
                description: "List open GitHub issues",
                usage: "/issues [state]",
                category: .git,
                handler: issuesHandler
            ),

            SlashCommand(
                name: "prs",
                description: "List open pull requests",
                usage: "/prs [state]",
                category: .git,
                handler: prsHandler
            ),

            SlashCommand(
                name: "push",
                description: "Push with credential scan",
                usage: "/push [branch]",
                category: .git,
                handler: pushHandler
            ),

            // Analysis Commands
            SlashCommand(
                name: "analyze",
                description: "Run full code analysis",
                usage: "/analyze [project-path]",
                category: .code,
                handler: analyzeHandler
            ),

            SlashCommand(
                name: "metrics",
                description: "Show code metrics",
                usage: "/metrics",
                category: .code,
                handler: metricsHandler
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
        let message = try await GitService.shared.generateCommitMessage(in: repoPath)
        return message
    }

    private static func prHandler(_ args: [String]) async throws -> String {
        return "Use git and the model to generate PR descriptions via chat."
    }

    private static func reviewHandler(_ args: [String]) async throws -> String {
        let repoPath = FileManager.default.currentDirectoryPath
        let staged = try await GitService.shared.getStagedChanges(in: repoPath)
        let unstaged = try await GitService.shared.getUnstagedChanges(in: repoPath)
        let diff = staged.isEmpty ? unstaged : staged
        let prompt = "Review these code changes and identify any issues:\n\n\(diff)"
        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func testHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }
        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        let prompt = "Generate unit tests for this Swift code:\n\n```swift\n\(code)\n```"
        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func docsHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }
        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        let prompt = "Generate documentation for this code:\n\n```swift\n\(code)\n```"
        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func refactorHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }
        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        let prompt = "Suggest refactoring improvements for this code:\n\n```swift\n\(code)\n```"
        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func explainHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }
        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        let prompt = "Explain what this code does:\n\n```swift\n\(code)\n```"
        return try await MLXService.shared.generate(prompt: prompt)
    }

    private static func optimizeHandler(_ args: [String]) async throws -> String {
        guard let filePath = args.first else {
            throw SlashCommandError.missingArgument("file-path")
        }
        let code = try String(contentsOfFile: filePath, encoding: .utf8)
        let prompt = "Optimize this code for performance:\n\n```swift\n\(code)\n```"
        return try await MLXService.shared.generate(prompt: prompt)
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

    // MARK: - Build & Deploy Handlers

    private static func buildHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? "/Volumes/Data/xcode/MLX Code/MLX Code.xcodeproj"
        let xcodeService = XcodeService.shared
        try await xcodeService.setProject(path: projectPath)

        let scheme = args.count > 1 ? args[1] : nil
        let result = try await xcodeService.build(scheme: scheme, configuration: "Debug")

        if result.succeeded {
            return "Build succeeded (\(result.warnings) warnings)"
        } else {
            return "Build FAILED (\(result.errors) errors, \(result.warnings) warnings)"
        }
    }

    private static func deployHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? "/Volumes/Data/xcode/MLX Code/MLX Code.xcodeproj"
        let xcodeService = XcodeService.shared
        try await xcodeService.setProject(path: projectPath)

        let scheme = args.count > 1 ? args[1] : ((projectPath as NSString).lastPathComponent as NSString).deletingPathExtension

        let result = try await xcodeService.fullBuildPipeline(scheme: scheme, configuration: "Release")

        var output = """
        Deploy Complete:
          Version: v\(result.version) build \(result.build)
          Build: \(result.buildResult.succeeded ? "SUCCESS" : "FAILED")
          DMG: \(result.dmgPath)
          Installed: \(result.installedPath)
        """

        if let local = result.exportResult.localBinaryPath {
            output += "\n  Local Binary: \(local)"
        }
        if let nas = result.exportResult.nasBinaryPath {
            output += "\n  NAS Binary: \(nas)"
        }

        return output
    }

    private static func archiveHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? "/Volumes/Data/xcode/MLX Code/MLX Code.xcodeproj"
        let xcodeService = XcodeService.shared
        try await xcodeService.setProject(path: projectPath)

        let scheme = args.count > 1 ? args[1] : ((projectPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let result = try await xcodeService.archive(scheme: scheme)

        return "Archive created: \(result.archivePath)\nVersion: v\(result.version) build \(result.build)"
    }

    // MARK: - GitHub Handlers

    private static func githubHandler(_ args: [String]) async throws -> String {
        let repoPath = args.first ?? "/Volumes/Data/xcode/MLX Code"

        do {
            let info = try await GitHubService.shared.getRepoInfo(repoPath: repoPath)
            return """
            Repository: \(info.owner)/\(info.name)
            Visibility: \(info.visibility)
            Stars: \(info.stars) | Forks: \(info.forks)
            Default Branch: \(info.defaultBranch)
            URL: \(info.url)
            """
        } catch {
            return "GitHub error: \(error.localizedDescription)"
        }
    }

    private static func issuesHandler(_ args: [String]) async throws -> String {
        let state = args.first ?? "open"
        let repoPath = "/Volumes/Data/xcode/MLX Code"

        let issues = try await GitHubService.shared.listIssues(repoPath: repoPath, state: state)

        if issues.isEmpty {
            return "No \(state) issues."
        }

        var output = "Issues (\(state)):\n"
        for issue in issues {
            output += "  #\(issue.number) \(issue.title) by @\(issue.author)\n"
        }
        return output
    }

    private static func prsHandler(_ args: [String]) async throws -> String {
        let state = args.first ?? "open"
        let repoPath = "/Volumes/Data/xcode/MLX Code"

        let prs = try await GitHubService.shared.listPullRequests(repoPath: repoPath, state: state)

        if prs.isEmpty {
            return "No \(state) pull requests."
        }

        var output = "Pull Requests (\(state)):\n"
        for pr in prs {
            output += "  #\(pr.number) \(pr.title) (\(pr.headBranch) -> \(pr.baseBranch))\n"
        }
        return output
    }

    private static func pushHandler(_ args: [String]) async throws -> String {
        let branch = args.first
        let repoPath = "/Volumes/Data/xcode/MLX Code"

        return try await GitHubService.shared.push(repoPath: repoPath, branch: branch)
    }

    // MARK: - Analysis Handlers

    private static func analyzeHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? "/Volumes/Data/xcode/MLX Code"
        _ = try await ContextAnalysisService.shared.detectActiveProject(from: projectPath)

        var sections: [String] = ["Full Project Analysis"]

        if let metrics = try? await ContextAnalysisService.shared.getCodeMetrics() {
            sections.append("Files: \(metrics.totalFiles) | Lines: \(metrics.totalLines) | Code: \(metrics.codeLines)")
        }

        if let deps = try? await ContextAnalysisService.shared.getFrameworkDependencies(), !deps.isEmpty {
            sections.append("Dependencies: \(deps.map(\.name).joined(separator: ", "))")
        }

        if let violations = try? await ContextAnalysisService.shared.runSwiftLint(), !violations.isEmpty {
            let errors = violations.filter { $0.isError }.count
            let warnings = violations.filter { $0.isWarning }.count
            sections.append("SwiftLint: \(errors) errors, \(warnings) warnings")
        }

        return sections.joined(separator: "\n")
    }

    private static func metricsHandler(_ args: [String]) async throws -> String {
        let projectPath = args.first ?? "/Volumes/Data/xcode/MLX Code"
        _ = try await ContextAnalysisService.shared.detectActiveProject(from: projectPath)

        let metrics = try await ContextAnalysisService.shared.getCodeMetrics()

        var output = """
        Code Metrics:
          Total Files: \(metrics.totalFiles)
          Total Lines: \(metrics.totalLines)
          Code Lines: \(metrics.codeLines)
          Comment Lines: \(metrics.commentLines)
          Blank Lines: \(metrics.blankLines)
        """

        if !metrics.largestFiles.isEmpty {
            output += "\n\nLargest Files:"
            for file in metrics.largestFiles.prefix(5) {
                output += "\n  \(file.name): \(file.lines) lines"
            }
        }

        return output
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
