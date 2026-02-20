//
//  ProjectViewModel.swift
//  MLX Code
//
//  State management for project build and version operations
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Manages project build state and operations
@MainActor
class ProjectViewModel: ObservableObject {
    /// Shared instance
    static let shared = ProjectViewModel()

    // MARK: - Published Properties

    /// Current build state
    @Published var buildState: BuildState = .idle

    /// Build output lines (streaming)
    @Published var buildOutputLines: [BuildOutputLine] = []

    /// Build errors/warnings
    @Published var buildIssues: [BuildOutputLine] = []

    /// Current version info
    @Published var versionInfo: VersionInfo?

    /// Last build result summary
    @Published var lastBuildSummary: String?

    /// Detected project path
    @Published var projectPath: String?

    /// Available schemes
    @Published var schemes: [String] = []

    /// Selected scheme
    @Published var selectedScheme: String?

    /// Selected configuration
    @Published var selectedConfiguration: String = "Debug"

    // MARK: - Build State Enum

    enum BuildState: Equatable {
        case idle
        case building
        case archiving
        case creatingDMG
        case installing
        case exporting
        case succeeded
        case failed(String)

        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .building: return "Building..."
            case .archiving: return "Archiving..."
            case .creatingDMG: return "Creating DMG..."
            case .installing: return "Installing..."
            case .exporting: return "Exporting..."
            case .succeeded: return "Build Succeeded"
            case .failed: return "Build Failed"
            }
        }

        var isActive: Bool {
            switch self {
            case .idle, .succeeded, .failed: return false
            default: return true
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Project Detection

    /// Detects and loads project info
    func detectProject(at path: String? = nil) async {
        let searchPath = path ?? "/Volumes/Data/xcode/MLX Code"

        do {
            if let detected = try await ContextAnalysisService.shared.detectActiveProject(from: searchPath) {
                projectPath = detected

                let xcodeService = XcodeService.shared
                try await xcodeService.setProject(path: detected)

                // Load schemes
                schemes = try await xcodeService.listSchemes()
                if selectedScheme == nil {
                    selectedScheme = schemes.first
                }

                // Load version info
                versionInfo = try? await xcodeService.getVersionInfo()
            }
        } catch {
            lastBuildSummary = "Project detection failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Build Operations

    /// Starts a streaming build
    func startBuild() async {
        guard let projectPath = projectPath else {
            lastBuildSummary = "No project detected"
            return
        }

        buildState = .building
        buildOutputLines = []
        buildIssues = []

        do {
            let xcodeService = XcodeService.shared
            try await xcodeService.setProject(path: projectPath)

            let stream = await xcodeService.streamingBuild(
                scheme: selectedScheme,
                configuration: selectedConfiguration
            )

            for await output in stream {
                switch output {
                case .line(let text):
                    buildOutputLines.append(BuildOutputLine(text: text, type: .info))
                case .warning(let text):
                    let line = BuildOutputLine(text: text, type: .warning)
                    buildOutputLines.append(line)
                    buildIssues.append(line)
                case .error(let text):
                    let line = BuildOutputLine(text: text, type: .error)
                    buildOutputLines.append(line)
                    buildIssues.append(line)
                case .progress(let text):
                    buildOutputLines.append(BuildOutputLine(text: text, type: .progress))
                case .complete(let success):
                    buildState = success ? .succeeded : .failed("Build failed")
                    let warnings = buildIssues.filter { $0.type == .warning }.count
                    let errors = buildIssues.filter { $0.type == .error }.count
                    lastBuildSummary = success
                        ? "Build succeeded (\(warnings) warnings)"
                        : "Build failed (\(errors) errors, \(warnings) warnings)"
                }
            }
        } catch {
            buildState = .failed(error.localizedDescription)
            lastBuildSummary = "Build error: \(error.localizedDescription)"
        }
    }

    /// Runs the full deploy pipeline
    func startDeploy() async {
        guard let projectPath = projectPath, let scheme = selectedScheme else {
            lastBuildSummary = "No project or scheme selected"
            return
        }

        buildState = .building
        buildOutputLines = []
        buildIssues = []

        do {
            let xcodeService = XcodeService.shared
            try await xcodeService.setProject(path: projectPath)

            buildState = .building
            buildOutputLines.append(BuildOutputLine(text: "Starting full deploy pipeline...", type: .progress))

            let result = try await xcodeService.fullBuildPipeline(
                scheme: scheme,
                configuration: "Release",
                bumpVersion: .patch
            )

            buildState = .succeeded
            versionInfo = VersionInfo(marketing: result.version, build: result.build, bundleId: versionInfo?.bundleId ?? "")

            var summary = "Deploy Complete: v\(result.version) build \(result.build)"
            summary += "\nDMG: \(result.dmgPath)"
            summary += "\nInstalled: \(result.installedPath)"
            if let local = result.exportResult.localBinaryPath {
                summary += "\nLocal: \(local)"
            }
            if let nas = result.exportResult.nasBinaryPath {
                summary += "\nNAS: \(nas)"
            }

            lastBuildSummary = summary

        } catch {
            buildState = .failed(error.localizedDescription)
            lastBuildSummary = "Deploy error: \(error.localizedDescription)"
        }
    }

    /// Bumps version number
    func bumpVersion(component: VersionComponent) async {
        guard projectPath != nil else { return }

        do {
            let xcodeService = XcodeService.shared
            versionInfo = try await xcodeService.incrementVersion(component: component)
        } catch {
            lastBuildSummary = "Version bump failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

/// A line of build output
struct BuildOutputLine: Identifiable {
    let id = UUID()
    let text: String
    let type: OutputType
    let timestamp = Date()

    enum OutputType {
        case info
        case warning
        case error
        case progress
    }
}
