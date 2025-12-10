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
    case prerequisites = "prerequisites"
    case features = "features"
    case keyboardShortcuts = "shortcuts"
    case troubleshooting = "troubleshooting"
    case about = "about"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted:
            return "Getting Started"
        case .prerequisites:
            return "Prerequisites & Setup"
        case .features:
            return "Features & Capabilities"
        case .keyboardShortcuts:
            return "Keyboard Shortcuts"
        case .troubleshooting:
            return "Troubleshooting"
        case .about:
            return "About & GitHub"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted:
            return "star.fill"
        case .prerequisites:
            return "checklist"
        case .features:
            return "sparkles"
        case .keyboardShortcuts:
            return "keyboard"
        case .troubleshooting:
            return "wrench.and.screwdriver"
        case .about:
            return "info.circle.fill"
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
        case .prerequisites:
            return "Prerequisites"
        case .features:
            return "Features"
        case .keyboardShortcuts:
            return "KeyboardShortcuts"
        case .troubleshooting:
            return "Troubleshooting"
        case .about:
            return "About"
        }
    }

    private var fallbackContent: String {
        switch self {
        case .gettingStarted:
            return """
            # Getting Started with MLX Code

            ## ⚠️ Important: Manual Setup Required

            MLX Code requires manual setup before first use. This is not a plug-and-play application.

            **Estimated Setup Time:** 30-120 minutes (depending on your experience)

            ## Quick Start

            1. **Install Prerequisites** (See Prerequisites & Setup tab)
               - Apple Silicon Mac required
               - Command Line Tools
               - Python 3.9+
               - MLX framework

            2. **Install MLX**: Open Terminal and run:
               ```bash
               pip3 install mlx mlx-lm huggingface-hub transformers
               ```

            3. **Download a Model** (3-14 GB):
               ```bash
               mkdir -p ~/.mlx/models
               cd ~/.mlx/models
               huggingface-cli download microsoft/Phi-3.5-mini-instruct --local-dir phi-3.5-mini
               ```

            4. **Configure Model Path**: Settings → Paths → Models → Choose your models directory

            5. **Load the Model**: Settings → Models → Scan Disk → Select model → Load

            6. **Start Chatting**: Type your message and press Enter!

            ## Need Help?

            Check the **Prerequisites & Setup** tab for detailed instructions.
            """

        case .prerequisites:
            return """
            # Prerequisites & Setup

            ## ⚠️ Important Notice

            **MLX Code requires manual setup.** This is an advanced developer tool that requires:
            - Command-line experience
            - Understanding of Python environments
            - Large model downloads (3-50 GB)
            - Apple Silicon Mac (M1/M2/M3/M4)

            ## System Requirements

            ### Hardware (Required)
            - ✅ Apple Silicon Mac (M1, M2, M3, M4 or newer)
            - ✅ 8 GB RAM minimum (16 GB recommended)
            - ✅ 10-50 GB free storage
            - ❌ Intel Macs NOT supported

            ### Software (Required)
            1. **macOS 14.0+** (Sonoma or newer)
            2. **Command Line Tools**
               ```bash
               xcode-select --install
               ```
            3. **Python 3.9+** (included with macOS 14+)
            4. **MLX Framework**
               ```bash
               pip3 install mlx>=0.0.10 mlx-lm>=0.0.10
               pip3 install huggingface-hub transformers sentencepiece
               ```

            ## Setup Steps

            ### Step 1: Install Python Dependencies
            ```bash
            pip3 install mlx mlx-lm huggingface-hub transformers \\
                sentencepiece protobuf tokenizers sentence-transformers \\
                chromadb numpy tqdm
            ```

            ### Step 2: Download a Model
            Choose one:

            **Phi-3.5 Mini (Recommended)** - 3.8 GB, fastest
            ```bash
            mkdir -p ~/.mlx/models
            cd ~/.mlx/models
            huggingface-cli download microsoft/Phi-3.5-mini-instruct \\
                --local-dir phi-3.5-mini
            ```

            **Llama 3.2 3B** - 7 GB, better quality
            ```bash
            huggingface-cli download meta-llama/Llama-3.2-3B-Instruct \\
                --local-dir llama-3.2-3b
            ```

            ### Step 3: Configure MLX Code
            1. Launch MLX Code
            2. Settings → Paths → Models → Point to your models directory
            3. Settings → Models → Scan Disk
            4. Select your model → Load

            ### Step 4: Grant Permissions
            When prompted:
            - Allow Files and Folders access
            - Allow Automation access

            ## Troubleshooting

            ### "MLX module not found"
            ```bash
            pip3 install --upgrade mlx mlx-lm
            python3 -c "import mlx; print(mlx.__version__)"
            ```

            ### "Model not loading"
            - Verify model is in correct directory
            - Check Settings → Paths → Models
            - Try smaller model (Phi-3.5 Mini)
            - Ensure enough RAM

            ### "Permission denied"
            ```bash
            # Remove quarantine
            xattr -cr "/Applications/MLX Code.app"
            ```

            ## For Detailed Instructions

            Click the app menu: **MLX Code → Prerequisites** for comprehensive setup guide.
            """

        case .features:
            return """
            # Features

            - Real-time AI chat
            - Multiple models
            - Code highlighting
            - Conversation history
            - Keyboard shortcuts
            - Custom models directory
            - Tool integration (Bash, Git, Xcode)

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

            ### "Python not found"
            ```bash
            # Check Python
            python3 --version

            # Install via Homebrew if needed
            brew install python@3.11
            ```

            ## Still Need Help?
            Check the Prerequisites & Setup guide or visit our GitHub repository.
            """

        case .about:
            return """
            # About MLX Code

            **Version:** 1.0
            **Build:** 2025-12-10
            **Author:** Jordan Koch
            **Co-Author:** Claude Code

            ## What is MLX Code?

            MLX Code is a native macOS application for running local Large Language Models (LLMs) using Apple's MLX framework. It provides a ChatGPT-like interface with advanced developer tools integration.

            ## Key Features
            - 🚀 Native Apple Silicon performance
            - 💬 Real-time streaming chat
            - 🛠️ Developer tools (Bash, Git, Xcode)
            - 📁 Custom models directory support
            - 🎨 Syntax highlighting
            - ⌨️ Keyboard shortcuts
            - 📊 Token metrics

            ## Open Source

            MLX Code is open source software released under the MIT License.

            ### GitHub Repository
            **https://github.com/kochj23/MLXCode**

            Visit our GitHub for:
            - 📖 Full documentation
            - 🐛 Bug reports
            - 💡 Feature requests
            - 🤝 Contributing guidelines
            - ⭐️ Star the project

            ## Technology Stack
            - **Language:** Swift 5.0
            - **Framework:** SwiftUI
            - **AI Framework:** MLX (Apple)
            - **Platform:** macOS 14.0+
            - **Architecture:** Apple Silicon only

            ## System Requirements
            - Apple Silicon Mac (M1/M2/M3/M4)
            - macOS 14.0+ (Sonoma)
            - 8 GB RAM minimum
            - 10-50 GB storage for models

            ## License

            MIT License

            Copyright © 2025 Jordan Koch

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.

            ## Support

            For help and support:
            - Check the Prerequisites & Setup guide
            - Visit GitHub Issues: https://github.com/kochj23/MLXCode/issues
            - Read the documentation

            ## Acknowledgments

            Built with Claude Code (claude.com/claude-code)
            Powered by Apple's MLX Framework
            Inspired by the open-source AI community

            ---

            **🔗 Visit us on GitHub: https://github.com/kochj23/MLXCode**
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
