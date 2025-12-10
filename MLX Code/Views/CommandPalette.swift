//
//  CommandPalette.swift
//  MLX Code
//
//  Universal command palette for keyboard-first workflow
//  Created on 2025-12-09
//

import SwiftUI

/// Command palette for quick actions (⌘K)
struct CommandPalette: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    let onExecute: (Command) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit {
                        executeSelected()
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            commandRow(command, index: index)
                                .id(command.id)
                                .onTapGesture {
                                    execute(command)
                                }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .onChange(of: selectedIndex) {
                    if !filteredCommands.isEmpty {
                        let index = min(selectedIndex, filteredCommands.count - 1)
                        proxy.scrollTo(filteredCommands[index].id, anchor: .center)
                    }
                }
            }

            if filteredCommands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No commands found")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    @ViewBuilder
    private func commandRow(_ command: Command, index: Int) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: command.icon)
                .font(.title3)
                .foregroundColor(command.category.color)
                .frame(width: 32)

            // Name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(.body)
                    .fontWeight(.medium)

                if !command.description.isEmpty {
                    Text(command.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Keyboard shortcut if available
            if let shortcut = command.keyboardShortcut {
                Text(shortcut)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            // Category badge
            Text(command.category.rawValue)
                .font(.caption2)
                .textCase(.uppercase)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(command.category.color.opacity(0.2))
                .foregroundColor(command.category.color)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return Command.allCommands
        }

        let query = searchText.lowercased()
        return Command.allCommands.filter { command in
            command.name.lowercased().contains(query) ||
            command.description.lowercased().contains(query) ||
            command.keywords.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private func executeSelected() {
        guard !filteredCommands.isEmpty else { return }
        let command = filteredCommands[selectedIndex]
        execute(command)
    }

    private func execute(_ command: Command) {
        dismiss()
        onExecute(command)
    }
}

// MARK: - Command Definition

/// Command that can be executed from palette
struct Command: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let category: CommandCategory
    let keywords: [String]
    let keyboardShortcut: String?
    let action: CommandAction

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String,
        category: CommandCategory,
        keywords: [String] = [],
        keyboardShortcut: String? = nil,
        action: CommandAction
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.keywords = keywords
        self.keyboardShortcut = keyboardShortcut
        self.action = action
    }

    static var allCommands: [Command] {
        [
            // File Operations
            Command(
                name: "New Conversation",
                description: "Start a fresh conversation",
                icon: "plus.circle",
                category: .file,
                keywords: ["new", "create", "start"],
                keyboardShortcut: "⌘N",
                action: .newConversation
            ),
            Command(
                name: "Save Conversation",
                description: "Save current conversation",
                icon: "square.and.arrow.down",
                category: .file,
                keywords: ["save", "export"],
                keyboardShortcut: "⌘S",
                action: .saveConversation
            ),

            // Model Operations
            Command(
                name: "Load Model",
                description: "Load a different model",
                icon: "cpu",
                category: .model,
                keywords: ["model", "switch", "load"],
                action: .loadModel
            ),
            Command(
                name: "Scan for Models",
                description: "Discover models on disk",
                icon: "arrow.clockwise",
                category: .model,
                keywords: ["scan", "refresh", "discover"],
                action: .scanModels
            ),

            // Code Actions
            Command(
                name: "Explain Code",
                description: "Get explanation of selected code",
                icon: "text.bubble",
                category: .code,
                keywords: ["explain", "describe", "understand"],
                action: .explainCode
            ),
            Command(
                name: "Generate Tests",
                description: "Create unit tests for code",
                icon: "checkmark.square",
                category: .code,
                keywords: ["test", "unittest", "testing"],
                action: .generateTests
            ),
            Command(
                name: "Refactor Code",
                description: "Suggest refactoring improvements",
                icon: "arrow.triangle.2.circlepath",
                category: .code,
                keywords: ["refactor", "improve", "clean"],
                action: .refactorCode
            ),
            Command(
                name: "Find Bugs",
                description: "Analyze code for potential issues",
                icon: "ant",
                category: .code,
                keywords: ["bug", "issue", "problem", "memory"],
                action: .findBugs
            ),
            Command(
                name: "Optimize Code",
                description: "Improve performance",
                icon: "bolt",
                category: .code,
                keywords: ["optimize", "performance", "speed"],
                action: .optimizeCode
            ),
            Command(
                name: "Security Scan",
                description: "Check for vulnerabilities",
                icon: "shield.checkered",
                category: .code,
                keywords: ["security", "vulnerability", "xss", "injection"],
                action: .securityScan
            ),

            // Git Operations
            Command(
                name: "Generate Commit Message",
                description: "AI-generated commit from diff",
                icon: "arrow.up.doc",
                category: .git,
                keywords: ["commit", "git", "message"],
                action: .generateCommit
            ),
            Command(
                name: "Generate PR Description",
                description: "Create pull request description",
                icon: "arrow.triangle.branch",
                category: .git,
                keywords: ["pr", "pull request", "description"],
                action: .generatePR
            ),
            Command(
                name: "Code Review",
                description: "AI review of pending changes",
                icon: "eye",
                category: .git,
                keywords: ["review", "check", "diff"],
                action: .codeReview
            ),

            // Project Operations
            Command(
                name: "Index Project",
                description: "Scan and index codebase",
                icon: "doc.text.magnifyingglass",
                category: .project,
                keywords: ["index", "scan", "search"],
                action: .indexProject
            ),
            Command(
                name: "Search Project",
                description: "Semantic code search",
                icon: "magnifyingglass",
                category: .project,
                keywords: ["search", "find", "lookup"],
                keyboardShortcut: "⌘F",
                action: .searchProject
            ),

            // View Operations
            Command(
                name: "Show Performance Dashboard",
                description: "View model performance metrics",
                icon: "chart.xyaxis.line",
                category: .view,
                keywords: ["performance", "metrics", "stats"],
                keyboardShortcut: "⌘P",
                action: .showPerformance
            ),
            Command(
                name: "Show Log Viewer",
                description: "Open live logs panel",
                icon: "list.bullet.rectangle",
                category: .view,
                keywords: ["logs", "debug", "console"],
                keyboardShortcut: "⌘L",
                action: .showLogs
            ),
            Command(
                name: "Show Settings",
                description: "Open settings panel",
                icon: "gear",
                category: .view,
                keywords: ["settings", "preferences", "config"],
                keyboardShortcut: "⌘,",
                action: .showSettings
            ),

            // Templates
            Command(
                name: "Load Template",
                description: "Start from conversation template",
                icon: "doc.on.doc",
                category: .template,
                keywords: ["template", "snippet", "preset"],
                action: .loadTemplate
            ),
            Command(
                name: "Save as Template",
                description: "Save conversation as reusable template",
                icon: "square.and.arrow.down.on.square",
                category: .template,
                keywords: ["save template", "create template"],
                action: .saveTemplate
            )
        ]
    }
}

/// Command categories
enum CommandCategory: String {
    case file = "File"
    case model = "Model"
    case code = "Code"
    case git = "Git"
    case project = "Project"
    case view = "View"
    case template = "Template"

    var color: Color {
        switch self {
        case .file: return .blue
        case .model: return .purple
        case .code: return .green
        case .git: return .orange
        case .project: return .pink
        case .view: return .cyan
        case .template: return .indigo
        }
    }
}

/// Available command actions
enum CommandAction {
    // File
    case newConversation
    case saveConversation

    // Model
    case loadModel
    case scanModels

    // Code
    case explainCode
    case generateTests
    case refactorCode
    case findBugs
    case optimizeCode
    case securityScan

    // Git
    case generateCommit
    case generatePR
    case codeReview

    // Project
    case indexProject
    case searchProject

    // View
    case showPerformance
    case showLogs
    case showSettings

    // Template
    case loadTemplate
    case saveTemplate
}

// MARK: - Preview

struct CommandPalette_Previews: PreviewProvider {
    static var previews: some View {
        CommandPalette { command in
            print("Executed: \(command.name)")
        }
    }
}
