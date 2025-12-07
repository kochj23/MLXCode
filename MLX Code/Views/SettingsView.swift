//
//  SettingsView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Settings panel view
struct SettingsView: View {
    /// App settings
    @ObservedObject private var settings = AppSettings.shared

    /// Whether to show file picker for Python path
    @State private var showingPythonPathPicker = false

    /// Dismiss action
    @Environment(\.dismiss) private var dismiss

    /// Model being downloaded
    @State private var downloadingModelId: UUID?

    /// Download progress for models
    @State private var downloadProgress: [UUID: Double] = [:]

    /// Download status messages
    @State private var downloadStatus: [UUID: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    print("🔴🔴🔴 SETTINGS CLOSE BUTTON CLICKED")
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Text("Close")
                            .font(.body)
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close settings (ESC)")
            }
            .padding()

            Divider()

            // Tab view with settings
            TabView {
                // General settings
                generalSettings
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }

                // Model settings
                modelSettings
                    .tabItem {
                        Label("Model", systemImage: "cpu")
                    }

                // Appearance settings
                appearanceSettings
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }

                // Paths settings
                PathsSettingsView()
                    .tabItem {
                        Label("Paths", systemImage: "folder")
                    }

                // Python MLX settings available in MLXPythonToolkitSettings.swift
                // To enable: Add tab with MLXPythonToolkitSettingsView()

                // Tools settings
                toolsSettings
                    .tabItem {
                        Label("Tools", systemImage: "hammer")
                    }

                // Advanced settings
                advancedSettings
                    .tabItem {
                        Label("Advanced", systemImage: "wrench")
                    }
            }
            .padding(.horizontal)
        }
        .frame(width: 650, height: 550)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Auto-Save Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Auto-Save")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Toggle("Enable Auto-Save", isOn: $settings.enableAutoSave)
                        .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto-Save Interval")
                                .frame(width: 140, alignment: .leading)
                            Text("\(Int(settings.autoSaveInterval))s")
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        Slider(value: $settings.autoSaveInterval, in: 5...300, step: 5)
                            .frame(maxWidth: 400)
                    }
                    .disabled(!settings.enableAutoSave)
                }

                Divider()

                // Conversation History Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Conversation History")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        Text("Maximum Conversations")
                            .frame(width: 180, alignment: .leading)
                        Text("\(settings.maxConversationHistory)")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        Stepper("", value: $settings.maxConversationHistory, in: 10...1000, step: 10)
                            .labelsHidden()
                    }
                }

                Spacer()

                Divider()

                // Reset button
                HStack {
                    Spacer()
                    Button("Reset to Defaults", role: .destructive) {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Model Settings

    private var modelSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Generation Parameters Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Generation Parameters")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Temperature
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .frame(width: 120, alignment: .leading)
                            Text(String(format: "%.2f", settings.temperature))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $settings.temperature, in: 0.0...2.0, step: 0.1)
                            .frame(maxWidth: 400)
                        Text("Higher values make output more random")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Max Tokens
                    HStack {
                        Text("Max Tokens")
                            .frame(width: 120, alignment: .leading)
                        Text("\(settings.maxTokens)")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        Stepper("", value: $settings.maxTokens, in: 128...100_000, step: 128)
                            .labelsHidden()
                    }

                    // Top-P
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Top-P")
                                .frame(width: 120, alignment: .leading)
                            Text(String(format: "%.2f", settings.topP))
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $settings.topP, in: 0.0...1.0, step: 0.05)
                            .frame(maxWidth: 400)
                        Text("Nucleus sampling threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Top-K
                    HStack {
                        Text("Top-K")
                            .frame(width: 120, alignment: .leading)
                        Text("\(settings.topK)")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        Stepper("", value: $settings.topK, in: 1...1000, step: 10)
                            .labelsHidden()
                    }
                }

                Divider()

                // Available Models Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Models")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(spacing: 8) {
                        ForEach(settings.availableModels) { model in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        if let description = model.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    // Download status
                                    if downloadingModelId == model.id {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .controlSize(.small)
                                            Text("\(Int((downloadProgress[model.id] ?? 0.0) * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else if model.isDownloaded {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    } else {
                                        Button("Download") {
                                            downloadModel(model)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                // Download progress bar
                                if downloadingModelId == model.id {
                                    VStack(spacing: 4) {
                                        ProgressView(value: downloadProgress[model.id] ?? 0.0)
                                            .progressViewStyle(.linear)

                                        if let status = downloadStatus[model.id] {
                                            Text(status)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Appearance Settings

    private var appearanceSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Picker("Appearance", selection: $settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                // Text Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Text")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                                .frame(width: 120, alignment: .leading)
                            Text("\(Int(settings.fontSize))pt")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $settings.fontSize, in: 8...72, step: 1)
                            .frame(maxWidth: 400)
                    }

                    Toggle("Enable Syntax Highlighting", isOn: $settings.enableSyntaxHighlighting)
                        .toggleStyle(.switch)
                }

                Divider()

                // Preview Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sample Text")
                            .font(.system(size: settings.fontSize))

                        Text("func example() -> String { return \"Hello\" }")
                            .font(.system(size: settings.fontSize, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tools Settings

    private var toolsSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tools Enable/Disable Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tool Execution")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Toggle("Enable Tools", isOn: $settings.enableTools)
                        .toggleStyle(.switch)

                    Text("Allow the LLM to use tools like file operations, code search, bash commands, and Xcode builds.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Working Directory Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Working Directory")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Working directory path", text: $settings.workingDirectory)
                        .textFieldStyle(.roundedBorder)

                    Text("Default directory for tool operations. Tools will execute relative to this path.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!settings.enableTools)

                Divider()

                // Project Path Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Path (Optional)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Xcode project path", text: Binding(
                        get: { settings.projectPath ?? "" },
                        set: { settings.projectPath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Text("Path to your Xcode project. If not set, tools will auto-detect from working directory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!settings.enableTools)

                Divider()

                // Available Tools Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Tools")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        ToolInfoRow(name: "File Operations", icon: "doc.text", description: "Read, write, edit, list, delete files")
                        ToolInfoRow(name: "Bash", icon: "terminal", description: "Execute shell commands")
                        ToolInfoRow(name: "Grep", icon: "magnifyingglass", description: "Search code content")
                        ToolInfoRow(name: "Glob", icon: "folder.badge.questionmark", description: "Find files by pattern")
                        ToolInfoRow(name: "Xcode", icon: "hammer", description: "Build, test, clean projects")
                    }
                }

                Divider()

                // Tool Execution History
                if settings.enableTools {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Tool Executions")
                            .font(.headline)
                            .foregroundColor(.primary)

                        let history = ToolRegistry.shared.getRecentExecutions(count: 5)
                        if history.isEmpty {
                            Text("No tool executions yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(history) { execution in
                                    HStack {
                                        Text(execution.summary)
                                            .font(.caption)
                                            .foregroundColor(execution.success ? .primary : .red)
                                        Spacer()
                                        Text(execution.timestamp, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Advanced Settings

    private var advancedSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Python Environment Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Python Environment")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Python Path")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Path to Python executable", text: $settings.pythonPath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                showingPythonPathPicker = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if !settings.validatePythonPath() {
                            Label("Invalid Python path", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        } else {
                            Label("Valid Python path", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }

                    Button("Check Python Environment") {
                        Task {
                            await checkPythonEnvironment()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Developer Tools Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Developer Tools")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: openConsoleApp) {
                            HStack {
                                Image(systemName: "terminal")
                                Text("View Logs in Console")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: 300)

                        Button(action: openApplicationSupportFolder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Open Application Support Folder")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: 300)

                        Button(role: .destructive, action: {
                            // TODO: Implement confirmation dialog
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear All Conversations")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: 300)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fileImporter(
            isPresented: $showingPythonPathPicker,
            allowedContentTypes: [.executable],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    settings.pythonPath = url.path
                }
            case .failure(let error):
                print("File picker error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Checks the Python environment and displays info
    private func checkPythonEnvironment() async {
        do {
            let info = try await PythonService.shared.getPythonInfo()

            let alert = NSAlert()
            alert.messageText = "Python Environment"
            alert.informativeText = """
            Version: \(info["version"] ?? "Unknown")
            Path: \(info["path"] ?? "Unknown")
            """
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to check Python environment: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Opens the Console app to view logs
    private func openConsoleApp() {
        let consoleURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
        NSWorkspace.shared.openApplication(at: consoleURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Opens the application support folder in Finder
    private func openApplicationSupportFolder() {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let mlxCodeFolder = appSupport.appendingPathComponent("MLX Code")

            // Create if doesn't exist
            try? fileManager.createDirectory(at: mlxCodeFolder, withIntermediateDirectories: true)

            NSWorkspace.shared.open(mlxCodeFolder)
        }
    }

    /// Downloads a model with progress tracking
    /// - Parameter model: The model to download
    private func downloadModel(_ model: MLXModel) {
        Task {
            // Set downloading state
            await MainActor.run {
                downloadingModelId = model.id
                downloadProgress[model.id] = 0.0
                downloadStatus[model.id] = "Preparing download..."
            }

            do {
                // Download with progress updates and get updated model with correct path
                let updatedModel = try await MLXService.shared.downloadModel(model) { progress in
                    Task { @MainActor in
                        downloadProgress[model.id] = progress

                        // Update status message based on progress
                        if progress < 0.1 {
                            downloadStatus[model.id] = "Initializing download..."
                        } else if progress < 1.0 {
                            if let sizeInBytes = model.sizeInBytes {
                                let mbDownloaded = Int(progress * Double(sizeInBytes) / 1_000_000)
                                let mbTotal = Int(sizeInBytes / 1_000_000)
                                downloadStatus[model.id] = "Downloading... \(mbDownloaded) / \(mbTotal) MB"
                            } else {
                                downloadStatus[model.id] = "Downloading..."
                            }
                        } else {
                            downloadStatus[model.id] = "Download complete!"
                        }
                    }
                }

                // Update model with correct path and mark as downloaded
                var downloadedModel: MLXModel?
                await MainActor.run {
                    if let index = settings.availableModels.firstIndex(where: { $0.id == model.id }) {
                        var modelToUpdate = updatedModel
                        modelToUpdate.isDownloaded = true
                        settings.availableModels[index] = modelToUpdate

                        // Update selected model if it's the one we just downloaded
                        if settings.selectedModel?.id == model.id {
                            settings.selectedModel = modelToUpdate
                        }

                        downloadedModel = modelToUpdate
                    }
                }

                logInfo("Model downloaded successfully: \(model.name) at path: \(updatedModel.path)", category: "Settings")

                // Automatically load the model after download if it's selected
                if let modelToLoad = downloadedModel, settings.selectedModel?.id == modelToLoad.id {
                    logInfo("Automatically loading downloaded model: \(modelToLoad.name)", category: "Settings")

                    do {
                        try await MLXService.shared.loadModel(modelToLoad)
                        logInfo("Model loaded successfully: \(modelToLoad.name)", category: "Settings")
                    } catch {
                        logError("Failed to auto-load model: \(error.localizedDescription)", category: "Settings")
                    }
                }

                // Show success briefly
                await MainActor.run {
                    downloadStatus[model.id] = "✓ Download complete"
                }

                // Wait a moment then clear
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            } catch {
                logError("Model download error: \(error.localizedDescription)", category: "Settings")

                await MainActor.run {
                    downloadStatus[model.id] = "Download failed: \(error.localizedDescription)"
                }

                // Show error briefly
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }

            // Clear downloading state
            await MainActor.run {
                downloadingModelId = nil
                downloadProgress[model.id] = nil
                downloadStatus[model.id] = nil
            }
        }
    }
}

// MARK: - Tool Info Row

struct ToolInfoRow: View {
    let name: String
    let icon: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
