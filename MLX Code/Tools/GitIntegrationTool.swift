//
//  GitIntegrationTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for Git version control operations
class GitIntegrationTool: BaseTool {
    init() {
        super.init(
            name: "git",
            description: """
            Git version control operations: status, diff, commit, push, pull, branch management, history, and more.
            Can generate AI-powered commit messages based on staged changes.
            """,
            parameters: ToolParameterSchema(
                
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Git operation to perform",
                        enum: ["status", "diff", "add", "commit", "push", "pull", "log", "branch", "checkout", "merge", "blame", "stash"]
                    ),
                    "files": ParameterProperty(
                        type: "array",
                        description: "Files to add/stage (for 'add' operation)"
                    ),
                    "message": ParameterProperty(
                        type: "string",
                        description: "Commit message (for 'commit' operation)"
                    ),
                    "branch": ParameterProperty(
                        type: "string",
                        description: "Branch name (for 'branch' or 'checkout' operation)"
                    ),
                    "generate_message": ParameterProperty(
                        type: "boolean",
                        description: "Auto-generate commit message from changes (default: false)"
                    ),
                    "limit": ParameterProperty(
                        type: "integer",
                        description: "Number of log entries to show (default: 10)"
                    ),
                    "file_path": ParameterProperty(
                        type: "string",
                        description: "File path for blame or specific operations"
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
        case "status":
            return try await gitStatus(context: context)
        case "diff":
            return try await gitDiff(parameters: parameters, context: context)
        case "add":
            return try await gitAdd(parameters: parameters, context: context)
        case "commit":
            return try await gitCommit(parameters: parameters, context: context)
        case "push":
            return try await gitPush(context: context)
        case "pull":
            return try await gitPull(context: context)
        case "log":
            return try await gitLog(parameters: parameters, context: context)
        case "branch":
            return try await gitBranch(parameters: parameters, context: context)
        case "checkout":
            return try await gitCheckout(parameters: parameters, context: context)
        case "merge":
            return try await gitMerge(parameters: parameters, context: context)
        case "blame":
            return try await gitBlame(parameters: parameters, context: context)
        case "stash":
            return try await gitStash(parameters: parameters, context: context)
        default:
            throw ToolError.missingParameter("Invalid git operation: \(operation)")
        }
    }

    // MARK: - Git Operations

    private func gitStatus(context: ToolContext) async throws -> ToolResult {
        let output = try await runGitCommand("status --porcelain -b", in: context.workingDirectory)

        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var branch = "unknown"
        var modified: [String] = []
        var added: [String] = []
        var deleted: [String] = []
        var untracked: [String] = []

        for line in lines {
            if line.hasPrefix("##") {
                branch = line.replacingOccurrences(of: "## ", with: "").components(separatedBy: "...").first ?? "unknown"
            } else {
                let status = String(line.prefix(2))
                let file = String(line.dropFirst(3))

                switch status {
                case " M", "M ", "MM":
                    modified.append(file)
                case "A ", " A":
                    added.append(file)
                case " D", "D ":
                    deleted.append(file)
                case "??":
                    untracked.append(file)
                default:
                    modified.append(file)
                }
            }
        }

        var result = "# Git Status\n\n"
        result += "**Branch**: \(branch)\n\n"

        if !modified.isEmpty {
            result += "## Modified (\(modified.count))\n"
            for file in modified {
                result += "- 📝 \(file)\n"
            }
            result += "\n"
        }

        if !added.isEmpty {
            result += "## Staged (\(added.count))\n"
            for file in added {
                result += "- ✅ \(file)\n"
            }
            result += "\n"
        }

        if !deleted.isEmpty {
            result += "## Deleted (\(deleted.count))\n"
            for file in deleted {
                result += "- ❌ \(file)\n"
            }
            result += "\n"
        }

        if !untracked.isEmpty {
            result += "## Untracked (\(untracked.count))\n"
            for file in untracked.prefix(10) {
                result += "- ❔ \(file)\n"
            }
            if untracked.count > 10 {
                result += "*... and \(untracked.count - 10) more*\n"
            }
        }

        return .success(result, metadata: [
            "branch": branch,
            "modified": modified.count,
            "staged": added.count
        ])
    }

    private func gitDiff(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let filePath = parameters["file_path"] as? String
        let command = filePath != nil ? "diff \(filePath!)" : "diff"

        let output = try await runGitCommand(command, in: context.workingDirectory)

        var result = "# Git Diff\n\n"

        if output.isEmpty {
            result += "*No changes*\n"
        } else {
            result += "```diff\n\(output.prefix(2000))\n```\n"
            if output.count > 2000 {
                result += "\n*... diff truncated (showing first 2000 chars)*\n"
            }
        }

        return .success(result)
    }

    private func gitAdd(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let files = parameters["files"] as? [String] ?? ["."]
        let filesStr = files.joined(separator: " ")

        _ = try await runGitCommand("add \(filesStr)", in: context.workingDirectory)

        var result = "# Files Staged\n\n"
        for file in files {
            result += "- ✅ \(file)\n"
        }

        return .success(result)
    }

    private func gitCommit(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var message = parameters["message"] as? String
        let generateMessage = parameters["generate_message"] as? Bool ?? false

        if generateMessage || message == nil {
            // Generate commit message from diff
            let diff = try await runGitCommand("diff --cached", in: context.workingDirectory)
            message = generateCommitMessage(from: diff)
        }

        guard let commitMessage = message, !commitMessage.isEmpty else {
            throw ToolError.missingParameter("Commit message is required")
        }

        let escapedMessage = commitMessage.replacingOccurrences(of: "\"", with: "\\\"")
        _ = try await runGitCommand("commit -m \"\(escapedMessage)\"", in: context.workingDirectory)

        var result = "# Commit Created\n\n"
        result += "**Message**:\n```\n\(commitMessage)\n```\n\n"
        result += "✅ Changes committed successfully\n"

        return .success(result)
    }

    private func gitPush(context: ToolContext) async throws -> ToolResult {
        let output = try await runGitCommand("push", in: context.workingDirectory)

        var result = "# Push Complete\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitPull(context: ToolContext) async throws -> ToolResult {
        let output = try await runGitCommand("pull", in: context.workingDirectory)

        var result = "# Pull Complete\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitLog(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let limit = parameters["limit"] as? Int ?? 10
        let output = try await runGitCommand("log --oneline -n \(limit)", in: context.workingDirectory)

        var result = "# Git Log (last \(limit) commits)\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitBranch(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let branchName = parameters["branch"] as? String

        let command = branchName != nil ? "branch \(branchName!)" : "branch -a"
        let output = try await runGitCommand(command, in: context.workingDirectory)

        var result = "# Git Branches\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitCheckout(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let branch = parameters["branch"] as? String else {
            throw ToolError.missingParameter("Branch name required for checkout")
        }

        let output = try await runGitCommand("checkout \(branch)", in: context.workingDirectory)

        var result = "# Checked Out Branch\n\n"
        result += "**Branch**: \(branch)\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitMerge(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let branch = parameters["branch"] as? String else {
            throw ToolError.missingParameter("Branch name required for merge")
        }

