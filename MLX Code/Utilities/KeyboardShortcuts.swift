//
//  KeyboardShortcuts.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Keyboard shortcut definitions for MLX Code
/// Provides power-user productivity enhancements
///
/// ## Shortcuts Overview
/// - ⌘N: New conversation
/// - ⌘K: Clear conversation
/// - ⌘R: Regenerate last response
/// - ⌘Return: Send message
/// - ⌘⌥C: Copy last response
/// - ⌘⌥V: Paste code from clipboard
/// - ⌘/: Show command palette
/// - ⌘,: Settings
/// - ⌘1-9: Switch to conversation 1-9
/// - ⌘⇧T: Toggle template library
/// - ⌘⇧G: Git commit helper
/// - ⌘⇧B: Build current project
///
/// ## Memory Safety
/// All keyboard shortcut handlers use weak references where needed
struct KeyboardShortcuts {
    /// Command palette shortcuts
    enum Command: String, CaseIterable, Identifiable {
        case newConversation = "New Conversation"
        case clearConversation = "Clear Conversation"
        case regenerate = "Regenerate Response"
        case copyLastResponse = "Copy Last Response"
        case pasteCode = "Paste Code"
        case showTemplates = "Show Templates"
        case gitCommit = "Git Commit Helper"
        case buildProject = "Build Project"
        case showSettings = "Settings"
        case exportConversation = "Export Conversation"
        case importConversation = "Import Conversation"

        var id: String { rawValue }

        var shortcut: KeyEquivalent? {
            switch self {
            case .newConversation: return "n"
            case .clearConversation: return "k"
            case .regenerate: return "r"
            case .showSettings: return ","
            default: return nil
            }
        }

        var modifiers: EventModifiers {
            switch self {
            case .copyLastResponse, .pasteCode:
                return [.command, .option]
            case .showTemplates, .gitCommit, .buildProject:
                return [.command, .shift]
            default:
                return [.command]
            }
        }

        var icon: String {
            switch self {
            case .newConversation: return "plus.message"
            case .clearConversation: return "trash"
            case .regenerate: return "arrow.clockwise"
            case .copyLastResponse: return "doc.on.doc"
            case .pasteCode: return "doc.on.clipboard"
            case .showTemplates: return "text.book.closed"
            case .gitCommit: return "arrow.branch"
            case .buildProject: return "hammer"
            case .showSettings: return "gear"
            case .exportConversation: return "square.and.arrow.up"
            case .importConversation: return "square.and.arrow.down"
            }
        }

        var description: String {
            switch self {
            case .newConversation: return "Start a new conversation"
            case .clearConversation: return "Clear the current conversation"
            case .regenerate: return "Regenerate the last AI response"
            case .copyLastResponse: return "Copy the last response to clipboard"
            case .pasteCode: return "Paste code from clipboard into chat"
            case .showTemplates: return "Open the template library"
            case .gitCommit: return "Generate Git commit message"
            case .buildProject: return "Build the current Xcode project"
            case .showSettings: return "Open settings panel"
            case .exportConversation: return "Export conversation to JSON"
            case .importConversation: return "Import conversation from JSON"
            }
        }
    }
}

