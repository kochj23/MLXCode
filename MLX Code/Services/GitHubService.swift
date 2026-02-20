//
//  GitHubService.swift
//  MLX Code
//
//  GitHub integration via gh CLI
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Service for GitHub operations using the gh CLI
actor GitHubService {
    /// Shared singleton instance
    static let shared = GitHubService()

    /// Path to gh CLI
    private let ghPath: String

    /// Command timeout (30 seconds)
    private let commandTimeout: TimeInterval = 30.0

    private init() {
        self.ghPath = GitHubService.findGhExecutable()
    }

    // MARK: - Repository Info

    /// Gets repository information
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Repository info
    func getRepoInfo(repoPath: String) async throws -> GitHubRepo {
        let output = try await executeGh(
            ["repo", "view", "--json", "name,owner,description,visibility,stargazerCount,forkCount,url,defaultBranchRef"],
            in: repoPath
        )

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubServiceError.parseError("Failed to parse repo info")
        }

        let ownerDict = json["owner"] as? [String: Any]
        let branchDict = json["defaultBranchRef"] as? [String: Any]

        return GitHubRepo(
            name: json["name"] as? String ?? "unknown",
            owner: ownerDict?["login"] as? String ?? "unknown",
            description: json["description"] as? String,
            visibility: json["visibility"] as? String ?? "PRIVATE",
            stars: json["stargazerCount"] as? Int ?? 0,
            forks: json["forkCount"] as? Int ?? 0,
            url: json["url"] as? String ?? "",
            defaultBranch: branchDict?["name"] as? String ?? "main"
        )
    }

    // MARK: - Issues

    /// Lists issues in the repository
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - state: Issue state filter (open, closed, all)
    ///   - limit: Maximum number of issues to return
    /// - Returns: Array of issues
    func listIssues(repoPath: String, state: String = "open", limit: Int = 30) async throws -> [GitHubIssue] {
        let output = try await executeGh(
            ["issue", "list", "--state", state, "--limit", "\(limit)", "--json", "number,title,state,author,labels,createdAt,updatedAt,body"],
            in: repoPath
        )

        guard let data = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.map { json in
            let authorDict = json["author"] as? [String: Any]
            let labelsArray = json["labels"] as? [[String: Any]] ?? []
            let labels = labelsArray.compactMap { $0["name"] as? String }

            return GitHubIssue(
                number: json["number"] as? Int ?? 0,
                title: json["title"] as? String ?? "",
                state: json["state"] as? String ?? "OPEN",
                author: authorDict?["login"] as? String ?? "unknown",
                labels: labels,
                body: json["body"] as? String,
                createdAt: json["createdAt"] as? String ?? "",
                updatedAt: json["updatedAt"] as? String ?? ""
            )
        }
    }

    /// Creates a new issue
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - title: Issue title
    ///   - body: Issue body
    ///   - labels: Labels to apply
    /// - Returns: Created issue number
    func createIssue(repoPath: String, title: String, body: String, labels: [String] = []) async throws -> Int {
        var args = ["issue", "create", "--title", title, "--body", body]
        if !labels.isEmpty {
            args.append(contentsOf: ["--label", labels.joined(separator: ",")])
        }

        let output = try await executeGh(args, in: repoPath)

        // Parse issue number from URL output
        if let range = output.range(of: #"/issues/(\d+)"#, options: .regularExpression),
           let numberStr = output[range].components(separatedBy: "/").last,
           let number = Int(numberStr) {
            return number
        }

        return 0
    }

    // MARK: - Pull Requests

    /// Lists pull requests
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - state: PR state filter (open, closed, merged, all)
    ///   - limit: Maximum number of PRs to return
    /// - Returns: Array of pull requests
    func listPullRequests(repoPath: String, state: String = "open", limit: Int = 30) async throws -> [GitHubPR] {
        let output = try await executeGh(
            ["pr", "list", "--state", state, "--limit", "\(limit)", "--json", "number,title,state,author,headRefName,baseRefName,createdAt,additions,deletions,isDraft"],
            in: repoPath
        )

        guard let data = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.map { json in
            let authorDict = json["author"] as? [String: Any]

            return GitHubPR(
                number: json["number"] as? Int ?? 0,
                title: json["title"] as? String ?? "",
                state: json["state"] as? String ?? "OPEN",
                author: authorDict?["login"] as? String ?? "unknown",
                headBranch: json["headRefName"] as? String ?? "",
                baseBranch: json["baseRefName"] as? String ?? "",
                createdAt: json["createdAt"] as? String ?? "",
                additions: json["additions"] as? Int ?? 0,
                deletions: json["deletions"] as? Int ?? 0,
                isDraft: json["isDraft"] as? Bool ?? false
            )
        }
    }

    /// Creates a pull request
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - title: PR title
    ///   - body: PR description
    ///   - base: Base branch
    ///   - head: Head branch (current branch if nil)
    /// - Returns: Created PR number
    func createPullRequest(repoPath: String, title: String, body: String, base: String = "main", head: String? = nil) async throws -> Int {
        var args = ["pr", "create", "--title", title, "--body", body, "--base", base]
        if let head = head {
            args.append(contentsOf: ["--head", head])
        }

        let output = try await executeGh(args, in: repoPath)

        if let range = output.range(of: #"/pull/(\d+)"#, options: .regularExpression),
           let numberStr = output[range].components(separatedBy: "/").last,
           let number = Int(numberStr) {
            return number
        }

        return 0
    }

    /// Gets detailed pull request info
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - number: PR number
    /// - Returns: PR details
    func getPullRequestDetails(repoPath: String, number: Int) async throws -> GitHubPR {
        let output = try await executeGh(
            ["pr", "view", "\(number)", "--json", "number,title,state,author,headRefName,baseRefName,createdAt,additions,deletions,isDraft,body,reviewDecision"],
            in: repoPath
        )

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubServiceError.parseError("Failed to parse PR details")
        }

        let authorDict = json["author"] as? [String: Any]

        return GitHubPR(
            number: json["number"] as? Int ?? number,
            title: json["title"] as? String ?? "",
            state: json["state"] as? String ?? "OPEN",
            author: authorDict?["login"] as? String ?? "unknown",
            headBranch: json["headRefName"] as? String ?? "",
            baseBranch: json["baseRefName"] as? String ?? "",
            createdAt: json["createdAt"] as? String ?? "",
            additions: json["additions"] as? Int ?? 0,
            deletions: json["deletions"] as? Int ?? 0,
            isDraft: json["isDraft"] as? Bool ?? false
        )
    }

    // MARK: - Branch Operations

    /// Lists branches (local + remote)
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Array of branches
    func listBranches(repoPath: String) async throws -> [GitHubBranch] {
        // Get local branches
        let localOutput = try await executeCommand(
            "/usr/bin/git", arguments: ["branch", "--format", "%(refname:short)|%(objectname:short)|%(upstream:short)"],
            in: repoPath
        )

        // Get current branch
        let currentBranch = try await executeCommand(
            "/usr/bin/git", arguments: ["branch", "--show-current"],
            in: repoPath
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var branches: [GitHubBranch] = []

        for line in localOutput.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            let name = parts.indices.contains(0) ? parts[0] : ""
            let commit = parts.indices.contains(1) ? parts[1] : ""
            let upstream = parts.indices.contains(2) ? parts[2] : ""

            guard !name.isEmpty else { continue }

            branches.append(GitHubBranch(
                name: name,
                isCurrent: name == currentBranch,
                lastCommit: commit,
                upstream: upstream.isEmpty ? nil : upstream
            ))
        }

        return branches
    }

    // MARK: - Push/Pull

    /// Pushes current branch to remote with credential scan
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - branch: Branch to push (current if nil)
    /// - Returns: Push result message
    func push(repoPath: String, branch: String? = nil) async throws -> String {
        // Run credential scan first
        let scanResult = try await scanForCredentials(repoPath: repoPath)
        guard scanResult.clean else {
            throw GitHubServiceError.credentialScanFailed(scanResult.findings)
        }

        var args = ["push", "-u", "origin"]
        if let branch = branch {
            args.append(branch)
        }

        let output = try await executeCommand("/usr/bin/git", arguments: args, in: repoPath)
        return output.isEmpty ? "Push successful" : output
    }

    /// Pulls latest changes from remote
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - branch: Branch to pull (current if nil)
    /// - Returns: Pull result message
    func pull(repoPath: String, branch: String? = nil) async throws -> String {
        var args = ["pull"]
        if let branch = branch {
            args.append(contentsOf: ["origin", branch])
        }

        let output = try await executeCommand("/usr/bin/git", arguments: args, in: repoPath)
        return output.isEmpty ? "Already up to date" : output
    }

    // MARK: - Security

    /// Scans the repository for exposed credentials
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Credential scan result
    func scanForCredentials(repoPath: String) async throws -> CredentialScanResult {
        let patterns = [
            "sk_live_[A-Za-z0-9]",
            "sk_test_[A-Za-z0-9]",
            "AKIA[A-Z0-9]{16}",
            "Bearer [A-Za-z0-9\\-._~+/]+=*",
            "eyJ[A-Za-z0-9\\-_]+\\.[A-Za-z0-9\\-_]+",
            "password\\s*=\\s*\"[^\"]+\"",
            "-----BEGIN (RSA |EC )?PRIVATE KEY-----"
        ]

        var findings: [String] = []

        for pattern in patterns {
            let args = ["-r", "-l", "--include=*.swift", "--include=*.m", "--include=*.h",
                        "--include=*.plist", "--include=*.json",
                        "-E", pattern, repoPath]

            let output = (try? await executeCommand("/usr/bin/grep", arguments: args, in: repoPath)) ?? ""

            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                let filename = (line as NSString).lastPathComponent
                // Skip test files and known false positives
                if filename.contains("Test") || filename.contains("test") ||
                   filename.contains("Example") || filename.contains("Mock") ||
                   line.contains("// pattern:") || line.contains("// regex:") {
                    continue
                }
                findings.append(line)
            }
        }

        return CredentialScanResult(clean: findings.isEmpty, findings: findings)
    }

    /// Checks if the repository has an MIT license
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Whether MIT license is present
    func checkLicense(repoPath: String) async throws -> LicenseCheckResult {
        let licensePaths = ["LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"]

        for filename in licensePaths {
            let path = (repoPath as NSString).appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: path) {
                let content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
                let hasMIT = content.lowercased().contains("mit license") || content.lowercased().contains("permission is hereby granted")
                return LicenseCheckResult(hasLicense: true, isMIT: hasMIT, path: path)
            }
        }

        return LicenseCheckResult(hasLicense: false, isMIT: false, path: nil)
    }

    // MARK: - Activity

    /// Gets recent repository activity
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - limit: Max items to return
    /// - Returns: Recent activity items
    func getRecentActivity(repoPath: String, limit: Int = 20) async throws -> [GitHubActivity] {
        let logOutput = try await executeCommand(
            "/usr/bin/git",
            arguments: ["log", "-\(limit)", "--pretty=format:%H|%an|%ad|%s", "--date=relative"],
            in: repoPath
        )

        return logOutput.components(separatedBy: .newlines).compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { return nil }

            return GitHubActivity(
                type: "commit",
                hash: String(parts[0].prefix(7)),
                author: parts[1],
                date: parts[2],
                description: parts[3]
            )
        }
    }

    /// Gets contributors for the repository
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Array of contributors
    func getContributors(repoPath: String) async throws -> [GitHubContributor] {
        let output = try await executeCommand(
            "/usr/bin/git",
            arguments: ["shortlog", "-sne", "HEAD"],
            in: repoPath
        )

        return output.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            // Format: "  123\tAuthor Name <email>"
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2 else { return nil }

            let commits = Int(parts[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let nameEmail = parts[1]

            var name = nameEmail
            var email: String?

            if let emailStart = nameEmail.range(of: "<"),
               let emailEnd = nameEmail.range(of: ">") {
                name = String(nameEmail[..<emailStart.lowerBound]).trimmingCharacters(in: .whitespaces)
                email = String(nameEmail[emailStart.upperBound..<emailEnd.lowerBound])
            }

            return GitHubContributor(name: name, email: email, commits: commits)
        }
    }

    // MARK: - Private Methods

    /// Executes a gh CLI command
    private func executeGh(_ arguments: [String], in repoPath: String) async throws -> String {
        return try await executeCommand(ghPath, arguments: arguments, in: repoPath)
    }

    /// Executes an arbitrary command
    private func executeCommand(_ executable: String, arguments: [String], in workingDirectory: String) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw GitHubServiceError.executionFailed(error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !errorOutput.isEmpty {
            // For grep, exit code 1 means no match - not an error
            if executable.hasSuffix("grep") && process.terminationStatus == 1 {
                return ""
            }
            throw GitHubServiceError.commandFailed(errorOutput)
        }

        return output
    }

    /// Finds the gh CLI executable
    private static func findGhExecutable() -> String {
        let paths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh"
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/opt/homebrew/bin/gh"
    }
}

