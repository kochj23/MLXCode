//
//  HelpView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Help documentation viewer
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: HelpTopic = .gettingStarted
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            // Sidebar with topics
            List(HelpTopic.allCases, selection: $selectedTopic) { topic in
                Label(topic.title, systemImage: topic.icon)
                    .tag(topic)
            }
            .navigationTitle("Help")
            .frame(minWidth: 200)
        } detail: {
            // Content area
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(selectedTopic.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Content
                ScrollView {
                    MarkdownTextView(
                        markdown: selectedTopic.content,
                        fontSize: 14,
                        enableSyntaxHighlighting: true
                    )
                    .padding()
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, minHeight: 600, idealHeight: 800)
    }
}

/// Help topics enumeration
enum HelpTopic: String, CaseIterable, Identifiable {
    case gettingStarted = "getting_started"
    case features = "features"
    case keyboardShortcuts = "shortcuts"
    case troubleshooting = "troubleshooting"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted:
            return "Getting Started"
        case .features:
            return "Features & Capabilities"
        case .keyboardShortcuts:
            return "Keyboard Shortcuts"
        case .troubleshooting:
            return "Troubleshooting"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted:
            return "star.fill"
        case .features:
            return "sparkles"
        case .keyboardShortcuts:
            return "keyboard"
        case .troubleshooting:
            return "wrench.and.screwdriver"
        }
    }

    var content: String {
        // Try to load from bundle first
        if let path = Bundle.main.path(forResource: filename, ofType: "md"),
           let content = try? String(contentsOfFile: path) {
            return content
        }

        // Fallback to hardcoded content
        return fallbackContent
    }

    private var filename: String {
        switch self {
        case .gettingStarted:
            return "GettingStarted"
        case .features:
            return "Features"
        case .keyboardShortcuts:
            return "KeyboardShortcuts"
        case .troubleshooting:
            return "Troubleshooting"
        }
    }

    private var fallbackContent: String {
        switch self {
        case .gettingStarted:
            return """
            # Getting Started with MLX Code

            ## Quick Start

            1. **Install MLX**: Open Terminal and run:
               ```bash
               pip3 install mlx mlx-lm
               ```

            2. **Download a Model**: Click Settings → Models → Download

            3. **Load the Model**: Click the "Load" button

            4. **Start Chatting**: Type your message and press Enter!

            ## Need Help?

            Check the Features guide for more details.
            """

        case .features:
            return """
            # Features

            - Real-time AI chat
            - Multiple models
            - Code highlighting
            - Conversation history
            - Keyboard shortcuts

            See the full documentation for details.
            """

        case .keyboardShortcuts:
            return """
            # Keyboard Shortcuts

            ## Essential
            - `⌘N` - New conversation
            - `⌘K` - Clear conversation
            - `⌘R` - Regenerate response
            - `⌘,` - Open Settings

            ## Chat
            - `⌘↩` - Send message
            - `Esc` - Stop generation

            See the full shortcuts guide for more.
            """

        case .troubleshooting:
            return """
            # Troubleshooting

            ## Common Issues

            ### "No model loaded"
            1. Open Settings
            2. Go to Models tab
            3. Click Download
            4. Click Load

            ### "MLX not installed"
            Run in Terminal:
            ```bash
            pip3 install mlx mlx-lm
            ```

            ## Still Need Help?
            Check the full troubleshooting guide.
            """
        }
    }
}

// MARK: - Preview

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
