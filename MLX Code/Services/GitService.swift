//
//  GitService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Actor-based service for Git operations
/// Provides thread-safe Git command execution with input validation
actor GitService {
    /// Shared instance
    static let shared = GitService()

    /// Git executable path
    private let gitPath: String

    /// Maximum output size (10MB)
    private let maxOutputSize = 10 * 1024 * 1024

    /// Timeout for Git commands (30 seconds)
    private let commandTimeout: TimeInterval = 30.0

    /// Initializes the Git service
    /// Validates that Git is available
    private init() {
        // Find git executable
        self.gitPath = GitService.findGitExecutable()
    }

    // MARK: - Public Methods

    /// Gets the current Git repository status
    /// - Parameter repositoryPath: Path to the Git repository
    /// - Returns: Git status information
    /// - Throws: GitError if operation fails
    func getStatus(in repositoryPath: String) async throws -> GitStatus {
        let validatedPath = try validateRepositoryPath(repositoryPath)

        // Run git status --porcelain to get machine-readable output
        let output = try await executeGitCommand(
            ["status", "--porcelain", "--branch"],
            in: validatedPath
        )

        return parseGitStatus(output)
    }

    /// Gets staged changes
    /// - Parameter repositoryPath: Path to the Git repository
    /// - Returns: Diff of staged changes
    /// - Throws: GitError if operation fails
    func getStagedChanges(in repositoryPath: String) async throws -> String {
        let validatedPath = try validateRepositoryPath(repositoryPath)

        // Run git diff --staged to get staged changes
        let output = try await executeGitCommand(
            ["diff", "--staged"],
            in: validatedPath
        )

        return output
    }

    /// Gets unstaged changes
    /// - Parameter repositoryPath: Path to the Git repository
    /// - Returns: Diff of unstaged changes
    /// - Throws: GitError if operation fails
    func getUnstagedChanges(in repositoryPath: String) async throws -> String {
        let validatedPath = try validateRepositoryPath(repositoryPath)

        // Run git diff to get unstaged changes
        let output = try await executeGitCommand(
            ["diff"],
            in: validatedPath
        )

        return output
    }

    /// Gets recent commit log
    /// - Parameters:
    ///   - repositoryPath: Path to the Git repository
    ///   - count: Number of commits to retrieve (default: 10)
    /// - Returns: Array of commit information
    /// - Throws: GitError if operation fails
    func getLog(in repositoryPath: String, count: Int = 10) async throws -> [GitCommit] {
        let validatedPath = try validateRepositoryPath(repositoryPath)
        let validatedCount = min(max(count, 1), 100) // Limit to 1-100

        // Run git log with formatted output
        let output = try await executeGitCommand(
            ["log", "-\(validatedCount)", "--pretty=format:%H|%an|%ae|%ad|%s", "--date=iso"],
            in: validatedPath
        )

        return parseGitLog(output)
    }

    /// Creates a commit with the given message
    /// - Parameters:
    ///   - message: Commit message
    ///   - repositoryPath: Path to the Git repository
    /// - Throws: GitError if operation fails
    func commit(message: String, in repositoryPath: String) async throws {
        let validatedPath = try validateRepositoryPath(repositoryPath)
        let validatedMessage = try validateCommitMessage(message)

        // Run git commit with validated message
        let _ = try await executeGitCommand(
            ["commit", "-m", validatedMessage],
            in: validatedPath
        )
    }

    /// Stages files for commit
    /// - Parameters:
    ///   - files: Files to stage (relative to repository root)
    ///   - repositoryPath: Path to the Git repository
    /// - Throws: GitError if operation fails
    func stageFiles(_ files: [String], in repositoryPath: String) async throws {
        let validatedPath = try validateRepositoryPath(repositoryPath)
        let validatedFiles = try validateFilePaths(files)

        guard !validatedFiles.isEmpty else {
            throw GitError.invalidInput("No valid files to stage")
        }

        // Run git add for each file
        var args = ["add"]
        args.append(contentsOf: validatedFiles)

        let _ = try await executeGitCommand(args, in: validatedPath)
    }

    /// Creates a new branch
    /// - Parameters:
    ///   - name: Branch name
    ///   - repositoryPath: Path to the Git repository
    ///   - checkout: Whether to checkout the new branch (default: true)
    /// - Throws: GitError if operation fails
    func createBranch(name: String, in repositoryPath: String, checkout: Bool = true) async throws {
        let validatedPath = try validateRepositoryPath(repositoryPath)
        let validatedName = try validateBranchName(name)

        if checkout {
            // Run git checkout -b to create and switch to new branch
            let _ = try await executeGitCommand(
                ["checkout", "-b", validatedName],
                in: validatedPath
            )
        } else {
            // Run git branch to create branch without switching
            let _ = try await executeGitCommand(
                ["branch", validatedName],
                in: validatedPath
            )
        }
    }

    /// Gets current branch name
    /// - Parameter repositoryPath: Path to the Git repository
    /// - Returns: Current branch name
    /// - Throws: GitError if operation fails
    func getCurrentBranch(in repositoryPath: String) async throws -> String {
        let validatedPath = try validateRepositoryPath(repositoryPath)

        // Run git branch --show-current
        let output = try await executeGitCommand(
            ["branch", "--show-current"],
            in: validatedPath
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generates a commit message using AI based on staged changes
    /// - Parameters:
    ///   - repositoryPath: Path to the Git repository
    ///   - aiService: AI service to use for generation
    /// - Returns: Generated commit message
    /// - Throws: GitError if operation fails
    func generateCommitMessage(in repositoryPath: String) async throws -> String {
        // Get staged changes
        let stagedChanges = try await getStagedChanges(in: repositoryPath)

        guard !stagedChanges.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitError.noStagedChanges
        }

        // Get recent commits for style reference
        let recentCommits = try await getLog(in: repositoryPath, count: 5)
        let commitStyle = recentCommits.map { $0.subject }.joined(separator: "\n")

        // Generate commit message prompt (for future AI integration)
        _ = """
        Analyze the following git diff and generate a concise, conventional commit message.

        Recent commit messages for style reference:
        \(commitStyle)

        Staged changes:
        \(stagedChanges.prefix(5000))

        Generate a commit message following these rules:
        1. Use conventional commit format: type(scope): subject
        2. Types: feat, fix, docs, style, refactor, test, chore
        3. Keep subject under 72 characters
        4. Focus on WHY, not WHAT
        5. Use imperative mood (e.g., "add" not "added")

        Commit message:
        """

        // Note: In a real implementation, this would call an AI service with the prompt above
        // For now, return a basic generated message based on analysis
        return analyzeChangesForCommitMessage(stagedChanges)
    }

    // MARK: - Private Methods

    /// Executes a Git command
    /// - Parameters:
    ///   - arguments: Command arguments
    ///   - repositoryPath: Working directory path
    /// - Returns: Command output
    /// - Throws: GitError if command fails
    private func executeGitCommand(_ arguments: [String], in repositoryPath: String) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set environment to avoid interactive prompts
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_ASKPASS"] = "echo"
        process.environment = environment

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                // Set timeout
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(commandTimeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: GitError.timeout)
                    }
                }

                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                // Check output size
                guard outputData.count <= maxOutputSize else {
                    continuation.resume(throwing: GitError.outputTooLarge)
                    return
                }

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: GitError.commandFailed(errorOutput))
                }
            } catch {
                continuation.resume(throwing: GitError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// Validates repository path
    /// - Parameter path: Path to validate
    /// - Returns: Validated path
    /// - Throws: GitError if path is invalid
    private func validateRepositoryPath(_ path: String) throws -> String {
        // Security: Prevent path traversal attacks
        let expandedPath = (path as NSString).expandingTildeInPath
        let resolvedPath = (expandedPath as NSString).resolvingSymlinksInPath

        // Check if path exists and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitError.invalidPath("Repository path does not exist or is not a directory")
        }

        // Check if it's a Git repository
        let gitDir = (resolvedPath as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir) else {
            throw GitError.notARepository
        }

        return resolvedPath
    }

    /// Validates commit message
    /// - Parameter message: Message to validate
    /// - Returns: Validated message
    /// - Throws: GitError if message is invalid
    private func validateCommitMessage(_ message: String) throws -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw GitError.invalidInput("Commit message cannot be empty")
        }

        guard trimmed.count <= 10000 else {
            throw GitError.invalidInput("Commit message too long (max 10000 characters)")
        }

        // Check for null bytes
        guard !trimmed.contains("\0") else {
            throw GitError.invalidInput("Commit message contains invalid characters")
        }

        return trimmed
    }

    /// Validates branch name
    /// - Parameter name: Branch name to validate
    /// - Returns: Validated name
    /// - Throws: GitError if name is invalid
    private func validateBranchName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw GitError.invalidInput("Branch name cannot be empty")
        }

        // Git branch name restrictions
        let invalidPatterns = [
            "^-",           // Cannot start with dash
            "\\.\\.",       // Cannot contain ".."
            "@\\{",         // Cannot contain "@{"
            "\\s",          // Cannot contain whitespace
            "^\\.",         // Cannot start with dot
            "\\.$",         // Cannot end with dot
            "/\\.",         // Cannot contain "/."
            "\\.lock$",     // Cannot end with ".lock"
            "[\\x00-\\x1f\\x7f]", // Control characters
            "[~^:?*\\[\\\\]"   // Special characters
        ]

        for pattern in invalidPatterns {
            if let _ = trimmed.range(of: pattern, options: .regularExpression) {
                throw GitError.invalidInput("Branch name contains invalid characters")
            }
        }

        guard trimmed.count <= 255 else {
            throw GitError.invalidInput("Branch name too long (max 255 characters)")
        }

        return trimmed
    }

    /// Validates file paths
    /// - Parameter paths: Paths to validate
    /// - Returns: Validated paths
    /// - Throws: GitError if paths are invalid
    private func validateFilePaths(_ paths: [String]) throws -> [String] {
        return try paths.map { path in
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                throw GitError.invalidInput("File path cannot be empty")
            }

            // Security: Prevent path traversal
            guard !trimmed.contains("..") else {
                throw GitError.invalidInput("File path contains invalid characters")
            }

            // Check for null bytes
            guard !trimmed.contains("\0") else {
                throw GitError.invalidInput("File path contains invalid characters")
            }

            return trimmed
        }
    }

    /// Parses git status output
    /// - Parameter output: Raw git status output
    /// - Returns: Parsed status
    private func parseGitStatus(_ output: String) -> GitStatus {
        var status = GitStatus(
            branch: "main",
            modifiedFiles: [],
            addedFiles: [],
            deletedFiles: [],
            untrackedFiles: []
        )

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("## ") {
                // Parse branch name
                let branchInfo = String(line.dropFirst(3))
                if let range = branchInfo.range(of: "...") {
                    status.branch = String(branchInfo[..<range.lowerBound])
                } else {
                    status.branch = branchInfo.components(separatedBy: .whitespaces).first ?? "main"
                }
            } else if line.count >= 3 {
                let statusCode = line.prefix(2)
                let filePath = String(line.dropFirst(3))

                switch statusCode {
                case " M", "M ", "MM":
                    status.modifiedFiles.append(filePath)
                case " A", "A ", "AM":
                    status.addedFiles.append(filePath)
                case " D", "D ", "DM":
                    status.deletedFiles.append(filePath)
                case "??":
                    status.untrackedFiles.append(filePath)
                default:
                    break
                }
            }
        }

        return status
    }

    /// Parses git log output
    /// - Parameter output: Raw git log output
    /// - Returns: Array of commits
    private func parseGitLog(_ output: String) -> [GitCommit] {
        let lines = output.components(separatedBy: .newlines)

        return lines.compactMap { line in
            let components = line.components(separatedBy: "|")
            guard components.count == 5 else { return nil }

            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: components[3]) ?? Date()

            return GitCommit(
                hash: components[0],
                author: components[1],
                authorEmail: components[2],
                date: date,
                subject: components[4]
            )
        }
    }

    /// Analyzes changes to generate a basic commit message
    /// - Parameter diff: Git diff output
    /// - Returns: Generated commit message
    private func analyzeChangesForCommitMessage(_ diff: String) -> String {
        // Basic analysis of changes
        let lines = diff.components(separatedBy: .newlines)

        var addedLines = 0
        var deletedLines = 0
        var modifiedFiles: Set<String> = []

        for line in lines {
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                addedLines += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletedLines += 1
            } else if line.hasPrefix("diff --git") {
                // Extract file name
                let components = line.components(separatedBy: " ")
                if components.count >= 3 {
                    let file = components[2].replacingOccurrences(of: "a/", with: "")
                    modifiedFiles.insert((file as NSString).lastPathComponent)
                }
            }
        }

        // Generate message based on analysis
        let fileCount = modifiedFiles.count
        let changeType = addedLines > deletedLines ? "Add" : (deletedLines > addedLines ? "Remove" : "Update")

        if fileCount == 1 {
            return "\(changeType.lowercased()): Update \(modifiedFiles.first ?? "file")"
        } else {
            return "\(changeType.lowercased()): Update \(fileCount) files"
        }
    }

    /// Finds the Git executable path
    /// - Returns: Path to git executable
    private static func findGitExecutable() -> String {
        let paths = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git"
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/usr/bin/git" // Default
    }
}

