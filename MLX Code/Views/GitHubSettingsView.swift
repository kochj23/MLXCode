//
//  GitHubSettingsView.swift
//  MLX Code
//
//  GitHub configuration UI
//  Created on 2025-12-09
//

import SwiftUI

/// GitHub settings configuration view
struct GitHubSettingsView: View {
    @ObservedObject private var settings = GitHubSettings.shared

    @State private var tokenInput: String = ""
    @State private var showingTokenInput: Bool = false
    @State private var testingConnection: Bool = false
    @State private var connectionStatus: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Account Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("GitHub Account")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Username
                    HStack {
                        Text("Username:")
                            .frame(width: 120, alignment: .leading)

                        TextField("github-username", text: $settings.username)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)

                        if !settings.username.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    // Personal Access Token
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Token:")
                                .frame(width: 120, alignment: .leading)

                            if settings.hasToken {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.green)
                                    Text("Token stored securely in Keychain")
                                        .foregroundColor(.secondary)
                                        .font(.caption)

                                    Button("Update") {
                                        showingTokenInput = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Remove") {
                                        try? settings.deleteToken()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.red)
                                }
                            } else {
                                Button("Add Token") {
                                    showingTokenInput = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if showingTokenInput {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    SecureField("ghp_xxxxxxxxxxxx", text: $tokenInput)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 400)

                                    Button("Save") {
                                        do {
                                            try settings.saveToken(tokenInput)
                                            tokenInput = ""
                                            showingTokenInput = false
                                        } catch {
                                            print("Error saving token: \(error)")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(tokenInput.isEmpty)

                                    Button("Cancel") {
                                        tokenInput = ""
                                        showingTokenInput = false
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Text("Create token at: github.com/settings/tokens")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Required scopes: repo, user")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }

                    // Test Connection
                    HStack {
                        Button(action: testGitHubConnection) {
                            HStack {
                                if testingConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                }
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!settings.hasToken || settings.username.isEmpty || testingConnection)

                        if !connectionStatus.isEmpty {
                            Text(connectionStatus)
                                .font(.caption)
                                .foregroundColor(connectionStatus.contains("✅") ? .green : .red)
                        }
                    }
                }

                Divider()

                // Repository Defaults Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Default Repository")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Used for PR creation and other Git operations")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Owner:")
                            .frame(width: 120, alignment: .leading)

                        TextField("owner-name", text: $settings.defaultOwner)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)

                        Text("/")
                            .foregroundColor(.secondary)

                        TextField("repo-name", text: $settings.defaultRepo)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }

                    HStack {
                        Text("Default Branch:")
                            .frame(width: 120, alignment: .leading)

                        TextField("main", text: $settings.defaultBranch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                    }
                }

                Divider()

                // Automation Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Automation")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Toggle("Auto-push commits", isOn: $settings.autoPushCommits)
                        .help("Automatically push to remote after committing")

                    Toggle("Auto-create pull requests", isOn: $settings.autoCreatePRs)
                        .help("Automatically create PR after pushing to feature branch")
                }

                Divider()

                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About GitHub Integration")
                        .font(.headline)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            featureRow("Generate commit messages from diffs")
                            featureRow("Create PR descriptions automatically")
                            featureRow("AI-powered code review")
                            featureRow("Push directly from MLX Code")
                        }
                        .padding(.vertical, 4)
                    }

                    Link("Create GitHub Token →", destination: URL(string: "https://github.com/settings/tokens/new")!)
                        .font(.caption)
                }

                Spacer()

                // Reset button
                HStack {
                    Spacer()
                    Button("Reset All Settings", role: .destructive) {
                        let alert = NSAlert()
                        alert.messageText = "Reset GitHub Settings"
                        alert.informativeText = "This will remove your token and reset all GitHub configuration."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Reset")
                        alert.addButton(withTitle: "Cancel")

                        if alert.runModal() == .alertFirstButtonReturn {
                            settings.resetSettings()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }

    private func testGitHubConnection() {
        testingConnection = true
        connectionStatus = ""

        Task {
            do {
                let result = try await settings.testConnection()
                await MainActor.run {
                    connectionStatus = result.message
                    testingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "❌ Error: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
    }
}

// MARK: - Preview

struct GitHubSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GitHubSettingsView()
            .frame(width: 600, height: 600)
    }
}
