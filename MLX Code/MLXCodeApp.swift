//
//  MLXCodeApp.swift
//  MLX Code
//
//  Created by MLX Code Generator on 2025-11-18.
//  Copyright © 2025 Local. All rights reserved.
//

import SwiftUI

/// Main application entry point for MLX Code
///
/// MLX Code is a local LLM-powered coding assistant that bridges Apple's MLX
/// toolkit with Xcode to provide intelligent code assistance without cloud dependencies.
///
/// ## Architecture
/// - **MLX Integration**: Uses Python subprocess with mlx-lm for model inference
/// - **Xcode Control**: Hybrid approach using xcodebuild CLI + direct project file parsing
/// - **Security**: Sandboxed execution, input validation, secure storage
///
/// ## Security Considerations
/// - All user input is validated before processing
/// - File operations are restricted to user-approved directories
/// - Model outputs are sanitized to prevent code injection
/// - Credentials stored securely in macOS Keychain
@main
struct MLXCodeApp: App {
    /// Application-wide settings manager
    @StateObject private var settings = AppSettings.shared

    /// Chat view model for managing conversations
    @StateObject private var chatViewModel = ChatViewModel()

    /// Show prerequisites window
    @State private var showingPrerequisites = false

    /// Show help window
    @State private var showingHelp = false

    /// Discovers models on disk and updates the model list with correct paths
    @MainActor
    private func discoverAndRefreshModels() async {
        print("🔍 Discovering models on startup...")

        do {
            // Scan filesystem for actual models
            let discovered = try await MLXService.shared.discoverModels()
            print("✅ Found \(discovered.count) models on disk")

            if !discovered.isEmpty {
                // Update settings with discovered models (these have CORRECT paths from disk)
                settings.availableModels = discovered

                // Auto-select first model if none selected
                if settings.selectedModel == nil {
                    settings.selectedModel = discovered.first
                    print("✅ Auto-selected: \(discovered.first?.name ?? "none")")
                }

                settings.saveSettings()
                print("✅ Model list refreshed with actual paths")
            }
        } catch {
            print("⚠️ Model discovery failed: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ChatView()
                .environmentObject(settings)
                .environmentObject(chatViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Discover actual models on disk at startup
                    Task {
                        await discoverAndRefreshModels()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    chatViewModel.newConversation()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    // Toggle sidebar visibility
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            CommandGroup(replacing: .help) {
                Button("MLX Code Help") {
                    showingHelp = true
                }
                .keyboardShortcut("?", modifiers: [.command])

                Button("Prerequisites & Setup Guide") {
                    showingPrerequisites = true
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])

                Divider()

                Link("GitHub Repository", destination: URL(string: "https://github.com/kochj23/MLXCode")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/kochj23/MLXCode/issues")!)
                Link("View Documentation", destination: URL(string: "https://github.com/kochj23/MLXCode/blob/main/README.md")!)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
        }

        // Prerequisites Window
        Window("Prerequisites Guide", id: "prerequisites") {
            PrerequisitesView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .keyboardShortcut("?", modifiers: [.command, .shift])

        // Help Window
        Window("MLX Code Help", id: "help") {
            HelpView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .keyboardShortcut("?", modifiers: [.command])
    }
}
