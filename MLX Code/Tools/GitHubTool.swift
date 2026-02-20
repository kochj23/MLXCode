//
//  GitHubTool.swift
//  MLX Code
//
//  LLM tool for GitHub operations via gh CLI
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Tool for GitHub operations (issues, PRs, branches, push/pull)
class GitHubTool: BaseTool {

    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "GitHub operation to perform",
                    enum: [
                        "repo_info", "list_issues", "create_issue",
                        "list_prs", "create_pr", "pr_details",
                        "push", "pull", "list_branches",
                        "contributors", "activity",
                        "scan_credentials", "check_license"
                    ]
                ),
                "repo_path": ParameterProperty(
                    type: "string",
                    description: "Path to the git repository (defaults to current project)"
                ),
                "title": ParameterProperty(
                    type: "string",
                    description: "Title for issue or PR creation"
                ),
                "body": ParameterProperty(
                    type: "string",
                    description: "Body/description for issue or PR creation"
                ),
                "state": ParameterProperty(
                    type: "string",
                    description: "Filter state: open, closed, merged, all (default: open)",
                    enum: ["open", "closed", "merged", "all"]
                ),
                "number": ParameterProperty(
                    type: "integer",
                    description: "Issue or PR number for detail views"
                ),
                "branch": ParameterProperty(
                    type: "string",
                    description: "Branch name for push/pull operations"
                ),
                "base": ParameterProperty(
                    type: "string",
                    description: "Base branch for PR creation (default: main)"
                ),
                "labels": ParameterProperty(
                    type: "string",
                    description: "Comma-separated labels for issue creation"
                )
            ],
            required: ["operation"]
        )

        super.init(
            name: "github",
            description: "GitHub operations: issues, PRs, branches, push/pull, credential scanning, license checks",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        try validateParameters(parameters, required: ["operation"])

        let operationStr = try stringParameter(parameters, key: "operation")
        let repoPath = resolveRepoPath(parameters: parameters, context: context)

        switch operationStr {
        case "repo_info":
            return try await repoInfo(repoPath: repoPath)

        case "list_issues":
            let state = (try? stringParameter(parameters, key: "state")) ?? "open"
            return try await listIssues(repoPath: repoPath, state: state)

        case "create_issue":
            let title = try stringParameter(parameters, key: "title")
            let body = (try? stringParameter(parameters, key: "body")) ?? ""
            let labelsStr = (try? stringParameter(parameters, key: "labels")) ?? ""
            let labels = labelsStr.isEmpty ? [] : labelsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return try await createIssue(repoPath: repoPath, title: title, body: body, labels: labels)

        case "list_prs":
            let state = (try? stringParameter(parameters, key: "state")) ?? "open"
            return try await listPRs(repoPath: repoPath, state: state)

        case "create_pr":
            let title = try stringParameter(parameters, key: "title")
            let body = (try? stringParameter(parameters, key: "body")) ?? ""
            let base = (try? stringParameter(parameters, key: "base")) ?? "main"
            return try await createPR(repoPath: repoPath, title: title, body: body, base: base)

        case "pr_details":
            let numberStr = try stringParameter(parameters, key: "number")
            guard let number = Int(numberStr) else {
                return .failure("Invalid PR number: \(numberStr)")
            }
            return try await prDetails(repoPath: repoPath, number: number)

        case "push":
            let branch = try? stringParameter(parameters, key: "branch")
            return try await push(repoPath: repoPath, branch: branch)

        case "pull":
            let branch = try? stringParameter(parameters, key: "branch")
            return try await pull(repoPath: repoPath, branch: branch)

        case "list_branches":
            return try await listBranches(repoPath: repoPath)

        case "contributors":
            return try await contributors(repoPath: repoPath)

        case "activity":
            return try await activity(repoPath: repoPath)

        case "scan_credentials":
            return try await scanCredentials(repoPath: repoPath)

        case "check_license":
            return try await checkLicense(repoPath: repoPath)

        default:
            return .failure("Unknown GitHub operation: \(operationStr)")
        }
    }

    // MARK: - Operation Implementations

    private func repoInfo(repoPath: String) async throws -> ToolResult {
        let info = try await GitHubService.shared.getRepoInfo(repoPath: repoPath)
        let output = """
        Repository: \(info.owner)/\(info.name)
        Visibility: \(info.visibility)
        Stars: \(info.stars) | Forks: \(info.forks)
        Default Branch: \(info.defaultBranch)
        URL: \(info.url)
        Description: \(info.description ?? "None")
        """
        return .success(output)
    }

    private func listIssues(repoPath: String, state: String) async throws -> ToolResult {
        let issues = try await GitHubService.shared.listIssues(repoPath: repoPath, state: state)

        if issues.isEmpty {
            return .success("No \(state) issues found.")
        }

        var output = "Issues (\(state)):\n"
        for issue in issues {
            let labels = issue.labels.isEmpty ? "" : " [\(issue.labels.joined(separator: ", "))]"
            output += "  #\(issue.number) \(issue.title)\(labels) by @\(issue.author)\n"
        }
        return .success(output, metadata: ["count": issues.count])
    }

    private func createIssue(repoPath: String, title: String, body: String, labels: [String]) async throws -> ToolResult {
        let number = try await GitHubService.shared.createIssue(repoPath: repoPath, title: title, body: body, labels: labels)
        return .success("Created issue #\(number): \(title)")
    }

    private func listPRs(repoPath: String, state: String) async throws -> ToolResult {
        let prs = try await GitHubService.shared.listPullRequests(repoPath: repoPath, state: state)

        if prs.isEmpty {
            return .success("No \(state) pull requests found.")
        }

        var output = "Pull Requests (\(state)):\n"
        for pr in prs {
            let draft = pr.isDraft ? " [DRAFT]" : ""
            output += "  #\(pr.number) \(pr.title)\(draft) (\(pr.headBranch) -> \(pr.baseBranch)) +\(pr.additions)/-\(pr.deletions)\n"
        }
        return .success(output, metadata: ["count": prs.count])
    }

    private func createPR(repoPath: String, title: String, body: String, base: String) async throws -> ToolResult {
        let number = try await GitHubService.shared.createPullRequest(repoPath: repoPath, title: title, body: body, base: base)
        return .success("Created PR #\(number): \(title)")
    }

    private func prDetails(repoPath: String, number: Int) async throws -> ToolResult {
        let pr = try await GitHubService.shared.getPullRequestDetails(repoPath: repoPath, number: number)
        let output = """
        PR #\(pr.number): \(pr.title)
        State: \(pr.state)\(pr.isDraft ? " (Draft)" : "")
        Author: @\(pr.author)
        Branch: \(pr.headBranch) -> \(pr.baseBranch)
        Changes: +\(pr.additions) / -\(pr.deletions)
        Created: \(pr.createdAt)
        """
        return .success(output)
    }

    private func push(repoPath: String, branch: String?) async throws -> ToolResult {
        let result = try await GitHubService.shared.push(repoPath: repoPath, branch: branch)
        return .success(result)
    }

    private func pull(repoPath: String, branch: String?) async throws -> ToolResult {
        let result = try await GitHubService.shared.pull(repoPath: repoPath, branch: branch)
        return .success(result)
    }

    private func listBranches(repoPath: String) async throws -> ToolResult {
        let branches = try await GitHubService.shared.listBranches(repoPath: repoPath)

        var output = "Branches:\n"
        for branch in branches {
            let current = branch.isCurrent ? " *" : ""
            let upstream = branch.hasUpstream ? " -> \(branch.upstream!)" : " (no upstream)"
            output += "  \(branch.name)\(current)\(upstream) [\(branch.lastCommit)]\n"
        }
        return .success(output, metadata: ["count": branches.count])
    }

    private func contributors(repoPath: String) async throws -> ToolResult {
        let contribs = try await GitHubService.shared.getContributors(repoPath: repoPath)

        var output = "Contributors:\n"
        for contrib in contribs {
            output += "  \(contrib.name) - \(contrib.commits) commits\n"
        }
        return .success(output, metadata: ["count": contribs.count])
    }

    private func activity(repoPath: String) async throws -> ToolResult {
        let activities = try await GitHubService.shared.getRecentActivity(repoPath: repoPath)

        var output = "Recent Activity:\n"
        for item in activities {
            output += "  [\(item.hash)] \(item.description) by \(item.author) (\(item.date))\n"
        }
        return .success(output, metadata: ["count": activities.count])
    }

    private func scanCredentials(repoPath: String) async throws -> ToolResult {
        let result = try await GitHubService.shared.scanForCredentials(repoPath: repoPath)

        if result.clean {
            return .success("Credential scan: CLEAN - No secrets found.")
        } else {
            var output = "WARNING: Potential secrets found (\(result.findings.count)):\n"
            for finding in result.findings.prefix(20) {
                output += "  \(finding)\n"
            }
            return .failure(output)
        }
    }

    private func checkLicense(repoPath: String) async throws -> ToolResult {
        let result = try await GitHubService.shared.checkLicense(repoPath: repoPath)

        if result.hasLicense {
            if result.isMIT {
                return .success("License: MIT License found at \(result.path ?? "unknown")")
            } else {
                return .success("License found at \(result.path ?? "unknown") but is NOT MIT. Public repos require MIT license.")
            }
        } else {
            return .failure("No license file found. Public repos MUST have an MIT license.")
        }
    }

    // MARK: - Helpers

    private func resolveRepoPath(parameters: [String: Any], context: ToolContext) -> String {
        if let path = try? stringParameter(parameters, key: "repo_path") {
            if path.hasPrefix("/") { return path }
            if path.hasPrefix("~/") { return (path as NSString).expandingTildeInPath }
            return (context.workingDirectory as NSString).appendingPathComponent(path)
        }

        if let projectPath = context.projectPath {
            // Get the directory containing the project
            return (projectPath as NSString).deletingLastPathComponent
        }

        return context.workingDirectory
    }
}