// MARK: - Data Structures

/// Represents Git repository status
struct GitStatus: Codable {
    /// Current branch name
    var branch: String

    /// Modified files
    var modifiedFiles: [String]

    /// Added files
    var addedFiles: [String]

    /// Deleted files
    var deletedFiles: [String]

    /// Untracked files
    var untrackedFiles: [String]

    /// Whether there are any changes
    var hasChanges: Bool {
        !modifiedFiles.isEmpty || !addedFiles.isEmpty || !deletedFiles.isEmpty
    }

    /// Whether there are untracked files
    var hasUntrackedFiles: Bool {
        !untrackedFiles.isEmpty
    }
}

/// Represents a Git commit
struct GitCommit: Codable, Identifiable {
    /// Commit hash
    let hash: String

    /// Author name
    let author: String

    /// Author email
    let authorEmail: String

    /// Commit date
    let date: Date

    /// Commit subject (first line of message)
    let subject: String

    /// Identifier for SwiftUI
    var id: String { hash }

    /// Short hash (first 7 characters)
    var shortHash: String {
        String(hash.prefix(7))
    }
}

// MARK: - Error Types

/// Git service errors
enum GitError: LocalizedError {
    case invalidPath(String)
    case notARepository
    case invalidInput(String)
    case commandFailed(String)
    case executionFailed(String)
    case timeout
    case outputTooLarge
    case noStagedChanges

    var errorDescription: String? {
        switch self {
        case .invalidPath(let message):
            return "Invalid path: \(message)"
        case .notARepository:
            return "Not a Git repository"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .commandFailed(let output):
            return "Git command failed: \(output)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .timeout:
            return "Git command timed out"
        case .outputTooLarge:
            return "Command output too large"
        case .noStagedChanges:
            return "No staged changes to commit"
        }
    }
}
