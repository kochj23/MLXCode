//
//  GitHubPanelView.swift
//  MLX Code
//
//  GitHub integration panel with issues, PRs, branches
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// GitHub integration panel
struct GitHubPanelView: View {
    @ObservedObject var viewModel = GitHubViewModel.shared

    @State private var pushResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            Divider()
                .background(ModernColors.glassBorder)

            // Repo info bar
            if let repo = viewModel.repoInfo {
                repoInfoBar(repo: repo)
                Divider()
                    .background(ModernColors.glassBorder)
            }

            // Tab bar
            tabBar

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            tabContent

            Spacer(minLength: 0)
        }
        .onAppear {
            Task { await viewModel.loadAll() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .font(.title2)
                .foregroundColor(ModernColors.accentGreen)

            Text("GitHub")
                .modernHeader(size: .small)

            Spacer()

            // Push/Pull buttons
            HStack(spacing: 8) {
                Button(action: { Task {
                    pushResult = await viewModel.push()
                }}) {
                    Label("Push", systemImage: "arrow.up")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.accentGreen, style: .filled))

                Button(action: { Task { _ = await viewModel.pull() }}) {
                    Label("Pull", systemImage: "arrow.down")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .outlined))
            }

            // Refresh
            Button(action: { Task { await viewModel.loadAll() }}) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(ModernColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Repo Info Bar

    private func repoInfoBar(repo: GitHubRepo) -> some View {
        HStack(spacing: 16) {
            Text("\(repo.owner)/\(repo.name)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text(repo.visibility)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(repo.isPublic ? ModernColors.accentGreen.opacity(0.2) : ModernColors.orange.opacity(0.2))
                .foregroundColor(repo.isPublic ? ModernColors.accentGreen : ModernColors.orange)
                .cornerRadius(4)

            Label("\(repo.stars)", systemImage: "star.fill")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(ModernColors.yellow)

            Spacer()

            // Credential scan
            Button(action: { Task { await viewModel.scanCredentials() }}) {
                Label("Scan", systemImage: "lock.shield")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .buttonStyle(.plain)
            .foregroundColor(scanColor)

            // License check
            Button(action: { Task { await viewModel.checkLicense() }}) {
                Label("License", systemImage: "doc.text")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .buttonStyle(.plain)
            .foregroundColor(licenseColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(GitHubViewModel.GitHubTab.allCases, id: \.self) { tab in
                Button(action: { viewModel.selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: viewModel.selectedTab == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(viewModel.selectedTab == tab ? ModernColors.cyan : ModernColors.textTertiary)

                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? ModernColors.cyan : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                switch viewModel.selectedTab {
                case .issues:
                    issuesContent
                case .pullRequests:
                    prsContent
                case .branches:
                    branchesContent
                case .activity:
                    activityContent
                }
            }
            .padding(12)
        }
    }

    // MARK: - Issues Tab

    private var issuesContent: some View {
        Group {
            if viewModel.issues.isEmpty {
                emptyState(icon: "checkmark.circle", message: "No open issues")
            } else {
                ForEach(viewModel.issues) { issue in
                    issueRow(issue)
                }
            }
        }
    }

    private func issueRow(_ issue: GitHubIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.isOpen ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(issue.isOpen ? ModernColors.accentGreen : ModernColors.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text("#\(issue.number) \(issue.title)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("@\(issue.author)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)

                    ForEach(issue.labels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(ModernColors.cyan.opacity(0.2))
                            .foregroundColor(ModernColors.cyan)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(8)
        .background(ModernColors.glassBackground)
        .cornerRadius(8)
    }

    // MARK: - PRs Tab

    private var prsContent: some View {
        Group {
            if viewModel.pullRequests.isEmpty {
                emptyState(icon: "arrow.triangle.pull", message: "No open pull requests")
            } else {
                ForEach(viewModel.pullRequests) { pr in
                    prRow(pr)
                }
            }
        }
    }

    private func prRow(_ pr: GitHubPR) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: pr.isMerged ? "arrow.triangle.merge" : "arrow.triangle.pull")
                .font(.system(size: 12))
                .foregroundColor(pr.isMerged ? ModernColors.purple : ModernColors.accentGreen)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(pr.number) \(pr.title)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(2)

                    if pr.isDraft {
                        Text("DRAFT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(ModernColors.textTertiary.opacity(0.3))
                            .foregroundColor(ModernColors.textTertiary)
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 8) {
                    Text("\(pr.headBranch) -> \(pr.baseBranch)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ModernColors.textTertiary)

                    Text("+\(pr.additions)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ModernColors.accentGreen)

                    Text("-\(pr.deletions)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ModernColors.statusCritical)
                }
            }
        }
        .padding(8)
        .background(ModernColors.glassBackground)
        .cornerRadius(8)
    }

    // MARK: - Branches Tab

    private var branchesContent: some View {
        Group {
            if viewModel.branches.isEmpty {
                emptyState(icon: "arrow.triangle.branch", message: "No branches found")
            } else {
                ForEach(viewModel.branches) { branch in
                    HStack(spacing: 10) {
                        Image(systemName: branch.isCurrent ? "circle.fill" : "circle")
                            .font(.system(size: 10))
                            .foregroundColor(branch.isCurrent ? ModernColors.cyan : ModernColors.textTertiary)

                        Text(branch.name)
                            .font(.system(size: 12, weight: branch.isCurrent ? .bold : .regular, design: .monospaced))
                            .foregroundColor(ModernColors.textPrimary)

                        Text("[\(branch.lastCommit)]")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(ModernColors.textTertiary)

                        if let upstream = branch.upstream {
                            Text("-> \(upstream)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(branch.isCurrent ? ModernColors.cyan.opacity(0.05) : ModernColors.glassBackground)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Activity Tab

    private var activityContent: some View {
        Group {
            if viewModel.activity.isEmpty {
                emptyState(icon: "clock", message: "No recent activity")
            } else {
                ForEach(viewModel.activity) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.hash)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(ModernColors.cyan)
                            .frame(width: 50, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(ModernColors.textPrimary)
                                .lineLimit(1)

                            HStack {
                                Text(item.author)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(ModernColors.textTertiary)

                                Text(item.date)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(ModernColors.textTertiary)
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ModernColors.textTertiary)
            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var scanColor: Color {
        guard let result = viewModel.credentialScanResult else { return ModernColors.textTertiary }
        return result.clean ? ModernColors.accentGreen : ModernColors.statusCritical
    }

    private var licenseColor: Color {
        guard let result = viewModel.licenseResult else { return ModernColors.textTertiary }
        return result.isMIT ? ModernColors.accentGreen : ModernColors.orange
    }
}
