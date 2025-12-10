//
//  GitHubService.swift
//  MLX Code
//
//  Comprehensive GitHub API integration
//  Created on 2025-12-10
//

import Foundation

/// Comprehensive GitHub API service
/// Provides full GitHub integration including repos, PRs, issues, actions, and more
actor GitHubService {
    static let shared = GitHubService()

    private let baseURL = "https://api.github.com"
    private let settings = GitHubSettings.shared

    private init() {}

    // MARK: - Authentication

    /// Gets authorization header with token
    private func getAuthHeaders() async throws -> [String: String] {
        let token = try await MainActor.run {
            try settings.getToken()
        }

        return [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github.v3+json",
            "X-GitHub-Api-Version": "2022-11-28"
        ]
    }

    // MARK: - HTTP Client

    /// Makes an API request
    private func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GitHubAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        let headers = try await getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubAPIError.httpError(httpResponse.statusCode, errorMessage)
        }

        return data
    }

    // MARK: - User Operations

    /// Gets authenticated user information
    func getCurrentUser() async throws -> GitHubUser {
        let data = try await makeRequest(endpoint: "/user")
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    /// Gets user information by username
    func getUser(_ username: String) async throws -> GitHubUser {
        let data = try await makeRequest(endpoint: "/users/\(username)")
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    // MARK: - Repository Operations

    /// Lists repositories for the authenticated user
    func listRepositories(page: Int = 1, perPage: Int = 30) async throws -> [GitHubRepository] {
        let data = try await makeRequest(
            endpoint: "/user/repos?page=\(page)&per_page=\(perPage)&sort=updated"
        )
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }

    /// Gets repository information
    func getRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)")
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }

    /// Creates a new repository
    func createRepository(
        name: String,
        description: String? = nil,
        isPrivate: Bool = false,
        autoInit: Bool = true
    ) async throws -> GitHubRepository {
        var body: [String: Any] = [
            "name": name,
            "private": isPrivate,
            "auto_init": autoInit
        ]

        if let description = description {
            body["description"] = description
        }

        let data = try await makeRequest(
            endpoint: "/user/repos",
            method: "POST",
            body: body
        )
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }

    // MARK: - Issue Operations

    /// Lists issues for a repository
    func listIssues(
        owner: String,
        repo: String,
        state: String = "open",
        labels: [String]? = nil
    ) async throws -> [GitHubIssue] {
        var endpoint = "/repos/\(owner)/\(repo)/issues?state=\(state)"
        if let labels = labels, !labels.isEmpty {
            endpoint += "&labels=\(labels.joined(separator: ","))"
        }

        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode([GitHubIssue].self, from: data)
    }

    /// Gets a specific issue
    func getIssue(owner: String, repo: String, number: Int) async throws -> GitHubIssue {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/issues/\(number)")
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    /// Creates a new issue
    func createIssue(
        owner: String,
        repo: String,
        title: String,
        body: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil
    ) async throws -> GitHubIssue {
        var requestBody: [String: Any] = ["title": title]

        if let body = body { requestBody["body"] = body }
        if let labels = labels { requestBody["labels"] = labels }
        if let assignees = assignees { requestBody["assignees"] = assignees }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/issues",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    /// Updates an issue
    func updateIssue(
        owner: String,
        repo: String,
        number: Int,
        title: String? = nil,
        body: String? = nil,
        state: String? = nil,
        labels: [String]? = nil
    ) async throws -> GitHubIssue {
        var requestBody: [String: Any] = [:]

        if let title = title { requestBody["title"] = title }
        if let body = body { requestBody["body"] = body }
        if let state = state { requestBody["state"] = state }
        if let labels = labels { requestBody["labels"] = labels }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(number)",
            method: "PATCH",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    /// Comments on an issue
    func commentOnIssue(
        owner: String,
        repo: String,
        number: Int,
        body: String
    ) async throws -> GitHubComment {
        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(number)/comments",
            method: "POST",
            body: ["body": body]
        )
        return try JSONDecoder().decode(GitHubComment.self, from: data)
    }

    // MARK: - Pull Request Operations

    /// Lists pull requests for a repository
    func listPullRequests(
        owner: String,
        repo: String,
        state: String = "open"
    ) async throws -> [GitHubPullRequest] {
        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls?state=\(state)"
        )
        return try JSONDecoder().decode([GitHubPullRequest].self, from: data)
    }

    /// Gets a specific pull request
    func getPullRequest(owner: String, repo: String, number: Int) async throws -> GitHubPullRequest {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)")
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Creates a pull request
    func createPullRequest(
        owner: String,
        repo: String,
        title: String,
        head: String,
        base: String,
        body: String? = nil,
        draft: Bool = false
    ) async throws -> GitHubPullRequest {
        var requestBody: [String: Any] = [
            "title": title,
            "head": head,
            "base": base,
            "draft": draft
        ]

        if let body = body {
            requestBody["body"] = body
        }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Updates a pull request
    func updatePullRequest(
        owner: String,
        repo: String,
        number: Int,
        title: String? = nil,
        body: String? = nil,
        state: String? = nil
    ) async throws -> GitHubPullRequest {
        var requestBody: [String: Any] = [:]

        if let title = title { requestBody["title"] = title }
        if let body = body { requestBody["body"] = body }
        if let state = state { requestBody["state"] = state }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)",
            method: "PATCH",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Merges a pull request
    func mergePullRequest(
        owner: String,
        repo: String,
        number: Int,
        commitMessage: String? = nil,
        mergeMethod: String = "merge" // merge, squash, or rebase
    ) async throws {
        var requestBody: [String: Any] = ["merge_method": mergeMethod]
        if let message = commitMessage {
            requestBody["commit_message"] = message
        }

        _ = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/merge",
            method: "PUT",
            body: requestBody
        )
    }

    // MARK: - Code Review Operations

    /// Lists reviews for a pull request
    func listReviews(
        owner: String,
        repo: String,
        pullNumber: Int
    ) async throws -> [GitHubReview] {
        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews"
        )
        return try JSONDecoder().decode([GitHubReview].self, from: data)
    }

    /// Creates a review on a pull request
    func createReview(
        owner: String,
        repo: String,
        pullNumber: Int,
        body: String? = nil,
        event: String, // APPROVE, REQUEST_CHANGES, COMMENT
        comments: [[String: Any]]? = nil
    ) async throws -> GitHubReview {
        var requestBody: [String: Any] = ["event": event]

        if let body = body { requestBody["body"] = body }
        if let comments = comments { requestBody["comments"] = comments }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubReview.self, from: data)
    }

    /// Comments on a pull request
    func commentOnPullRequest(
        owner: String,
        repo: String,
        pullNumber: Int,
        body: String
    ) async throws -> GitHubComment {
        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(pullNumber)/comments",
            method: "POST",
            body: ["body": body]
        )
        return try JSONDecoder().decode(GitHubComment.self, from: data)
    }

    // MARK: - GitHub Actions / Workflows

    /// Lists workflows for a repository
    func listWorkflows(owner: String, repo: String) async throws -> [GitHubWorkflow] {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/workflows")
        let response = try JSONDecoder().decode(WorkflowsResponse.self, from: data)
        return response.workflows
    }

    /// Triggers a workflow dispatch event
    func triggerWorkflow(
        owner: String,
        repo: String,
        workflowId: String,
        ref: String,
        inputs: [String: String]? = nil
    ) async throws {
        var requestBody: [String: Any] = ["ref": ref]
        if let inputs = inputs {
            requestBody["inputs"] = inputs
        }

        _ = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/actions/workflows/\(workflowId)/dispatches",
            method: "POST",
            body: requestBody
        )
    }

    /// Lists workflow runs
    func listWorkflowRuns(
        owner: String,
        repo: String,
        page: Int = 1
    ) async throws -> [GitHubWorkflowRun] {
        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/actions/runs?page=\(page)"
        )
        let response = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
        return response.workflowRuns
    }

    // MARK: - Releases

    /// Lists releases for a repository
    func listReleases(owner: String, repo: String) async throws -> [GitHubRelease] {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/releases")
        return try JSONDecoder().decode([GitHubRelease].self, from: data)
    }

    /// Creates a new release
    func createRelease(
        owner: String,
        repo: String,
        tagName: String,
        name: String,
        body: String? = nil,
        draft: Bool = false,
        prerelease: Bool = false
    ) async throws -> GitHubRelease {
        var requestBody: [String: Any] = [
            "tag_name": tagName,
            "name": name,
            "draft": draft,
            "prerelease": prerelease
        ]

        if let body = body {
            requestBody["body"] = body
        }

        let data = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/releases",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - Gists

    /// Lists gists for the authenticated user
    func listGists() async throws -> [GitHubGist] {
        let data = try await makeRequest(endpoint: "/gists")
        return try JSONDecoder().decode([GitHubGist].self, from: data)
    }

    /// Creates a new gist
    func createGist(
        description: String,
        files: [String: String], // filename -> content
        isPublic: Bool = true
    ) async throws -> GitHubGist {
        let filesDict = files.mapValues { ["content": $0] }

        let requestBody: [String: Any] = [
            "description": description,
            "public": isPublic,
            "files": filesDict
        ]

        let data = try await makeRequest(
            endpoint: "/gists",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GitHubGist.self, from: data)
    }

    // MARK: - Branches

    /// Lists branches for a repository
    func listBranches(owner: String, repo: String) async throws -> [GitHubBranch] {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/branches")
        return try JSONDecoder().decode([GitHubBranch].self, from: data)
    }

    /// Gets a specific branch
    func getBranch(owner: String, repo: String, branch: String) async throws -> GitHubBranch {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/branches/\(branch)")
        return try JSONDecoder().decode(GitHubBranch.self, from: data)
    }

    // MARK: - File Operations

    /// Gets file contents from repository
    func getFileContents(
        owner: String,
        repo: String,
        path: String,
        ref: String? = nil
    ) async throws -> GitHubFile {
        var endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        if let ref = ref {
            endpoint += "?ref=\(ref)"
        }

        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder().decode(GitHubFile.self, from: data)
    }

    // MARK: - Search Operations

    /// Searches repositories
    func searchRepositories(
        query: String,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubRepository] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await makeRequest(
            endpoint: "/search/repositories?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)"
        )
        let response = try JSONDecoder().decode(SearchRepositoriesResponse.self, from: data)
        return response.items
    }

    /// Searches issues
    func searchIssues(
        query: String,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubIssue] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await makeRequest(
            endpoint: "/search/issues?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)"
        )
        let response = try JSONDecoder().decode(SearchIssuesResponse.self, from: data)
        return response.items
    }

    // MARK: - Collaborators

    /// Lists collaborators for a repository
    func listCollaborators(owner: String, repo: String) async throws -> [GitHubUser] {
        let data = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/collaborators")
        return try JSONDecoder().decode([GitHubUser].self, from: data)
    }

    /// Adds a collaborator to a repository
    func addCollaborator(
        owner: String,
        repo: String,
        username: String,
        permission: String = "push" // pull, push, admin, maintain, triage
    ) async throws {
        _ = try await makeRequest(
            endpoint: "/repos/\(owner)/\(repo)/collaborators/\(username)",
            method: "PUT",
            body: ["permission": permission]
        )
    }
}

