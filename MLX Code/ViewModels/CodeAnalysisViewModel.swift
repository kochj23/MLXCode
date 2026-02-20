//
//  CodeAnalysisViewModel.swift
//  MLX Code
//
//  State management for code analysis features
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Manages code analysis state for the UI
@MainActor
class CodeAnalysisViewModel: ObservableObject {
    /// Shared instance
    static let shared = CodeAnalysisViewModel()

    // MARK: - Published Properties

    /// Code metrics
    @Published var metrics: CodeMetrics?

    /// Dependency graph nodes
    @Published var dependencyNodes: [DependencyNode] = []

    /// Framework dependencies
    @Published var frameworkDependencies: [FrameworkDependency] = []

    /// Lint violations
    @Published var lintViolations: [LintViolation] = []

    /// Symbol index stats
    @Published var symbolIndex: SymbolIndex?

    /// Loading state
    @Published var isAnalyzing = false

    /// Error message
    @Published var errorMessage: String?

    /// Selected analysis tab
    @Published var selectedTab: AnalysisTab = .metrics

    // MARK: - Tab Enum

    enum AnalysisTab: String, CaseIterable {
        case metrics = "Metrics"
        case dependencies = "Dependencies"
        case lint = "Lint"
        case symbols = "Symbols"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Analysis Operations

    /// Runs full analysis
    func runFullAnalysis(projectPath: String? = nil) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        let path = projectPath ?? "/Volumes/Data/xcode/MLX Code"
        _ = try? await ContextAnalysisService.shared.detectActiveProject(from: path)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMetrics() }
            group.addTask { await self.loadDependencyGraph() }
            group.addTask { await self.loadFrameworkDependencies() }
            group.addTask { await self.loadLintResults() }
            group.addTask { await self.loadSymbolIndex() }
        }
    }

    /// Loads code metrics
    func loadMetrics() async {
        do {
            metrics = try await ContextAnalysisService.shared.getCodeMetrics()
        } catch {
            errorMessage = "Metrics failed: \(error.localizedDescription)"
        }
    }

    /// Loads dependency graph
    func loadDependencyGraph() async {
        do {
            dependencyNodes = try await ContextAnalysisService.shared.getDependencyGraph()
        } catch {
            errorMessage = "Dependency graph failed: \(error.localizedDescription)"
        }
    }

    /// Loads framework dependencies
    func loadFrameworkDependencies() async {
        do {
            frameworkDependencies = try await ContextAnalysisService.shared.getFrameworkDependencies()
        } catch {
            errorMessage = "Framework deps failed: \(error.localizedDescription)"
        }
    }

    /// Loads SwiftLint results
    func loadLintResults() async {
        do {
            lintViolations = try await ContextAnalysisService.shared.runSwiftLint()
        } catch {
            errorMessage = "SwiftLint failed: \(error.localizedDescription)"
        }
    }

    /// Loads symbol index
    func loadSymbolIndex() async {
        do {
            symbolIndex = try await ContextAnalysisService.shared.indexProject(force: true)
        } catch {
            errorMessage = "Indexing failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    /// Lint error count
    var lintErrorCount: Int { lintViolations.filter { $0.isError }.count }

    /// Lint warning count
    var lintWarningCount: Int { lintViolations.filter { $0.isWarning }.count }
}
