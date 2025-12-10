//
//  GitHubPanelView.swift
//  MLX Code
//
//  Comprehensive GitHub operations panel
//  Created on 2025-12-10
//

import SwiftUI

/// Main GitHub operations panel
struct GitHubPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = GitHubSettings.shared
    @State private var selectedTab: GitHubTab = .repositories

    enum GitHubTab: String, CaseIterable {
        case repositories = "Repositories"
        case pullRequests = "Pull Requests"
        case issues = "Issues"
        case actions = "Actions"
        case releases = "Releases"
        case gists = "Gists"

        var icon: String {
            switch self {
            case .repositories: return "folder.fill"
            case .pullRequests: return "arrow.triangle.merge"
            case .issues: return "exclamationmark.circle"
            case .actions: return "play.circle"
            case .releases: return "tag"
            case .gists: return "doc.text"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                Text("GitHub Operations")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if !settings.hasToken {
                    Button("Configure GitHub") {
                        // Open settings
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Tab selection
            Picker("Operation", selection: $selectedTab) {
                ForEach(GitHubTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content area
            Group {
                if !settings.hasToken {
                    noTokenView
                } else {
                    tabContent
                }
            }
        }
        .frame(width: 900, height: 700)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .repositories:
            RepositoriesTabView()
        case .pullRequests:
            PullRequestsTabView()
        case .issues:
            IssuesTabView()
        case .actions:
            ActionsTabView()
        case .releases:
            ReleasesTabView()
        case .gists:
            GistsTabView()
        }
    }

    private var noTokenView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("GitHub Not Configured")
                .font(.title)
                .fontWeight(.semibold)

            Text("Please configure your GitHub credentials in Settings to use GitHub features.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Open Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Repositories Tab

struct RepositoriesTabView: View {
    @State private var repositories: [GitHubRepository] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showingCreateRepo = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: loadRepositories) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Button(action: { showingCreateRepo = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Repository")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            // Content
            if let error = error {
                errorView(error)
            } else if repositories.isEmpty && !loading {
                emptyStateView(
                    icon: "folder",
                    title: "No Repositories",
                    message: "Click Refresh to load your repositories"
                )
            } else {
                repositoryList
            }
        }
        .sheet(isPresented: $showingCreateRepo) {
            CreateRepositoryView { success in
                if success {
                    loadRepositories()
                }
            }
        }
        .onAppear {
            if repositories.isEmpty {
                loadRepositories()
            }
        }
    }

    private var repositoryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(repositories) { repo in
                    RepositoryRow(repository: repo)
                }
            }
            .padding()
        }
    }

    private func loadRepositories() {
        loading = true
        error = nil

        Task {
            do {
                let repos = try await GitHubService.shared.listRepositories()
                await MainActor.run {
                    repositories = repos
                    loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Error")
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Retry") {
                loadRepositories()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct RepositoryRow: View {
    let repository: GitHubRepository

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(repository.name)
                        .font(.headline)

                    if repository.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Button("View on GitHub") {
                        if let url = URL(string: repository.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let description = repository.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    if let language = repository.language {
                        Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                    }
                    Label("\(repository.stargazersCount)", systemImage: "star")
                        .font(.caption)
                    Label("\(repository.forksCount)", systemImage: "tuningfork")
                        .font(.caption)
                    Label("\(repository.openIssuesCount)", systemImage: "exclamationmark.circle")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Pull Requests Tab

struct PullRequestsTabView: View {
    @ObservedObject private var settings = GitHubSettings.shared
    @State private var pullRequests: [GitHubPullRequest] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack {
            if settings.defaultOwner.isEmpty || settings.defaultRepo.isEmpty {
                Text("Please configure default repository in Settings → GitHub")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                pullRequestsContent
            }
        }
        .onAppear {
            if pullRequests.isEmpty && !settings.defaultOwner.isEmpty {
                loadPullRequests()
            }
        }
    }

    private var pullRequestsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: loadPullRequests) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Text("\(settings.defaultOwner)/\(settings.defaultRepo)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(pullRequests) { pr in
                        PullRequestRow(pullRequest: pr)
                    }
                }
                .padding()
            }
        }
    }

    private func loadPullRequests() {
        loading = true
        error = nil

        Task {
            do {
                let prs = try await GitHubService.shared.listPullRequests(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo
                )
                await MainActor.run {
                    pullRequests = prs
                    loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}

struct PullRequestRow: View {
    let pullRequest: GitHubPullRequest

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(pullRequest.number)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(pullRequest.title)
                        .font(.headline)

                    if pullRequest.draft {
                        Text("DRAFT")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Button("View") {
                        if let url = URL(string: pullRequest.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    Text("\(pullRequest.head.ref) → \(pullRequest.base.ref)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Issues Tab

struct IssuesTabView: View {
    @ObservedObject private var settings = GitHubSettings.shared
    @State private var issues: [GitHubIssue] = []
    @State private var loading = false
    @State private var showingCreateIssue = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: loadIssues) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Button(action: { showingCreateIssue = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Issue")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(issues) { issue in
                        IssueRow(issue: issue)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateIssue) {
            CreateIssueView { success in
                if success {
                    loadIssues()
                }
            }
        }
        .onAppear {
            if issues.isEmpty {
                loadIssues()
            }
        }
    }

    private func loadIssues() {
        guard !settings.defaultOwner.isEmpty && !settings.defaultRepo.isEmpty else { return }

        loading = true

        Task {
            do {
                let result = try await GitHubService.shared.listIssues(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo
                )
                await MainActor.run {
                    issues = result
                    loading = false
                }
            } catch {
                await MainActor.run {
                    loading = false
                }
            }
        }
    }
}

struct IssueRow: View {
    let issue: GitHubIssue

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(issue.number)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(issue.title)
                        .font(.headline)

                    Spacer()

                    Button("View") {
                        if let url = URL(string: issue.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !issue.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(issue.labels, id: \.id) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color).opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Actions Tab

struct ActionsTabView: View {
    @ObservedObject private var settings = GitHubSettings.shared
    @State private var workflows: [GitHubWorkflow] = []
    @State private var runs: [GitHubWorkflowRun] = []
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: loadWorkflows) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Workflows
                    if !workflows.isEmpty {
                        Text("Workflows")
                            .font(.headline)

                        ForEach(workflows) { workflow in
                            WorkflowRow(workflow: workflow)
                        }
                    }

                    // Recent Runs
                    if !runs.isEmpty {
                        Text("Recent Runs")
                            .font(.headline)
                            .padding(.top)

                        ForEach(runs.prefix(10)) { run in
                            WorkflowRunRow(run: run)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if workflows.isEmpty {
                loadWorkflows()
            }
        }
    }

    private func loadWorkflows() {
        guard !settings.defaultOwner.isEmpty && !settings.defaultRepo.isEmpty else { return }

        loading = true

        Task {
            do {
                async let workflowsResult = GitHubService.shared.listWorkflows(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo
                )
                async let runsResult = GitHubService.shared.listWorkflowRuns(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo
                )

                let (w, r) = try await (workflowsResult, runsResult)

                await MainActor.run {
                    workflows = w
                    runs = r
                    loading = false
                }
            } catch {
                await MainActor.run {
                    loading = false
                }
            }
        }
    }
}

struct WorkflowRow: View {
    let workflow: GitHubWorkflow

    var body: some View {
        GroupBox {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.blue)
                Text(workflow.name)
                    .font(.subheadline)
                Spacer()
                Text(workflow.state)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
    }
}

struct WorkflowRunRow: View {
    let run: GitHubWorkflowRun

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    statusIcon
                    Text(run.name)
                        .font(.subheadline)
                    Spacer()
                    Button("View") {
                        if let url = URL(string: run.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text("\(run.headBranch) • \(run.status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
    }

    private var statusIcon: some View {
        Group {
            if run.status == "completed" {
                if run.conclusion == "success" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
}

// MARK: - Releases Tab

struct ReleasesTabView: View {
    @ObservedObject private var settings = GitHubSettings.shared
    @State private var releases: [GitHubRelease] = []
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: loadReleases) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(releases) { release in
                        ReleaseRow(release: release)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if releases.isEmpty {
                loadReleases()
            }
        }
    }

    private func loadReleases() {
        guard !settings.defaultOwner.isEmpty && !settings.defaultRepo.isEmpty else { return }

        loading = true

        Task {
            do {
                let result = try await GitHubService.shared.listReleases(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo
                )
                await MainActor.run {
                    releases = result
                    loading = false
                }
            } catch {
                await MainActor.run {
                    loading = false
                }
            }
        }
    }
}

struct ReleaseRow: View {
    let release: GitHubRelease

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(release.name)
                        .font(.headline)

                    if release.prerelease {
                        Text("PRE-RELEASE")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Button("View") {
                        if let url = URL(string: release.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text(release.tagName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Gists Tab

struct GistsTabView: View {
    @State private var gists: [GitHubGist] = []
    @State private var loading = false
    @State private var showingCreateGist = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: loadGists) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(loading)

                Button(action: { showingCreateGist = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Gist")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                if loading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gists) { gist in
                        GistRow(gist: gist)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateGist) {
            CreateGistView { success in
                if success {
                    loadGists()
                }
            }
        }
        .onAppear {
            if gists.isEmpty {
                loadGists()
            }
        }
    }

    private func loadGists() {
        loading = true

        Task {
            do {
                let result = try await GitHubService.shared.listGists()
                await MainActor.run {
                    gists = result
                    loading = false
                }
            } catch {
                await MainActor.run {
                    loading = false
                }
            }
        }
    }
}

struct GistRow: View {
    let gist: GitHubGist

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let description = gist.description {
                        Text(description)
                            .font(.headline)
                    } else {
                        Text("Untitled Gist")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    if !gist.isPublic {
                        Label("Secret", systemImage: "lock.fill")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Button("View") {
                        if let url = URL(string: gist.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text("\(gist.files.count) file(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Create Repository View

struct CreateRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: (Bool) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var autoInit = true
    @State private var creating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Repository")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Repository name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $description)
                    .textFieldStyle(.roundedBorder)

                Toggle("Private repository", isOn: $isPrivate)
                Toggle("Initialize with README", isOn: $autoInit)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    createRepository()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || creating)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createRepository() {
        creating = true
        error = nil

        Task {
            do {
                _ = try await GitHubService.shared.createRepository(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    isPrivate: isPrivate,
                    autoInit: autoInit
                )
                await MainActor.run {
                    onComplete(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    creating = false
                }
            }
        }
    }
}

// MARK: - Create Issue View

struct CreateIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = GitHubSettings.shared
    let onComplete: (Bool) -> Void

    @State private var title = ""
    @State private var issueBody = ""
    @State private var creating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Issue")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(settings.defaultOwner)/\(settings.defaultRepo)")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Issue title", text: $title)
                    .textFieldStyle(.roundedBorder)

                Text("Description:")
                    .font(.caption)

                TextEditor(text: $issueBody)
                    .font(.system(.body, design: .default))
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.2))
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create Issue") {
                    createIssue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || creating)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
    }

    private func createIssue() {
        creating = true
        error = nil

        Task {
            do {
                _ = try await GitHubService.shared.createIssue(
                    owner: settings.defaultOwner,
                    repo: settings.defaultRepo,
                    title: title,
                    body: issueBody.isEmpty ? nil : issueBody
                )
                await MainActor.run {
                    onComplete(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    creating = false
                }
            }
        }
    }
}

// MARK: - Create Gist View

struct CreateGistView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: (Bool) -> Void

    @State private var description = ""
    @State private var filename = "file.txt"
    @State private var content = ""
    @State private var isPublic = true
    @State private var creating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Gist")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Description (optional)", text: $description)
                    .textFieldStyle(.roundedBorder)

                TextField("Filename", text: $filename)
                    .textFieldStyle(.roundedBorder)

                Text("Content:")
                    .font(.caption)

                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 250)
                    .border(Color.gray.opacity(0.2))

                Toggle("Public gist", isOn: $isPublic)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create Gist") {
                    createGist()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filename.isEmpty || content.isEmpty || creating)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
    }

    private func createGist() {
        creating = true
        error = nil

        Task {
            do {
                _ = try await GitHubService.shared.createGist(
                    description: description,
                    files: [filename: content],
                    isPublic: isPublic
                )
                await MainActor.run {
                    onComplete(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    creating = false
                }
            }
        }
    }
}

// MARK: - Helper Extensions

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

struct GitHubPanelView_Previews: PreviewProvider {
    static var previews: some View {
        GitHubPanelView()
    }
}