// MARK: - Data Models

struct GitHubUser: Codable {
    let id: Int
    let login: String
    let name: String?
    let email: String?
    let avatarUrl: String
    let htmlUrl: String
    let bio: String?
    let publicRepos: Int?
    let followers: Int?
    let following: Int?

    enum CodingKeys: String, CodingKey {
        case id, login, name, email, bio, followers, following
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case publicRepos = "public_repos"
    }
}

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let cloneUrl: String
    let isPrivate: Bool
    let fork: Bool
    let defaultBranch: String
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, fork, language
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubIssue: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GitHubUser
    let labels: [GitHubLabel]
    let assignees: [GitHubUser]?
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, assignees
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubLabel: Codable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

struct GitHubPullRequest: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GitHubUser
    let head: GitHubBranchRef
    let base: GitHubBranchRef
    let htmlUrl: String
    let draft: Bool
    let merged: Bool?
    let mergeable: Bool?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, head, base, draft, merged, mergeable
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubBranchRef: Codable {
    let ref: String
    let sha: String
    let repo: GitHubRepository?
}

struct GitHubComment: Codable, Identifiable {
    let id: Int
    let body: String
    let user: GitHubUser
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubReview: Codable, Identifiable {
    let id: Int
    let user: GitHubUser
    let body: String?
    let state: String // APPROVED, CHANGES_REQUESTED, COMMENTED
    let htmlUrl: String
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case htmlUrl = "html_url"
        case submittedAt = "submitted_at"
    }
}