// MARK: - Data Models

/// GitHub repository information
struct GitHubRepo {
    let name: String
    let owner: String
    let description: String?
    let visibility: String
    let stars: Int
    let forks: Int
    let url: String
    let defaultBranch: String

    var isPrivate: Bool { visibility == "PRIVATE" }
    var isPublic: Bool { visibility == "PUBLIC" }
}

/// GitHub issue
struct GitHubIssue: Identifiable {
    let number: Int
    let title: String
    let state: String
    let author: String
    let labels: [String]
    let body: String?
    let createdAt: String
    let updatedAt: String

    var id: Int { number }
    var isOpen: Bool { state == "OPEN" }
}

/// GitHub pull request
struct GitHubPR: Identifiable {
    let number: Int
    let title: String
    let state: String
    let author: String
    let headBranch: String
    let baseBranch: String
    let createdAt: String
    let additions: Int
    let deletions: Int
    let isDraft: Bool

    var id: Int { number }
    var isOpen: Bool { state == "OPEN" }
    var isMerged: Bool { state == "MERGED" }
}

/// GitHub branch
struct GitHubBranch: Identifiable {
    let name: String
    let isCurrent: Bool
    let lastCommit: String
    let upstream: String?

    var id: String { name }
    var hasUpstream: Bool { upstream != nil }
}

