//
//  GitHubTool.swift
//  MLX Code
//
//  GitHub operations tool for LLM
//  Created on 2025-12-10
//

import Foundation

/// Tool for GitHub operations via LLM
class GitHubTool: BaseTool {
    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "GitHub operation to perform",
                    enum: [
                        "list_repos", "get_repo", "create_repo",
                        "list_issues", "create_issue", "get_issue", "comment_issue",
                        "list_prs", "get_pr", "create_pr",
                        "list_releases", "create_release",
                        "list_gists", "create_gist",
                        "list_workflows", "list_workflow_runs",
                        "search_repos", "search_issues",
                        "get_user"
                    ]
                ),
                "owner": ParameterProperty(
                    type: "string",
                    description: "Repository owner (optional, uses default if not specified)"
                ),
                "repo": ParameterProperty(
                    type: "string",
                    description: "Repository name (optional, uses default if not specified)"
                ),
                "title": ParameterProperty(
                    type: "string",
                    description: "Title for issue/PR/release"
                ),
                "body": ParameterProperty(
                    type: "string",
                    description: "Body/description for issue/PR/release/gist"
                ),
                "number": ParameterProperty(
                    type: "number",
                    description: "Issue or PR number"
                ),
                "query": ParameterProperty(
                    type: "string",
                    description: "Search query"
                ),
                "state": ParameterProperty(
                    type: "string",
                    description: "State filter (open, closed, all)"
                ),
                "head": ParameterProperty(
                    type: "string",
                    description: "Head branch for PR"
                ),
                "base": ParameterProperty(
                    type: "string",
                    description: "Base branch for PR"
                ),
                "tag_name": ParameterProperty(
                    type: "string",
                    description: "Tag name for release"
                ),
                "is_private": ParameterProperty(
                    type: "boolean",
                    description: "Whether repo should be private"
                ),
                "is_public": ParameterProperty(
                    type: "boolean",
                    description: "Whether gist should be public"
                )
            ],
            required: ["operation"]
        )

        super.init(
            name: "github",
            description: """
            Performs GitHub operations using the configured GitHub account.

            Capabilities:
            - List user's repositories
            - Get repository information
            - Create new repositories
            - List issues in a repository
            - Create issues
            - Comment on issues
            - List pull requests
            - Get PR details
            - List releases
            - List gists
            - Create gists
            - List workflow runs
            - Search repositories
            - Search issues
            - Get current user info

            Use this when the user asks about their GitHub account, repositories, issues, PRs, etc.
            """,
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let operation = parameters["operation"] as? String ?? ""

        // Check if GitHub is configured
        let settings = await MainActor.run { GitHubSettings.shared }
        let hasToken = await MainActor.run { settings.hasToken }

        guard hasToken else {
            return ToolResult(
                success: false,
                output: """
                ❌ GitHub is not configured.

                To use GitHub features:
                1. Open Settings (⌘,)
                2. Go to GitHub tab
                3. Enter your GitHub username
                4. Add your Personal Access Token
                5. Test the connection

                Create a token at: https://github.com/settings/tokens/new
                Required scopes: repo, user, workflow
                """,
                error: "GitHub not configured"
            )
        }

        do {
            let service = GitHubService.shared

            switch operation {
            case "list_repos":
                return try await listRepositories(service: service)

            case "get_repo":
                guard let owner = parameters["owner"] as? String,
                      let repo = parameters["repo"] as? String else {
                    throw ToolError.missingParameter("owner and repo")
                }
                return try await getRepository(service: service, owner: owner, repo: repo)

            case "create_repo":
                guard let name = parameters["title"] as? String else {
                    throw ToolError.missingParameter("title")
                }
                let description = parameters["body"] as? String
                let isPrivate = parameters["is_private"] as? Bool ?? false
                return try await createRepository(
                    service: service,
                    name: name,
                    description: description,
                    isPrivate: isPrivate
                )

            case "list_issues":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                let state = parameters["state"] as? String ?? "open"
                return try await listIssues(service: service, owner: owner, repo: repo, state: state)

            case "create_issue":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let title = parameters["title"] as? String else {
                    throw ToolError.missingParameter("title")
                }
                let body = parameters["body"] as? String
                return try await createIssue(
                    service: service,
                    owner: owner,
                    repo: repo,
                    title: title,
                    body: body
                )

            case "get_issue":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let number = parameters["number"] as? Int else {
                    throw ToolError.missingParameter("number")
                }
                return try await getIssue(service: service, owner: owner, repo: repo, number: number)

            case "comment_issue":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let number = parameters["number"] as? Int,
                      let body = parameters["body"] as? String else {
                    throw ToolError.missingParameter("number and body")
                }
                return try await commentOnIssue(
                    service: service,
                    owner: owner,
                    repo: repo,
                    number: number,
                    body: body
                )

            case "list_prs":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                let state = parameters["state"] as? String ?? "open"
                return try await listPullRequests(service: service, owner: owner, repo: repo, state: state)

            case "get_pr":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let number = parameters["number"] as? Int else {
                    throw ToolError.missingParameter("number")
                }
                return try await getPullRequest(service: service, owner: owner, repo: repo, number: number)

            case "create_pr":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let title = parameters["title"] as? String,
                      let head = parameters["head"] as? String,
                      let base = parameters["base"] as? String else {
                    throw ToolError.missingParameter("title, head, and base")
                }
                let body = parameters["body"] as? String
                return try await createPullRequest(
                    service: service,
                    owner: owner,
                    repo: repo,
                    title: title,
                    head: head,
                    base: base,
                    body: body
                )

            case "list_releases":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                return try await listReleases(service: service, owner: owner, repo: repo)

            case "create_release":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                guard let tagName = parameters["tag_name"] as? String,
                      let title = parameters["title"] as? String else {
                    throw ToolError.missingParameter("tag_name and title")
                }
                let body = parameters["body"] as? String
                return try await createRelease(
                    service: service,
                    owner: owner,
                    repo: repo,
                    tagName: tagName,
                    name: title,
                    body: body
                )

            case "list_gists":
                return try await listGists(service: service)

            case "create_gist":
                guard let description = parameters["body"] as? String,
                      let files = parameters["files"] as? [String: String] else {
                    throw ToolError.missingParameter("body and files")
                }
                let isPublic = parameters["is_public"] as? Bool ?? true
                return try await createGist(
                    service: service,
                    description: description,
                    files: files,
                    isPublic: isPublic
                )

            case "list_workflows":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                return try await listWorkflows(service: service, owner: owner, repo: repo)

            case "list_workflow_runs":
                let defaultOwner = await getDefaultOwner()
                let defaultRepo = await getDefaultRepo()
                let owner = parameters["owner"] as? String ?? defaultOwner
                let repo = parameters["repo"] as? String ?? defaultRepo
                return try await listWorkflowRuns(service: service, owner: owner, repo: repo)

            case "search_repos":
                guard let query = parameters["query"] as? String else {
                    throw ToolError.missingParameter("query")
                }
                return try await searchRepositories(service: service, query: query)

            case "search_issues":
                guard let query = parameters["query"] as? String else {
                    throw ToolError.missingParameter("query")
                }
                return try await searchIssues(service: service, query: query)

            case "get_user":
                return try await getCurrentUser(service: service)

            default:
                throw ToolError.executionFailed("Unknown operation: \(operation)")
            }

        } catch {
            return ToolResult(
                success: false,
                output: "",
                error: "GitHub API error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helper Methods

    private func getDefaultOwner() async -> String {
        await MainActor.run {
            let owner = GitHubSettings.shared.defaultOwner
            return owner.isEmpty ? GitHubSettings.shared.username : owner
        }
    }

    private func getDefaultRepo() async -> String {
        await MainActor.run {
            GitHubSettings.shared.defaultRepo
        }
    }

    // MARK: - Operation Implementations

    private func listRepositories(service: GitHubService) async throws -> ToolResult {
        let repos = try await service.listRepositories()

        var output = "## Your Repositories (\(repos.count))\n\n"
        for repo in repos.prefix(20) {
            output += "### \(repo.name)\n"
            if let desc = repo.description {
                output += "\(desc)\n"
            }
            output += "- **Stars**: \(repo.stargazersCount)\n"
            output += "- **Forks**: \(repo.forksCount)\n"
            output += "- **Issues**: \(repo.openIssuesCount)\n"
            if let lang = repo.language {
                output += "- **Language**: \(lang)\n"
            }
            output += "- **URL**: \(repo.htmlUrl)\n\n"
        }

        if repos.count > 20 {
            output += "\n_Showing first 20 of \(repos.count) repositories_\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func getRepository(service: GitHubService, owner: String, repo: String) async throws -> ToolResult {
        let repository = try await service.getRepository(owner: owner, repo: repo)

        let output = """
        ## \(repository.fullName)

        \(repository.description ?? "No description")

        **Details:**
        - Stars: \(repository.stargazersCount)
        - Forks: \(repository.forksCount)
        - Open Issues: \(repository.openIssuesCount)
        - Language: \(repository.language ?? "N/A")
        - Default Branch: \(repository.defaultBranch)
        - Private: \(repository.isPrivate ? "Yes" : "No")
        - URL: \(repository.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func createRepository(
        service: GitHubService,
        name: String,
        description: String?,
        isPrivate: Bool
    ) async throws -> ToolResult {
        let repo = try await service.createRepository(
            name: name,
            description: description,
            isPrivate: isPrivate,
            autoInit: true
        )

        let output = """
        ✅ Repository created successfully!

        **Name**: \(repo.name)
        **URL**: \(repo.htmlUrl)
        **Clone URL**: \(repo.cloneUrl)
        **Private**: \(repo.isPrivate ? "Yes" : "No")
        """

        return ToolResult(success: true, output: output)
    }

    private func listIssues(
        service: GitHubService,
        owner: String,
        repo: String,
        state: String
    ) async throws -> ToolResult {
        let issues = try await service.listIssues(owner: owner, repo: repo, state: state)

        var output = "## Issues in \(owner)/\(repo) (\(state))\n\n"
        output += "Found \(issues.count) issues\n\n"

        for issue in issues.prefix(15) {
            output += "### #\(issue.number): \(issue.title)\n"
            output += "- **State**: \(issue.state)\n"
            output += "- **Author**: \(issue.user.login)\n"
            if !issue.labels.isEmpty {
                output += "- **Labels**: \(issue.labels.map { $0.name }.joined(separator: ", "))\n"
            }
            output += "- **URL**: \(issue.htmlUrl)\n\n"
        }

        if issues.count > 15 {
            output += "\n_Showing first 15 of \(issues.count) issues_\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func createIssue(
        service: GitHubService,
        owner: String,
        repo: String,
        title: String,
        body: String?
    ) async throws -> ToolResult {
        let issue = try await service.createIssue(
            owner: owner,
            repo: repo,
            title: title,
            body: body
        )

        let output = """
        ✅ Issue created successfully!

        **Number**: #\(issue.number)
        **Title**: \(issue.title)
        **URL**: \(issue.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func getIssue(
        service: GitHubService,
        owner: String,
        repo: String,
        number: Int
    ) async throws -> ToolResult {
        let issue = try await service.getIssue(owner: owner, repo: repo, number: number)

        var output = """
        ## #\(issue.number): \(issue.title)

        **State**: \(issue.state)
        **Author**: \(issue.user.login)
        **Created**: \(issue.createdAt)
        **Updated**: \(issue.updatedAt)
        **URL**: \(issue.htmlUrl)

        """

        if !issue.labels.isEmpty {
            output += "**Labels**: \(issue.labels.map { $0.name }.joined(separator: ", "))\n\n"
        }

        if let body = issue.body {
            output += "### Description\n\n\(body)\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func commentOnIssue(
        service: GitHubService,
        owner: String,
        repo: String,
        number: Int,
        body: String
    ) async throws -> ToolResult {
        let comment = try await service.commentOnIssue(
            owner: owner,
            repo: repo,
            number: number,
            body: body
        )

        let output = """
        ✅ Comment added successfully!

        **Issue**: #\(number)
        **URL**: \(comment.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func listPullRequests(
        service: GitHubService,
        owner: String,
        repo: String,
        state: String
    ) async throws -> ToolResult {
        let prs = try await service.listPullRequests(owner: owner, repo: repo, state: state)

        var output = "## Pull Requests in \(owner)/\(repo) (\(state))\n\n"
        output += "Found \(prs.count) pull requests\n\n"

        for pr in prs.prefix(15) {
            output += "### #\(pr.number): \(pr.title)\n"
            output += "- **State**: \(pr.state)\n"
            output += "- **Author**: \(pr.user.login)\n"
            output += "- **Branches**: \(pr.head.ref) → \(pr.base.ref)\n"
            if pr.draft {
                output += "- **Draft**: Yes\n"
            }
            output += "- **URL**: \(pr.htmlUrl)\n\n"
        }

        if prs.count > 15 {
            output += "\n_Showing first 15 of \(prs.count) pull requests_\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func getPullRequest(
        service: GitHubService,
        owner: String,
        repo: String,
        number: Int
    ) async throws -> ToolResult {
        let pr = try await service.getPullRequest(owner: owner, repo: repo, number: number)

        var output = """
        ## #\(pr.number): \(pr.title)

        **State**: \(pr.state)
        **Author**: \(pr.user.login)
        **Branches**: \(pr.head.ref) → \(pr.base.ref)
        **Draft**: \(pr.draft ? "Yes" : "No")
        **Merged**: \(pr.merged ?? false ? "Yes" : "No")
        **Mergeable**: \(pr.mergeable ?? false ? "Yes" : "No")
        **URL**: \(pr.htmlUrl)

        """

        if let body = pr.body {
            output += "### Description\n\n\(body)\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func createPullRequest(
        service: GitHubService,
        owner: String,
        repo: String,
        title: String,
        head: String,
        base: String,
        body: String?
    ) async throws -> ToolResult {
        let pr = try await service.createPullRequest(
            owner: owner,
            repo: repo,
            title: title,
            head: head,
            base: base,
            body: body
        )

        let output = """
        ✅ Pull request created successfully!

        **Number**: #\(pr.number)
        **Title**: \(pr.title)
        **Branches**: \(pr.head.ref) → \(pr.base.ref)
        **URL**: \(pr.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func listReleases(service: GitHubService, owner: String, repo: String) async throws -> ToolResult {
        let releases = try await service.listReleases(owner: owner, repo: repo)

        var output = "## Releases for \(owner)/\(repo)\n\n"
        output += "Found \(releases.count) releases\n\n"

        for release in releases.prefix(10) {
            output += "### \(release.name)\n"
            output += "- **Tag**: \(release.tagName)\n"
            if release.prerelease {
                output += "- **Pre-release**: Yes\n"
            }
            if release.draft {
                output += "- **Draft**: Yes\n"
            }
            output += "- **URL**: \(release.htmlUrl)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func createRelease(
        service: GitHubService,
        owner: String,
        repo: String,
        tagName: String,
        name: String,
        body: String?
    ) async throws -> ToolResult {
        let release = try await service.createRelease(
            owner: owner,
            repo: repo,
            tagName: tagName,
            name: name,
            body: body
        )

        let output = """
        ✅ Release created successfully!

        **Name**: \(release.name)
        **Tag**: \(release.tagName)
        **URL**: \(release.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func listGists(service: GitHubService) async throws -> ToolResult {
        let gists = try await service.listGists()

        var output = "## Your Gists\n\n"
        output += "Found \(gists.count) gists\n\n"

        for gist in gists.prefix(15) {
            if let desc = gist.description {
                output += "### \(desc)\n"
            } else {
                output += "### Untitled Gist\n"
            }
            output += "- **Files**: \(gist.files.count)\n"
            output += "- **Public**: \(gist.isPublic ? "Yes" : "No")\n"
            output += "- **URL**: \(gist.htmlUrl)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func createGist(
        service: GitHubService,
        description: String,
        files: [String: String],
        isPublic: Bool
    ) async throws -> ToolResult {
        let gist = try await service.createGist(
            description: description,
            files: files,
            isPublic: isPublic
        )

        let output = """
        ✅ Gist created successfully!

        **Description**: \(gist.description ?? "Untitled")
        **Files**: \(gist.files.count)
        **Public**: \(gist.isPublic ? "Yes" : "No")
        **URL**: \(gist.htmlUrl)
        """

        return ToolResult(success: true, output: output)
    }

    private func listWorkflows(service: GitHubService, owner: String, repo: String) async throws -> ToolResult {
        let workflows = try await service.listWorkflows(owner: owner, repo: repo)

        var output = "## Workflows in \(owner)/\(repo)\n\n"
        output += "Found \(workflows.count) workflows\n\n"

        for workflow in workflows {
            output += "### \(workflow.name)\n"
            output += "- **Path**: \(workflow.path)\n"
            output += "- **State**: \(workflow.state)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func listWorkflowRuns(service: GitHubService, owner: String, repo: String) async throws -> ToolResult {
        let runs = try await service.listWorkflowRuns(owner: owner, repo: repo)

        var output = "## Recent Workflow Runs for \(owner)/\(repo)\n\n"
        output += "Found \(runs.count) recent runs\n\n"

        for run in runs.prefix(10) {
            output += "### \(run.name)\n"
            output += "- **Status**: \(run.status)\n"
            if let conclusion = run.conclusion {
                output += "- **Conclusion**: \(conclusion)\n"
            }
            output += "- **Branch**: \(run.headBranch)\n"
            output += "- **URL**: \(run.htmlUrl)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func searchRepositories(service: GitHubService, query: String) async throws -> ToolResult {
        let repos = try await service.searchRepositories(query: query)

        var output = "## Search Results for: \(query)\n\n"
        output += "Found \(repos.count) repositories\n\n"

        for repo in repos.prefix(15) {
            output += "### \(repo.fullName)\n"
            if let desc = repo.description {
                output += "\(desc)\n"
            }
            output += "- **Stars**: \(repo.stargazersCount)\n"
            if let lang = repo.language {
                output += "- **Language**: \(lang)\n"
            }
            output += "- **URL**: \(repo.htmlUrl)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func searchIssues(service: GitHubService, query: String) async throws -> ToolResult {
        let issues = try await service.searchIssues(query: query)

        var output = "## Issue Search Results for: \(query)\n\n"
        output += "Found \(issues.count) issues\n\n"

        for issue in issues.prefix(15) {
            output += "### #\(issue.number): \(issue.title)\n"
            output += "- **State**: \(issue.state)\n"
            output += "- **Author**: \(issue.user.login)\n"
            output += "- **URL**: \(issue.htmlUrl)\n\n"
        }

        return ToolResult(success: true, output: output)
    }

    private func getCurrentUser(service: GitHubService) async throws -> ToolResult {
        let user = try await service.getCurrentUser()

        var output = """
        ## Your GitHub Profile

        **Username**: \(user.login)
        """

        if let name = user.name {
            output += "\n**Name**: \(name)"
        }
        if let email = user.email {
            output += "\n**Email**: \(email)"
        }
        if let bio = user.bio {
            output += "\n**Bio**: \(bio)"
        }
        if let repos = user.publicRepos {
            output += "\n**Public Repos**: \(repos)"
        }
        if let followers = user.followers {
            output += "\n**Followers**: \(followers)"
        }
        if let following = user.following {
            output += "\n**Following**: \(following)"
        }

        output += "\n**Profile URL**: \(user.htmlUrl)"

        return ToolResult(success: true, output: output)
    }
}

// MARK: - Tool Registration
// GitHub tool is automatically registered via ToolRegistry.registerBuiltInTools()
