//
//  MLXPythonSettingsView.swift
//  MLX Code
//
//  Python MLX toolkit configuration UI with status indicator
//  Created on 2025-12-06
//

import SwiftUI

/// Python MLX toolkit settings view
struct MLXPythonSettingsView: View {
    @StateObject private var settings = MLXPythonSettings.shared
    @State private var showingFilePicker = false
    @State private var showingAutoDetectAlert = false
    @State private var autoDetectSuccess = false
    @State private var showingInstallAlert = false
    @State private var installOutput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Python MLX Toolkit Configuration")
                .font(.headline)
                .padding(.bottom, 5)

            // Python path section
            VStack(alignment: .leading, spacing: 8) {
                Text("Python Executable Path")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Python path", text: $settings.pythonPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse...") {
                        browsePythonPath()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Status section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Status indicator light
                    Circle()
                        .fill(settings.status.color)
                        .frame(width: 16, height: 16)
                        .shadow(color: settings.status.color.opacity(0.5), radius: 4)
                        .overlay(
                            Circle()
                                .stroke(settings.status.color.opacity(0.3), lineWidth: 2)
                                .scaleEffect(settings.isChecking ? 1.5 : 1.0)
                                .opacity(settings.isChecking ? 0 : 1)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                                          value: settings.isChecking)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status: \(settings.status.rawValue)")
                            .font(.body)

                        Text(settings.status.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if settings.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                // Version information
                if let pythonVer = settings.pythonVersion {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.secondary)
                        Text("Python: \(pythonVer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let mlxVer = settings.mlxVersion {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.secondary)
                        Text("MLX: \(mlxVer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let lastCheck = settings.lastCheckTime {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("Last checked: \(formatDate(lastCheck))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await settings.checkMLXAvailability()
                    }
                }) {
                    Label("Check Now", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.isChecking)

                Button(action: {
                    Task {
                        let success = await settings.autoDetect()
                        autoDetectSuccess = success
                        showingAutoDetectAlert = true
                    }
                }) {
                    Label("Auto-Detect", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(settings.isChecking)

                Button(action: {
                    Task {
                        let result = await settings.installMLXToolkit()
                        installOutput = result.output
                        showingInstallAlert = true
                    }
                }) {
                    Label("Install MLX", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .disabled(settings.status == .pythonNotFound || settings.isChecking)
            }

            // Auto-check option
            Toggle("Check MLX status on app launch", isOn: $settings.autoCheckOnLaunch)
                .font(.subheadline)

            Divider()

            // Help text
            Text("Python MLX toolkit enables advanced AI features. If not installed, the app will use CoreML only. MLX provides additional flexibility for custom models and Python-based AI processing.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 600)
        .alert("Auto-Detection Result", isPresented: $showingAutoDetectAlert) {
            Button("OK") { }
        } message: {
            if autoDetectSuccess {
                Text("Found working Python with MLX at:\n\(settings.pythonPath)\n\nMLX Version: \(settings.mlxVersion ?? "Unknown")")
            } else {
                Text("Could not find Python with MLX installed.\n\nPlease install MLX or manually specify Python path.")
            }
        }
        .alert("MLX Installation", isPresented: $showingInstallAlert) {
            Button("OK") { }
        } message: {
            Text(installOutput.isEmpty ? "Check console for details" : installOutput)
        }
    }

    private func browsePythonPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Python Executable"
        panel.message = "Choose the Python 3 executable"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin/")

        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.pythonPath = url.path
                Task {
                    await settings.checkMLXAvailability()
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Preview provider
struct MLXPythonSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MLXPythonSettingsView()
            .frame(width: 600, height: 400)
    }
}
