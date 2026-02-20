//
//  ProjectDashboardView.swift
//  MLX Code
//
//  Project overview dashboard panel
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Dashboard showing project overview and quick actions
struct ProjectDashboardView: View {
    @ObservedObject var projectVM = ProjectViewModel.shared
    @ObservedObject var githubVM = GitHubViewModel.shared
    @ObservedObject var analysisVM = CodeAnalysisViewModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "hammer.circle.fill")
                        .font(.title)
                        .foregroundColor(ModernColors.cyan)
                    Text("Project Dashboard")
                        .modernHeader(size: .medium)
                    Spacer()

                    // Refresh button
                    Button(action: { Task { await refreshAll() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Version & Status Card
                HStack(spacing: 16) {
                    versionCard
                    buildStatusCard
                }

                // Quick Actions
                quickActionsCard

                // Git Status Summary
                if let repo = githubVM.repoInfo {
                    gitSummaryCard(repo: repo)
                }

                // Metrics Summary
                if let metrics = analysisVM.metrics {
                    metricsSummaryCard(metrics: metrics)
                }
            }
            .padding(20)
        }
        .onAppear {
            Task {
                await projectVM.detectProject()
                await refreshAll()
            }
        }
    }

    // MARK: - Cards

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(ModernColors.cyan)
                Text("Version")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }

            if let info = projectVM.versionInfo {
                Text("v\(info.marketing)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Build \(info.build)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                Text("--")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var buildStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hammer")
                    .foregroundColor(statusColor)
                Text("Build Status")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Text(projectVM.buildState.displayName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(statusColor)

            if let summary = projectVM.lastBuildSummary {
                Text(summary)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            HStack(spacing: 12) {
                actionButton(title: "Build", icon: "hammer.fill", color: ModernColors.cyan) {
                    Task { await projectVM.startBuild() }
                }

                actionButton(title: "Deploy", icon: "arrow.up.doc.fill", color: ModernColors.accentGreen) {
                    Task { await projectVM.startDeploy() }
                }

                actionButton(title: "Analyze", icon: "magnifyingglass.circle.fill", color: ModernColors.purple) {
                    Task { await analysisVM.runFullAnalysis() }
                }

                actionButton(title: "Push", icon: "arrow.up.circle.fill", color: ModernColors.accentOrange) {
                    Task { _ = await githubVM.push() }
                }
            }
        }
        .glassCard()
    }

    private func gitSummaryCard(repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(ModernColors.accentGreen)
                Text("GitHub")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(repo.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)

                    HStack(spacing: 12) {
                        Label("\(repo.stars)", systemImage: "star.fill")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.yellow)

                        Label("\(repo.forks)", systemImage: "tuningfork")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.textTertiary)

                        Text(repo.visibility)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(repo.isPublic ? ModernColors.accentGreen.opacity(0.2) : ModernColors.orange.opacity(0.2))
                            .foregroundColor(repo.isPublic ? ModernColors.accentGreen : ModernColors.orange)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(githubVM.issues.count) issues")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)

                    Text("\(githubVM.pullRequests.count) PRs")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }
        }
        .glassCard()
    }

    private func metricsSummaryCard(metrics: CodeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ModernColors.purple)
                Text("Code Metrics")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }

            HStack(spacing: 24) {
                metricItem(label: "Files", value: "\(metrics.totalFiles)", color: ModernColors.cyan)
                metricItem(label: "Lines", value: formatCount(metrics.totalLines), color: ModernColors.accentGreen)
                metricItem(label: "Code", value: formatCount(metrics.codeLines), color: ModernColors.purple)
                metricItem(label: "Comments", value: "\(String(format: "%.0f", metrics.commentRatio))%", color: ModernColors.yellow)
            }
        }
        .glassCard()
    }

    // MARK: - Components

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(projectVM.buildState.isActive)
    }

    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(ModernColors.textTertiary)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch projectVM.buildState {
        case .succeeded: return ModernColors.statusLow
        case .failed: return ModernColors.statusCritical
        case .idle: return ModernColors.textTertiary
        default: return ModernColors.cyan
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func refreshAll() async {
        await githubVM.loadRepoInfo()
        await githubVM.loadIssues()
        await githubVM.loadPullRequests()
        await analysisVM.loadMetrics()
    }
}
