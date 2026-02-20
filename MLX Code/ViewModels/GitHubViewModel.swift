//
//  GitHubViewModel.swift
//  MLX Code
//
//  State management for GitHub integration
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Manages GitHub state for the UI
@MainActor
class GitHubViewModel: ObservableObject {
    /// Shared instance
    static let shared = GitHubViewModel()

    // MARK: - Published Properties

    /// Repository info
    @Published var repoInfo: GitHubRepo?

    /// Open issues
    @Published var issues: [GitHubIssue] = []

    /// Pull requests
    @Published var pullRequests: [GitHubPR] = []

    /// Branches
    @Published var branches: [GitHubBranch] = []

    /// Recent activity
    @Published var activity: [GitHubActivity] = []

    /// Contributors
    @Published var contributors: [GitHubContributor] = []

    /// Credential scan result
    @Published var credentialScanResult: CredentialScanResult?

    /// License check result
    @Published var licenseResult: LicenseCheckResult?

    /// Loading state
    @Published var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    /// Current tab selection
    @Published var selectedTab: GitHubTab = .issues

    /// Repository path
    @Published var repoPath: String = "/Volumes/Data/xcode/MLX Code"

    // MARK: - Tab Enum

    enum GitHubTab: String, CaseIterable {
        case issues = "Issues"
        case pullRequests = "Pull Requests"
        case branches = "Branches"
        case activity = "Activity"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Data Loading

    /// Loads all GitHub data for the repository
    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRepoInfo() }
            group.addTask { await self.loadIssues() }
            group.addTask { await self.loadPullRequests() }
            group.addTask { await self.loadBranches() }
            group.addTask { await self.loadActivity() }
        }
    }

    /// Loads repository info
    func loadRepoInfo() async {
        do {
            repoInfo = try await GitHubService.shared.getRepoInfo(repoPath: repoPath)
        } catch {
            errorMessage = "Failed to load repo info: \(error.localizedDescription)"
        }
    }

    /// Loads issues
    func loadIssues(state: String = "open") async {
        do {
            issues = try await GitHubService.shared.listIssues(repoPath: repoPath, state: state)
        } catch {
            errorMessage = "Failed to load issues: \(error.localizedDescription)"
        }
    }

    /// Loads pull requests
    func loadPullRequests(state: String = "open") async {
        do {
            pullRequests = try await GitHubService.shared.listPullRequests(repoPath: repoPath, state: state)
        } catch {
            errorMessage = "Failed to load PRs: \(error.localizedDescription)"
        }
    }

    /// Loads branches
    func loadBranches() async {
        do {
            branches = try await GitHubService.shared.listBranches(repoPath: repoPath)
        } catch {
            errorMessage = "Failed to load branches: \(error.localizedDescription)"
        }
    }

    /// Loads recent activity
    func loadActivity() async {
        do {
            activity = try await GitHubService.shared.getRecentActivity(repoPath: repoPath)
        } catch {
            errorMessage = "Failed to load activity: \(error.localizedDescription)"
        }
    }

    /// Loads contributors
    func loadContributors() async {
        do {
            contributors = try await GitHubService.shared.getContributors(repoPath: repoPath)
        } catch {
            errorMessage = "Failed to load contributors: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    /// Pushes current branch with credential scan
    func push(branch: String? = nil) async -> String {
        do {
            let result = try await GitHubService.shared.push(repoPath: repoPath, branch: branch)
            return result
        } catch {
            return "Push failed: \(error.localizedDescription)"
        }
    }

    /// Pulls latest changes
    func pull(branch: String? = nil) async -> String {
        do {
            let result = try await GitHubService.shared.pull(repoPath: repoPath, branch: branch)
            await loadBranches()
            return result
        } catch {
            return "Pull failed: \(error.localizedDescription)"
        }
    }

    /// Runs credential scan
    func scanCredentials() async {
        do {
            credentialScanResult = try await GitHubService.shared.scanForCredentials(repoPath: repoPath)
        } catch {
            errorMessage = "Credential scan failed: \(error.localizedDescription)"
        }
    }

    /// Checks license
    func checkLicense() async {
        do {
            licenseResult = try await GitHubService.shared.checkLicense(repoPath: repoPath)
        } catch {
            errorMessage = "License check failed: \(error.localizedDescription)"
        }
    }
}
