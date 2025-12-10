//
//  PrerequisitesView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct PrerequisitesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: PrerequisiteSection = .hardware
    @ObservedObject private var settings = AppSettings.shared

    enum PrerequisiteSection: String, CaseIterable {
        case hardware = "Hardware"
        case software = "Software"
        case python = "Python & MLX"
        case models = "Models"
        case permissions = "Permissions"
        case troubleshooting = "Troubleshooting"
        case quickStart = "Quick Start"

        var icon: String {
            switch self {
            case .hardware: return "cpu"
            case .software: return "gearshape.2"
            case .python: return "terminal"
            case .models: return "brain"
            case .permissions: return "lock.shield"
            case .troubleshooting: return "wrench.and.screwdriver"
            case .quickStart: return "bolt.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(PrerequisiteSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Prerequisites")
            .frame(minWidth: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contentForSection(selectedSection)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    @ViewBuilder
    private func contentForSection(_ section: PrerequisiteSection) -> some View {
        switch section {
        case .hardware:
            hardwareContent
        case .software:
            softwareContent
        case .python:
            pythonContent
        case .models:
            modelsContent
        case .permissions:
            permissionsContent
        case .troubleshooting:
            troubleshootingContent
        case .quickStart:
            quickStartContent
        }
    }

    // MARK: - Hardware Section

    private var hardwareContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hardware Requirements")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            GroupBox("✅ Required") {
                VStack(alignment: .leading, spacing: 8) {
                    requirementRow(icon: "checkmark.circle.fill", color: .green,
                                   title: "Apple Silicon Mac",
                                   detail: "M1, M1 Pro, M1 Max, M1 Ultra, M2, M2 Pro, M2 Max, M2 Ultra, M3, M3 Pro, M3 Max, M4, or newer")
                    requirementRow(icon: "checkmark.circle.fill", color: .green,
                                   title: "Minimum 8 GB RAM",
                                   detail: "16 GB recommended for larger models")
                    requirementRow(icon: "checkmark.circle.fill", color: .green,
                                   title: "10-50 GB Storage",
                                   detail: "10 GB minimum, 50+ GB recommended for multiple models")
                }
                .padding()
            }

            GroupBox("❌ Not Supported") {
                VStack(alignment: .leading, spacing: 8) {
                    requirementRow(icon: "xmark.circle.fill", color: .red,
                                   title: "Intel Macs",
                                   detail: "MLX framework requires Apple Silicon")
                    requirementRow(icon: "xmark.circle.fill", color: .red,
                                   title: "Non-Mac Hardware",
                                   detail: "macOS required")
                }
                .padding()
            }

            checkSystemButton
        }
    }

    // MARK: - Software Section

    private var softwareContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Software Requirements")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            softwareItem(
                title: "1. macOS 14.0+ (Sonoma)",
                required: true,
                description: "MLX Code requires macOS 14.0 or newer",
                checkCommand: "sw_vers",
                installInstructions: "System Settings → General → Software Update"
            )

            softwareItem(
                title: "2. Command Line Tools",
                required: true,
                description: "Includes Git and essential development tools",
                checkCommand: "xcode-select -p",
                installInstructions: "Run: xcode-select --install"
            )

            softwareItem(
                title: "3. Xcode 15+",
                required: false,
                description: "Only needed if building from source",
                checkCommand: "xcodebuild -version",
                installInstructions: "Download from Mac App Store or developer.apple.com"
            )

            softwareItem(
                title: "4. Homebrew",
                required: false,
                description: "Recommended package manager for macOS",
                checkCommand: "brew --version",
                installInstructions: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            )

            softwareItem(
                title: "5. GitHub CLI",
                required: false,
                description: "For CI/CD tool features and PR creation",
                checkCommand: "gh --version",
                installInstructions: "brew install gh"
            )
        }
    }

    // MARK: - Python Section

    private var pythonContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Python & MLX Setup")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            GroupBox("Python 3.9+") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Check if Python is installed:")
                        .font(.headline)

                    codeBlock("python3 --version")

                    Text("macOS 14+ includes Python 3.9+ by default")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            GroupBox("MLX Framework (Required)") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Install MLX and dependencies:")
                        .font(.headline)

                    codeBlock("""
                    pip3 install mlx>=0.0.10
                    pip3 install mlx-lm>=0.0.10
                    pip3 install huggingface-hub>=0.19.0
                    pip3 install transformers>=4.35.0
                    pip3 install sentencepiece>=0.1.99
                    pip3 install protobuf>=3.20.0
                    pip3 install tokenizers>=0.15.0
                    pip3 install sentence-transformers>=2.2.0
                    pip3 install chromadb>=0.4.0
                    pip3 install numpy>=1.24.0
                    pip3 install tqdm>=4.65.0
                    """)

                    Text("Or install from requirements.txt:")
                        .font(.headline)
                        .padding(.top, 8)

                    codeBlock("""
                    cd "/path/to/MLX Code/Python"
                    pip3 install -r requirements.txt
                    """)
                }
                .padding()
            }

            GroupBox("Verify Installation") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test MLX installation:")
                        .font(.headline)

                    codeBlock("python3 -c \"import mlx.core as mx; print(f'MLX version: {mx.__version__}')\"")
                }
                .padding()
            }
        }
    }

    // MARK: - Models Section

    private var modelsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Download LLM Models")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            Text("MLX Code requires at least one LLM model. The app will automatically detect a writable location for models (typically ~/Documents/MLXCode/models or ~/.mlx/models)")
                .font(.body)
                .padding(.bottom, 8)

            modelOption(
                name: "Phi-3.5 Mini",
                size: "3.8 GB",
                speed: "⚡️ Fastest",
                quality: "⭐️⭐️⭐️",
                recommended: true,
                downloadCommand: """
                mkdir -p \(settings.modelsPath)/
                cd \(settings.modelsPath)/
                huggingface-cli download microsoft/Phi-3.5-mini-instruct --local-dir phi-3.5-mini
                """
            )

            modelOption(
                name: "Llama 3.2 3B",
                size: "7 GB",
                speed: "⚡️⚡️ Fast",
                quality: "⭐️⭐️⭐️⭐️",
                recommended: false,
                downloadCommand: """
                mkdir -p \(settings.modelsPath)/
                cd \(settings.modelsPath)/
                huggingface-cli download meta-llama/Llama-3.2-3B-Instruct --local-dir llama-3.2-3b
                """
            )

            modelOption(
                name: "Mistral 7B",
                size: "14 GB",
                speed: "⚡️⚡️⚡️ Moderate",
                quality: "⭐️⭐️⭐️⭐️⭐️",
                recommended: false,
                downloadCommand: """
                mkdir -p \(settings.modelsPath)/
                cd \(settings.modelsPath)/
                huggingface-cli download mistralai/Mistral-7B-Instruct-v0.2 --local-dir mistral-7b
                """
            )

            Text("💡 You can download multiple models and switch between them in MLX Code")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Permissions Section

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions & Security")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            GroupBox("Required Permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    permissionRow(icon: "folder", title: "Files and Folders",
                                  description: "To read and write your code files")
                    permissionRow(icon: "terminal", title: "Terminal/Automation",
                                  description: "To execute bash commands and tools")
                }
                .padding()
            }

            GroupBox("Grant Permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Launch MLX Code")
                    Text("2. When prompted, click 'Allow' for each permission")
                    Text("3. Or manually: System Settings → Privacy & Security → Files and Folders / Automation")
                }
                .padding()
            }

            GroupBox("Security Exception") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If you see 'App can't be opened because it's from an unidentified developer':")
                        .font(.headline)

                    Text("Option 1: Right-click MLX Code.app → Open → Open")
                        .font(.caption)

                    Text("Option 2: Run command:")
                        .font(.caption)
                        .padding(.top, 4)

                    codeBlock("xattr -d com.apple.quarantine \"/Applications/MLX Code.app\"")
                }
                .padding()
            }
        }
    }

    // MARK: - Troubleshooting Section

    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Troubleshooting")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            troubleshootingItem(
                problem: "Python not found",
                solution: """
                # Install Python via Homebrew
                brew install python@3.11

                # Or check macOS built-in Python
                which python3
                """
            )

            troubleshootingItem(
                problem: "MLX module not found",
                solution: """
                # Reinstall MLX
                pip3 install --upgrade mlx mlx-lm
                """
            )

            troubleshootingItem(
                problem: "Model not loading",
                solution: """
                • Ensure model is in your configured models directory (check Settings → Paths)
                • Check model is MLX-compatible (not PyTorch/GGUF only)
                • Verify you have enough RAM for the model size
                • Try a smaller model like Phi-3.5 Mini
                """
            )

            troubleshootingItem(
                problem: "Permission denied",
                solution: """
                # Reset app permissions
                tccutil reset All com.mlxcode.app

                # Then relaunch and grant permissions
                """
            )

            troubleshootingItem(
                problem: "App damaged and can't be opened",
                solution: """
                # Remove quarantine attribute
                xattr -cr "/Applications/MLX Code.app"
                """
            )
        }
    }

    // MARK: - Quick Start Section

    private var quickStartContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start Guide")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            GroupBox("Complete Setup Script") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Run these commands in Terminal:")
                        .font(.headline)

                    codeBlock("""
                    # 1. Install Homebrew
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

                    # 2. Install Command Line Tools
                    xcode-select --install

                    # 3. Install Python dependencies
                    pip3 install mlx mlx-lm huggingface-hub transformers sentence-transformers chromadb numpy tqdm

                    # 4. Download Phi-3.5 Mini model (3.8 GB)
                    mkdir -p \(settings.modelsPath)/
                    cd \(settings.modelsPath)/
                    huggingface-cli download microsoft/Phi-3.5-mini-instruct --local-dir phi-3.5-mini

                    # 5. Copy app to Applications
                    cp -r "MLX Code.app" /Applications/

                    # 6. Launch
                    open "/Applications/MLX Code.app"
                    """)
                }
                .padding()
            }

            GroupBox("Setup Time Estimates") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Minimum setup:")
                        Spacer()
                        Text("~30 minutes")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Recommended setup:")
                        Spacer()
                        Text("~1-2 hours")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            GroupBox("After Installation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Launch MLX Code")
                    Text("2. Click 'Models' in the sidebar")
                    Text("3. Browse to \(settings.modelsPath)/phi-3.5-mini")
                    Text("4. Click 'Load Model'")
                    Text("5. Start chatting!")
                    Text("")
                    Text("Try: 'List all tools' to see what's available")
                        .italic()
                }
                .padding()
            }
        }
    }

    // MARK: - Helper Views

    private func requirementRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func softwareItem(title: String, required: Bool, description: String, checkCommand: String, installInstructions: String) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(required ? "Required" : "Optional")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(required ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    Spacer()
                }

                Text(description)
                    .font(.body)

                Text("Check:")
                    .font(.headline)
                codeBlock(checkCommand)

                Text("Install:")
                    .font(.headline)
                    .padding(.top, 4)
                Text(installInstructions)
                    .font(.caption)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding()
        }
    }

    private func modelOption(name: String, size: String, speed: String, quality: String, recommended: Bool, downloadCommand: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                    if recommended {
                        Text("RECOMMENDED")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    Spacer()
                    Text(size)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Speed:")
                            .font(.caption)
                        Text(speed)
                    }
                    VStack(alignment: .leading) {
                        Text("Quality:")
                            .font(.caption)
                        Text(quality)
                    }
                }

                Text("Download:")
                    .font(.headline)
                    .padding(.top, 8)
                codeBlock(downloadCommand)
            }
            .padding()
        }
    }

    private func permissionRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func troubleshootingItem(problem: String, solution: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(problem)
                        .font(.headline)
                }

                Text("Solution:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(solution)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding()
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
    }

    private var checkSystemButton: some View {
        Button(action: {
            checkSystemRequirements()
        }) {
            HStack {
                Image(systemName: "checkmark.shield")
                Text("Check System Requirements")
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }

    private func checkSystemRequirements() {
        // This would check actual system requirements
        // For now, just a placeholder
        print("Checking system requirements...")
    }
}

#Preview {
    PrerequisitesView()
}