/// View for displaying command palette
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    let onSelectCommand: (KeyboardShortcuts.Command) -> Void

    var filteredCommands: [KeyboardShortcuts.Command] {
        if searchText.isEmpty {
            return KeyboardShortcuts.Command.allCases
        } else {
            return KeyboardShortcuts.Command.allCases.filter {
                $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            // Command list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredCommands) { command in
                        CommandRow(command: command)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectCommand(command)
                                isPresented = false
                            }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

/// Row displaying a single command
struct CommandRow: View {
    let command: KeyboardShortcuts.Command

    var body: some View {
        HStack {
            Image(systemName: command.icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.rawValue)
                    .font(.body)

                Text(command.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let shortcut = command.shortcut {
                KeyboardShortcutBadge(
                    key: shortcut,
                    modifiers: command.modifiers
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

/// Badge showing keyboard shortcut
struct KeyboardShortcutBadge: View {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    var modifierSymbols: [String] {
        var symbols: [String] = []
        if modifiers.contains(.command) { symbols.append("⌘") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.control) { symbols.append("⌃") }
        return symbols
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(modifierSymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            Text(key.character.uppercased())
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Keyboard Shortcut Handler

/// Centralized keyboard shortcut handler
@MainActor
class KeyboardShortcutHandler: ObservableObject {
    weak var chatViewModel: ChatViewModel?

    /// Executes a keyboard command
    /// - Parameter command: The command to execute
    func executeCommand(_ command: KeyboardShortcuts.Command) {
        guard let viewModel = chatViewModel else {
            logWarning("ChatViewModel not available for command execution", category: "KeyboardShortcuts")
            return
        }

        Task { [weak viewModel] in
            guard let viewModel = viewModel else { return }

            switch command {
            case .newConversation:
                viewModel.newConversation()

            case .clearConversation:
                await viewModel.clearCurrentConversation()

            case .regenerate:
                await viewModel.regenerateLastResponse()

            case .copyLastResponse:
                copyLastResponseToClipboard(viewModel)

            case .pasteCode:
                pasteCodeFromClipboard(viewModel)

            case .showTemplates:
                // Handled by view state
                break

            case .gitCommit:
                await generateGitCommitMessage(viewModel)

            case .buildProject:
                await buildCurrentProject(viewModel)

            case .showSettings:
                // Handled by view state
                break

            case .exportConversation:
                exportCurrentConversation(viewModel)

            case .importConversation:
                // Handled by view state
                break
            }
        }
    }

    // MARK: - Private Helper Methods

    private func copyLastResponseToClipboard(_ viewModel: ChatViewModel) {
        guard let lastMessage = viewModel.currentConversation?.messages.last(where: { $0.role == .assistant }) else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastMessage.content, forType: .string)

        logInfo("Copied last response to clipboard", category: "KeyboardShortcuts")
    }

    private func pasteCodeFromClipboard(_ viewModel: ChatViewModel) {
        guard let clipboardContent = NSPasteboard.general.string(forType: .string) else {
            return
        }

        // Format as code block
        let formattedCode = "```\n\(clipboardContent)\n```"
        viewModel.userInput = formattedCode

        logInfo("Pasted code from clipboard", category: "KeyboardShortcuts")
    }

    private func generateGitCommitMessage(_ viewModel: ChatViewModel) async {
        let prompt = """
        Generate a concise Git commit message for the staged changes.
        Use conventional commits format (feat:, fix:, docs:, etc.).
        Keep it under 72 characters for the subject line.
        """

        viewModel.userInput = prompt
        await viewModel.sendMessage()

        logInfo("Generating Git commit message", category: "KeyboardShortcuts")
    }

    private func buildCurrentProject(_ viewModel: ChatViewModel) async {
        let prompt = "Build the current Xcode project and report any errors or warnings."

        viewModel.userInput = prompt
        await viewModel.sendMessage()

        logInfo("Building current project", category: "KeyboardShortcuts")
    }

    private func exportCurrentConversation(_ viewModel: ChatViewModel) {
        guard let conversation = viewModel.currentConversation,
              let data = viewModel.exportConversation(conversation) else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(conversation.title).json"
        savePanel.allowedContentTypes = [.json]

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try data.write(to: url)
                logInfo("Exported conversation to \(url.path)", category: "KeyboardShortcuts")
            } catch {
                logError("Failed to export conversation: \(error.localizedDescription)", category: "KeyboardShortcuts")
            }
        }
    }
}

// MARK: - ChatViewModel Extensions

extension ChatViewModel {
    /// Clears the current conversation
    func clearCurrentConversation() async {
        guard let conversation = currentConversation else { return }

        // Create new empty conversation
        currentConversation = Conversation(title: "New Conversation")

        logInfo("Cleared conversation: \(conversation.title)", category: "ChatViewModel")
    }

    /// Regenerates the last assistant response
    func regenerateLastResponse() async {
        guard let conversation = currentConversation else { return }

        // Remove last assistant message
        if let lastAssistantIndex = conversation.messages.lastIndex(where: { $0.role == .assistant }) {
            currentConversation?.messages.remove(at: lastAssistantIndex)
        }

        // Regenerate
        await sendMessage()

        logInfo("Regenerating last response", category: "ChatViewModel")
    }

    /// Switches to conversation at index
    /// - Parameter index: Conversation index (0-based)
    func selectConversation(at index: Int) {
        guard index >= 0 && index < conversations.count else { return }
        loadConversation(conversations[index])
    }
}

// MARK: - Preview

struct CommandPaletteView_Previews: PreviewProvider {
    static var previews: some View {
        CommandPaletteView(
            isPresented: .constant(true),
            onSelectCommand: { _ in }
        )
    }
}
