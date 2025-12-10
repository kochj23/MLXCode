//
//  PathsSettingsView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for managing path preferences
struct PathsSettingsView: View {
    /// App settings
    @ObservedObject private var settings = AppSettings.shared

    /// File picker presentation states
    @State private var showingXcodeProjectsPicker = false
    @State private var showingWorkspacePicker = false
    @State private var showingModelsPicker = false
    @State private var showingTemplatesPicker = false
    @State private var showingConversationsPicker = false

    /// Permission error alert
    @State private var showingPermissionAlert = false
    @State private var permissionErrors: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project Paths Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Project Paths")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Xcode Projects Path
                    pathRow(
                        title: "Xcode Projects",
                        path: $settings.xcodeProjectsPath,
                        showingPicker: $showingXcodeProjectsPicker,
                        description: "Default location for Xcode projects"
                    )

                    // Workspace Path
                    pathRow(
                        title: "Workspace",
                        path: $settings.workspacePath,
                        showingPicker: $showingWorkspacePicker,
                        description: "Default workspace directory"
                    )
                }

                Divider()

                // Storage Paths Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Storage Paths")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Models Path
                    pathRow(
                        title: "Models",
                        path: $settings.modelsPath,
                        showingPicker: $showingModelsPicker,
                        description: "Custom model storage directory"
                    )

                    // Templates Path
                    pathRow(
                        title: "Templates",
                        path: $settings.templatesPath,
                        showingPicker: $showingTemplatesPicker,
                        description: "Template export/import directory"
                    )

                    // Conversations Export Path
                    pathRow(
                        title: "Conversations",
                        path: $settings.conversationsExportPath,
                        showingPicker: $showingConversationsPicker,
                        description: "Conversation export directory"
                    )
                }

                Spacer()

                Divider()

                // Reset button
                HStack {
                    Spacer()
                    Button("Reset All Paths to Defaults", role: .destructive) {
                        resetPaths()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            checkAllPermissions()
        }
        .alert("Permission Errors Detected", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text(formatPermissionErrors())
        }
    }

    // MARK: - Path Row Component

    /// Creates a row for a path setting with text field, buttons, and validation
    /// - Parameters:
    ///   - title: Label for the path
    ///   - path: Binding to the path string
    ///   - showingPicker: Binding to file picker presentation state
    ///   - description: Optional description text
    /// - Returns: View containing the path row
    @ViewBuilder
    private func pathRow(
        title: String,
        path: Binding<String>,
        showingPicker: Binding<Bool>,
        description: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            // Path input and buttons
            HStack(spacing: 8) {
                TextField("Path", text: path)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)

                Button("Choose...") {
                    showingPicker.wrappedValue = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: {
                    settings.openInFinder(path.wrappedValue)
                }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!settings.validateDirectoryPath(path.wrappedValue))
                .help("Open in Finder")
            }

            // Description
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Validation status
            if !settings.validateDirectoryPath(path.wrappedValue) {
                Label("Directory does not exist", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            } else if !settings.hasWritePermission(for: path.wrappedValue) {
                HStack {
                    Label("No write permission", systemImage: "exclamationmark.octagon.fill")
                        .foregroundColor(.red)
                        .font(.caption)

                    Button("Fix...") {
                        showPermissionFixOptions(for: title, path: path.wrappedValue)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            } else {
                Label("Valid directory with write access", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .fileImporter(
            isPresented: showingPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFilePickerResult(result, path: path)
        }
    }

    // MARK: - Helper Methods

    /// Handles the result of file picker selection
    /// - Parameters:
    ///   - result: Result from file picker
    ///   - path: Binding to update with selected path
    private func handleFilePickerResult(_ result: Result<[URL], Error>, path: Binding<String>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Convert to tilde path if in home directory
                let fileManager = FileManager.default
                if let homeDirectory = fileManager.homeDirectoryForCurrentUser.path as String?,
                   url.path.hasPrefix(homeDirectory) {
                    let relativePath = url.path.replacingOccurrences(of: homeDirectory, with: "~")
                    path.wrappedValue = relativePath
                } else {
                    path.wrappedValue = url.path
                }
            }
        case .failure(let error):
            print("File picker error: \(error.localizedDescription)")
        }
    }

    /// Resets all path settings to their defaults
    private func resetPaths() {
        let alert = NSAlert()
        alert.messageText = "Reset Paths to Defaults"
        alert.informativeText = "Are you sure you want to reset all paths to their default values?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            settings.xcodeProjectsPath = "~/Desktop/xcode"
            settings.workspacePath = "~"
            settings.modelsPath = AppSettings.detectWritableModelsPath() // Use smart default
            settings.templatesPath = "~/Documents"
            settings.conversationsExportPath = "~/Documents"
        }
    }

    /// Checks all path permissions and shows alert if errors found
    private func checkAllPermissions() {
        permissionErrors = settings.validateAllPathPermissions()
        if !permissionErrors.isEmpty {
            showingPermissionAlert = true
        }
    }

    /// Formats permission errors for display in alert
    private func formatPermissionErrors() -> String {
        var message = "The following directories lack write permissions:\n\n"
        for (label, error) in permissionErrors.sorted(by: { $0.key < $1.key }) {
            message += "• \(label): \(error)\n"
        }
        message += "\nPlease choose different directories or fix permissions."
        return message
    }

    /// Shows permission fix options for a specific path
    private func showPermissionFixOptions(for label: String, path: String) {
        let alert = NSAlert()
        alert.messageText = "Fix Write Permission Issue"
        alert.informativeText = """
        \(label) does not have write permission: \(path)

        Options:
        1. Open Finder to fix permissions manually
        2. Choose a different directory
        3. Create directory in home folder (recommended)
        """
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Open in Finder")
        alert.addButton(withTitle: "Choose Different Directory")
        alert.addButton(withTitle: "Create in Home Folder")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Open in Finder
            openInFinderAndShowInstructions(path: path)

        case .alertSecondButtonReturn:
            // Choose different directory - trigger appropriate picker
            triggerDirectoryPicker(for: label)

        case .alertThirdButtonReturn:
            // Create in home folder
            createInHomeFolder(for: label)

        default:
            break
        }
    }

    /// Opens directory in Finder and shows permission fix instructions
    private func openInFinderAndShowInstructions(path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Open parent directory if path doesn't exist
        let directoryToOpen: URL
        if FileManager.default.fileExists(atPath: expandedPath) {
            directoryToOpen = url
        } else {
            directoryToOpen = url.deletingLastPathComponent()
        }

        NSWorkspace.shared.open(directoryToOpen)

        // Show instructions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let instructionsAlert = NSAlert()
            instructionsAlert.messageText = "Fix Permissions"
            instructionsAlert.informativeText = """
            To fix write permissions:

            1. Right-click the folder in Finder
            2. Select "Get Info"
            3. At the bottom, click the lock icon and authenticate
            4. Under "Sharing & Permissions", ensure your user has "Read & Write"
            5. Click the gear icon → "Apply to enclosed items" if needed
            6. Close the Info window and return to MLX Code
            """
            instructionsAlert.alertStyle = .informational
            instructionsAlert.addButton(withTitle: "OK")
            instructionsAlert.runModal()
        }
    }

    /// Triggers the appropriate directory picker based on label
    private func triggerDirectoryPicker(for label: String) {
        switch label {
        case "Models":
            showingModelsPicker = true
        case "Templates":
            showingTemplatesPicker = true
        case "Conversations":
            showingConversationsPicker = true
        default:
            break
        }
    }

    /// Creates directory in home folder with write permissions
    private func createInHomeFolder(for label: String) {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let suggestedPath: String

        switch label {
        case "Models":
            suggestedPath = homeDirectory.appendingPathComponent("MLXCode/Models").path
        case "Templates":
            suggestedPath = homeDirectory.appendingPathComponent("MLXCode/Templates").path
        case "Conversations":
            suggestedPath = homeDirectory.appendingPathComponent("MLXCode/Conversations").path
        default:
            return
        }

        do {
            // Create directory
            try FileManager.default.createDirectory(
                atPath: suggestedPath,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Convert to tilde path
            let tilePath = suggestedPath.replacingOccurrences(
                of: homeDirectory.path,
                with: "~"
            )

            // Update setting
            switch label {
            case "Models":
                settings.modelsPath = tilePath
            case "Templates":
                settings.templatesPath = tilePath
            case "Conversations":
                settings.conversationsExportPath = tilePath
            default:
                break
            }

            // Show success
            let successAlert = NSAlert()
            successAlert.messageText = "Directory Created"
            successAlert.informativeText = "Successfully created directory at:\n\(tilePath)"
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "OK")
            successAlert.runModal()

            // Recheck permissions
            checkAllPermissions()

        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Failed to Create Directory"
            errorAlert.informativeText = "Error: \(error.localizedDescription)"
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }
}

// MARK: - Preview

struct PathsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PathsSettingsView()
            .frame(width: 600, height: 500)
    }
}
