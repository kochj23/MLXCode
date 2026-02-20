//
//  BuildPanelView.swift
//  MLX Code
//
//  Build control panel with streaming output
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Build control panel with real-time output streaming
struct BuildPanelView: View {
    @ObservedObject var projectVM = ProjectViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hammer.circle.fill")
                    .font(.title2)
                    .foregroundColor(ModernColors.cyan)
                Text("Build")
                    .modernHeader(size: .small)
                Spacer()

                buildStateIndicator
            }
            .padding(16)

            Divider()
                .background(ModernColors.glassBorder)

            // Controls
            HStack(spacing: 12) {
                // Scheme picker
                if !projectVM.schemes.isEmpty {
                    Picker("Scheme", selection: Binding(
                        get: { projectVM.selectedScheme ?? "" },
                        set: { projectVM.selectedScheme = $0.isEmpty ? nil : $0 }
                    )) {
                        ForEach(projectVM.schemes, id: \.self) { scheme in
                            Text(scheme).tag(scheme)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                // Configuration picker
                Picker("Config", selection: $projectVM.selectedConfiguration) {
                    Text("Debug").tag("Debug")
                    Text("Release").tag("Release")
                }
                .frame(maxWidth: 120)

                Spacer()

                // Action buttons
                Button(action: { Task { await projectVM.startBuild() } }) {
                    Label("Build", systemImage: "hammer.fill")
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))
                .disabled(projectVM.buildState.isActive)

                Button(action: { Task { await projectVM.startDeploy() } }) {
                    Label("Deploy", systemImage: "arrow.up.doc.fill")
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.accentGreen, style: .filled))
                .disabled(projectVM.buildState.isActive)
            }
            .padding(12)

            Divider()
                .background(ModernColors.glassBorder)

            // Version controls
            if let versionInfo = projectVM.versionInfo {
                HStack(spacing: 12) {
                    Text("v\(versionInfo.marketing) build \(versionInfo.build)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(ModernColors.textSecondary)

                    Spacer()

                    Text("Bump:")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)

                    ForEach(["major", "minor", "patch", "build"], id: \.self) { component in
                        Button(component.capitalized) {
                            if let vc = VersionComponent(rawValue: component) {
                                Task { await projectVM.bumpVersion(component: vc) }
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ModernColors.glassBackground)
                        .foregroundColor(ModernColors.textSecondary)
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .background(ModernColors.glassBorder)
            }

            // Build output log
            buildOutputLog
        }
    }

    // MARK: - Components

    private var buildStateIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .shadow(color: stateColor, radius: 4)

            Text(projectVM.buildState.displayName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(stateColor)

            if projectVM.buildState.isActive {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
    }

    private var buildOutputLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(projectVM.buildOutputLines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            lineIcon(for: line.type)

                            Text(line.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(lineColor(for: line.type))
                                .textSelection(.enabled)
                        }
                        .id(line.id)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                    }

                    // Summary at bottom
                    if let summary = projectVM.lastBuildSummary, !projectVM.buildState.isActive {
                        Divider()
                            .background(ModernColors.glassBorder)
                            .padding(.vertical, 8)

                        Text(summary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(stateColor)
                            .padding(.horizontal, 12)
                            .id("summary")
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.3))
            .onChange(of: projectVM.buildOutputLines.count) { _, _ in
                if let lastLine = projectVM.buildOutputLines.last {
                    withAnimation {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch projectVM.buildState {
        case .succeeded: return ModernColors.statusLow
        case .failed: return ModernColors.statusCritical
        case .idle: return ModernColors.textTertiary
        default: return ModernColors.cyan
        }
    }

    private func lineColor(for type: BuildOutputLine.OutputType) -> Color {
        switch type {
        case .info: return ModernColors.textTertiary
        case .warning: return ModernColors.yellow
        case .error: return ModernColors.statusCritical
        case .progress: return ModernColors.cyan
        }
    }

    @ViewBuilder
    private func lineIcon(for type: BuildOutputLine.OutputType) -> some View {
        switch type {
        case .info:
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(ModernColors.textTertiary)
                .frame(width: 12)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundColor(ModernColors.yellow)
                .frame(width: 12)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 9))
                .foregroundColor(ModernColors.statusCritical)
                .frame(width: 12)
        case .progress:
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 9))
                .foregroundColor(ModernColors.cyan)
                .frame(width: 12)
        }
    }
}
