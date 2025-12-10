//
//  GitAIService.swift
//  MLX Code
//
//  AI-powered Git operations
//  Created on 2025-12-09
//

import Foundation

/// AI-enhanced Git operations
actor GitAIService {
    static let shared = GitAIService()

    private init() {}

    // MARK: - Commit Message Generation

    /// Generates a commit message from git diff
    /// - Parameter repoPath: Path to git repository
    /// - Returns: Suggested commit message
    func generateCommitMessage(repoPath: String) async throws -> String {
        // Get git diff
        let diff = try await runGitCommand(["diff", "--cached"], in: repoPath)

        if diff.isEmpty {
            // No staged changes, check unstaged
            let unstagedDiff = try await runGitCommand(["diff"], in: repoPath)
            if unstagedDiff.isEmpty {
                throw GitAIError.noChanges
            }
        }

        // Generate commit message using MLX
        let prompt = """
        Based on this git diff, generate a concise commit message following conventional commits format:

        \(diff.prefix(2000))

        Generate a commit message in this format:
        <type>: <subject>

        <optional body>

        Types: feat, fix, docs, style, refactor, test, chore
        Keep subject under 50 characters.
        """

        let commitMessage = try await MLXService.shared.generate(prompt: prompt)
        return commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generates a PR description from commits
    /// - Parameters:
    ///   - repoPath: Path to repository
    ///   - baseBranch: Base branch (default: main)
    /// - Returns: PR title and description
    func generatePRDescription(repoPath: String, baseBranch: String = "main") async throws -> (title: String, description: String) {
        // Get commits since base branch
        let log = try await runGitCommand(["log", "\(baseBranch)..HEAD", "--pretty=format:%s"], in: repoPath)
        let diff = try await runGitCommand(["diff", "\(baseBranch)...HEAD"], in: repoPath)

        let prompt = """
        Generate a pull request title and description for these changes:

        Commits:
        \(log)

        Diff summary (first 3000 chars):
        \(diff.prefix(3000))

        Generate in this format:
        TITLE: <concise PR title>

        DESCRIPTION:
        ## Summary
        - <bullet point 1>
        - <bullet point 2>

        ## Changes
        - <change 1>
        - <change 2>

        ## Testing
        - <how to test>
        """

        let result = try await MLXService.shared.generate(prompt: prompt)

        // Parse result
        let lines = result.components(separatedBy: "\n")
        var title = ""
        var description = ""
        var inDescription = false

        for line in lines {
            if line.hasPrefix("TITLE:") {
                title = line.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("DESCRIPTION:") {
                inDescription = true
            } else if inDescription {
                description += line + "\n"
            }
        }

        return (title.isEmpty ? "Update" : title, description.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Explains a commit
    /// - Parameters:
    ///   - commitHash: Commit SHA
    ///   - repoPath: Repository path
    /// - Returns: Human-readable explanation
    func explainCommit(_ commitHash: String, repoPath: String) async throws -> String {
        let show = try await runGitCommand(["show", commitHash], in: repoPath)

        let prompt = """
        Explain this git commit in simple terms:

        \(show.prefix(2000))

        Provide:
        1. What changed
        2. Why it might have changed
        3. Potential impact
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    /// Performs AI code review on changes
    /// - Parameter repoPath: Repository path
    /// - Returns: Review comments
    func reviewChanges(repoPath: String) async throws -> String {
        let diff = try await runGitCommand(["diff"], in: repoPath)

        guard !diff.isEmpty else {
            throw GitAIError.noChanges
        }

        let prompt = """
        Review this code change for:
        - Potential bugs
        - Performance issues
        - Security vulnerabilities
        - Best practices
        - Memory leaks (for Swift/ObjC)

        Diff:
        \(diff.prefix(5000))

        Provide specific, actionable feedback.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Helper Methods

    private func runGitCommand(_ args: [String], in repoPath: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            throw GitAIError.gitCommandFailed(errorOutput)
        }

        return output
    }
}

// MARK: - Errors

enum GitAIError: LocalizedError {
    case noChanges
    case gitCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noChanges:
            return "No changes to process"
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}
