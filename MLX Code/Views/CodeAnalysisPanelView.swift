//
//  CodeAnalysisPanelView.swift
//  MLX Code
//
//  Code analysis results panel
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Panel showing code analysis results (metrics, lint, dependencies, symbols)
struct CodeAnalysisPanelView: View {
    @ObservedObject var viewModel = CodeAnalysisViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title2)
                    .foregroundColor(ModernColors.purple)
                Text("Analysis")
                    .modernHeader(size: .small)

                Spacer()

                if viewModel.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button(action: { Task { await viewModel.runFullAnalysis() }}) {
                    Label("Analyze", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.purple, style: .filled))
                .disabled(viewModel.isAnalyzing)
            }
            .padding(16)

            Divider()
                .background(ModernColors.glassBorder)

            // Tab bar
            tabBar

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    tabContent
                }
                .padding(12)
            }
        }
        .onAppear {
            if viewModel.metrics == nil {
                Task { await viewModel.runFullAnalysis() }
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CodeAnalysisViewModel.AnalysisTab.allCases, id: \.self) { tab in
                Button(action: { viewModel.selectedTab = tab }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: viewModel.selectedTab == tab ? .bold : .medium, design: .rounded))

                            if tab == .lint && viewModel.lintErrorCount > 0 {
                                Text("\(viewModel.lintErrorCount)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(ModernColors.statusCritical)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .foregroundColor(viewModel.selectedTab == tab ? ModernColors.purple : ModernColors.textTertiary)

                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? ModernColors.purple : Color.clear)
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
        switch viewModel.selectedTab {
        case .metrics:
            metricsContent
        case .dependencies:
            dependenciesContent
        case .lint:
            lintContent
        case .symbols:
            symbolsContent
        }
    }

    // MARK: - Metrics Tab

    private var metricsContent: some View {
        Group {
            if let metrics = viewModel.metrics {
                // Overview cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    metricCard(label: "Files", value: "\(metrics.totalFiles)", color: ModernColors.cyan)
                    metricCard(label: "Lines", value: formatCount(metrics.totalLines), color: ModernColors.accentGreen)
                    metricCard(label: "Code", value: formatCount(metrics.codeLines), color: ModernColors.purple)
                    metricCard(label: "Comments", value: "\(String(format: "%.0f", metrics.commentRatio))%", color: ModernColors.yellow)
                }

                // Languages
                if !metrics.languages.isEmpty {
                    sectionHeader("Languages")
                    ForEach(metrics.languages.sorted(by: { $0.value > $1.value }), id: \.key) { lang, count in
                        HStack {
                            Text(lang)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(ModernColors.textPrimary)
                            Spacer()
                            Text("\(count) files")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                        .padding(.horizontal, 8)
                    }
                }

                // Largest files
                if !metrics.largestFiles.isEmpty {
                    sectionHeader("Largest Files")
                    ForEach(metrics.largestFiles.prefix(10)) { file in
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                                .foregroundColor(ModernColors.textTertiary)
                            Text(file.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(ModernColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(file.lines) lines")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                        .padding(.horizontal, 8)
                    }
                }
            } else {
                emptyState("Run analysis to see code metrics")
            }
        }
    }

    // MARK: - Dependencies Tab

    private var dependenciesContent: some View {
        Group {
            // Framework dependencies
            if !viewModel.frameworkDependencies.isEmpty {
                sectionHeader("Package Dependencies (\(viewModel.frameworkDependencies.count))")
                ForEach(viewModel.frameworkDependencies) { dep in
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 11))
                            .foregroundColor(ModernColors.purple)

                        Text(dep.name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(ModernColors.textPrimary)

                        if let version = dep.version {
                            Text("v\(version)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()

                        Text(dep.manager.rawValue)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ModernColors.purple.opacity(0.2))
                            .foregroundColor(ModernColors.purple)
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .background(ModernColors.glassBackground)
                    .cornerRadius(8)
                }
            }

            // Internal dependencies
            if !viewModel.dependencyNodes.isEmpty {
                let nodesWithDeps = viewModel.dependencyNodes.filter { !$0.externalDependencies.isEmpty }
                if !nodesWithDeps.isEmpty {
                    sectionHeader("Internal Dependencies")
                    ForEach(nodesWithDeps.prefix(20)) { node in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(ModernColors.textPrimary)

                            if !node.externalDependencies.isEmpty {
                                Text("Imports: \(node.externalDependencies.joined(separator: ", "))")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(ModernColors.textTertiary)
                            }
                        }
                        .padding(6)
                    }
                }
            }

            if viewModel.frameworkDependencies.isEmpty && viewModel.dependencyNodes.isEmpty {
                emptyState("No dependencies found")
            }
        }
    }

    // MARK: - Lint Tab

    private var lintContent: some View {
        Group {
            if viewModel.lintViolations.isEmpty {
                emptyState("No lint violations (or SwiftLint not installed)")
            } else {
                // Summary
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernColors.statusCritical)
                        Text("\(viewModel.lintErrorCount) errors")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(ModernColors.statusCritical)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ModernColors.yellow)
                        Text("\(viewModel.lintWarningCount) warnings")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(ModernColors.yellow)
                    }
                }
                .padding(8)

                // Violations list
                ForEach(viewModel.lintViolations.prefix(50)) { violation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: violation.isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(violation.isError ? ModernColors.statusCritical : ModernColors.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(violation.file):\(violation.line)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(ModernColors.textTertiary)

                            Text(violation.reason)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(ModernColors.textPrimary)
                                .lineLimit(2)

                            Text(violation.ruleId)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                    }
                    .padding(6)
                    .background(ModernColors.glassBackground)
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Symbols Tab

    private var symbolsContent: some View {
        Group {
            if let index = viewModel.symbolIndex {
                // Summary
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    symbolCard(label: "Classes", count: index.classes.count, icon: "c.square", color: ModernColors.cyan)
                    symbolCard(label: "Structs", count: index.structs.count, icon: "s.square", color: ModernColors.accentGreen)
                    symbolCard(label: "Protocols", count: index.protocols.count, icon: "p.square", color: ModernColors.purple)
                    symbolCard(label: "Functions", count: index.functions.count, icon: "f.square", color: ModernColors.yellow)
                    symbolCard(label: "Properties", count: index.properties.count, icon: "v.square", color: ModernColors.orange)
                    symbolCard(label: "Total", count: index.totalSymbols, icon: "number.square", color: ModernColors.textSecondary)
                }

                // File count
                Text("\(index.fileCount) source files indexed")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
                    .padding(.top, 8)
            } else {
                emptyState("Index project to see symbols")
            }
        }
    }

    // MARK: - Components

    private func metricCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(ModernColors.glassBackground)
        .cornerRadius(12)
    }

    private func symbolCard(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ModernColors.glassBackground)
        .cornerRadius(8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(ModernColors.textSecondary)
            .padding(.top, 8)
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 24))
                .foregroundColor(ModernColors.textTertiary)
            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}