struct GitHubWorkflow: Codable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let state: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, path, state
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubWorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let headBranch: String
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case headBranch = "head_branch"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubRelease: Codable, Identifiable {
    let id: Int
    let tagName: String
    let name: String
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let htmlUrl: String
    let createdAt: String
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, body, draft, prerelease
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }
}

struct GitHubGist: Codable, Identifiable {
    let id: String
    let description: String?
    let isPublic: Bool
    let htmlUrl: String
    let files: [String: GitHubGistFile]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, description, files
        case isPublic = "public"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubGistFile: Codable {
    let filename: String
    let type: String
    let language: String?
    let rawUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case filename, type, language, size
        case rawUrl = "raw_url"
    }
}

struct GitHubBranch: Codable, Identifiable {
    let name: String
    let commit: GitHubCommitInfo
    let protected: Bool

    var id: String { name }
}

struct GitHubCommitInfo: Codable {
    let sha: String
    let url: String
}

struct GitHubFile: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let url: String
    let htmlUrl: String
    let downloadUrl: String?
    let type: String
    let content: String?
    let encoding: String?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url, type, content, encoding
        case htmlUrl = "html_url"
        case downloadUrl = "download_url"
    }
}

// MARK: - Response Wrappers

struct WorkflowsResponse: Codable {
    let workflows: [GitHubWorkflow]
}

struct WorkflowRunsResponse: Codable {
    let workflowRuns: [GitHubWorkflowRun]

    enum CodingKeys: String, CodingKey {
        case workflowRuns = "workflow_runs"
    }
}

struct SearchRepositoriesResponse: Codable {
    let items: [GitHubRepository]
}

struct SearchIssuesResponse: Codable {
    let items: [GitHubIssue]
}

// MARK: - Errors

enum GitHubAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .httpError(let code, let message):
            return "GitHub API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noToken:
            return "No GitHub token configured"
        }
    }
}