        let output = try await runGitCommand("merge \(branch)", in: context.workingDirectory)

        var result = "# Merge Complete\n\n"
        result += "**Merged**: \(branch) into current branch\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    private func gitBlame(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] as? String else {
            throw ToolError.missingParameter("file_path required for blame")
        }

        let output = try await runGitCommand("blame \(filePath)", in: context.workingDirectory)

        var result = "# Git Blame\n\n"
        result += "**File**: \(filePath)\n\n"
        result += "```\n\(output.prefix(1000))\n```\n"

        return .success(result)
    }

    private func gitStash(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let output = try await runGitCommand("stash", in: context.workingDirectory)

        var result = "# Changes Stashed\n\n"
        result += "```\n\(output)\n```\n"

        return .success(result)
    }

    // MARK: - Helper Methods

    private func runGitCommand(_ command: String, in directory: String) async throws -> String {
        let fullCommand = "cd \"\(directory)\" && git \(command) 2>&1"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", fullCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !output.isEmpty && output.contains("fatal") {
            throw ToolError.executionFailed("Git command failed: \(output)")
        }

        return output
    }

    private func generateCommitMessage(from diff: String) -> String {
        // Analyze diff and generate semantic commit message
        let lines = diff.components(separatedBy: .newlines)

        var addedLines = 0
        var deletedLines = 0
        var modifiedFiles: Set<String> = []

        for line in lines {
            if line.hasPrefix("+++ b/") {
                let file = String(line.dropFirst(6))
                modifiedFiles.insert(file)
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                addedLines += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletedLines += 1
            }
        }

        // Generate simple commit message based on changes
        var message = ""

        if modifiedFiles.count == 1, let file = modifiedFiles.first {
            let fileName = (file as NSString).lastPathComponent
            message = "Update \(fileName)"
        } else if modifiedFiles.count > 1 {
            message = "Update \(modifiedFiles.count) files"
        } else {
            message = "Update project files"
        }

        message += "\n\n"
        message += "- Modified \(modifiedFiles.count) file(s)\n"
        message += "- Added \(addedLines) line(s)\n"
        message += "- Deleted \(deletedLines) line(s)\n"

        return message
    }
}