/// GitHub contributor
struct GitHubContributor: Identifiable {
    let name: String
    let email: String?
    let commits: Int

    var id: String { name }
}

/// GitHub activity item
struct GitHubActivity: Identifiable {
    let id = UUID()
    let type: String
    let hash: String
    let author: String
    let date: String
    let description: String
}

/// Credential scan result
struct CredentialScanResult {
    let clean: Bool
    let findings: [String]
}

/// License check result
struct LicenseCheckResult {
    let hasLicense: Bool
    let isMIT: Bool
    let path: String?
}

// MARK: - Errors

/// Errors from GitHub service operations
enum GitHubServiceError: LocalizedError {
    case ghNotInstalled
    case executionFailed(String)
    case commandFailed(String)
    case parseError(String)
    case credentialScanFailed([String])
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .ghNotInstalled:
            return "GitHub CLI (gh) is not installed. Install with: brew install gh"
        case .executionFailed(let message):
            return "Failed to execute gh: \(message)"
        case .commandFailed(let output):
            return "GitHub command failed: \(output)"
        case .parseError(let message):
            return "Failed to parse GitHub response: \(message)"
        case .credentialScanFailed(let findings):
            return "Credential scan found \(findings.count) potential secret(s). Fix before pushing."
        case .notAuthenticated:
            return "Not authenticated with GitHub. Run: gh auth login"
        }
    }
}
