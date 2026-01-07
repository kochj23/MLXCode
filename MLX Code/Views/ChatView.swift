//
//  ChatView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Main chat interface view
struct ChatView: View {
    /// View model for chat logic
    @StateObject private var viewModel = ChatViewModel()

    /// App settings
    @ObservedObject private var settings = AppSettings.shared

    /// Whether settings panel is shown
    @State private var showingSettings = false

    /// Whether conversation list is shown
    @State private var showingConversations = false

    /// Whether Git helper panel is shown
    @State private var showingGitHelper = false

    /// Whether GitHub panel is shown
    @State private var showingGitHubPanel = false

    /// Whether build errors panel is shown
    @State private var showingBuildErrors = false

    /// Whether log viewer panel is shown
    @State private var showingLogViewer = false

    /// Whether help viewer is shown
    @State private var showingHelp = false

    /// Current Git status
    @State private var gitStatus: GitStatus?

    /// Current build errors
    @State private var buildErrors: [BuildIssue] = []

    /// Permission error alert
    @State private var showingPermissionAlert = false
    @State private var permissionErrors: [String: String] = [:]

    var body: some View {
        mainView
            .navigationTitle("MLX Code")
            .modifier(SheetsModifier(
                showingSettings: $showingSettings,
                showingGitHelper: $showingGitHelper,
                showingGitHubPanel: $showingGitHubPanel,
                showingBuildErrors: $showingBuildErrors,
                showingHelp: $showingHelp,
                gitStatus: $gitStatus,
                buildErrors: buildErrors
            ))
            .modifier(AlertsModifier(
                viewModel: viewModel,
                showingPermissionAlert: $showingPermissionAlert,
                permissionErrors: permissionErrors,
                showingSettings: $showingSettings,
                formatPermissionErrors: formatPermissionErrors
            ))
            .modifier(KeyboardShortcutsModifier(viewModel: viewModel))
            .onAppear {
                checkPermissionsOnStartup()
            }
    }

    private var mainView: some View {
        NavigationSplitView {
            // Sidebar with conversation list
            conversationList
        } detail: {
            // Main chat area with optional log viewer
            HSplitView {
                // Main chat area
                VStack(spacing: 0) {
                    // Toolbar
                    toolbar

                    Divider()

                    // Messages area
                    ZStack {
                        messagesArea

                        // Thinking overlay (shown during initial processing)
                        if viewModel.isWaitingForFirstToken {
                            ThinkingOverlayView(message: "Preparing response...")
                                .transition(.opacity)
                        }
                    }

                    Divider()

                    // Input area
                    inputArea

                    // Status bar
                    statusBar
                }
                .frame(minWidth: 400)

                // Right panel with metrics and logs
                VStack(spacing: 0) {
                    // Token metrics panel (visible by default, opposite of logs)
                    TokenMetricsView(viewModel: viewModel)
                        .padding(8)

                    Divider()

                    // Log viewer panel (collapsible)
                    if showingLogViewer {
                        LogViewerPanel()
                    }
                }
                .frame(minWidth: 300, idealWidth: 400, maxWidth: 600)
            }
            .onChange(of: viewModel.isGenerating) { _, newValue in
                // Auto-open log viewer when generation starts
                if newValue && !showingLogViewer {
                    withAnimation {
                        showingLogViewer = true
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether the send button should be disabled
    private var sendButtonDisabled: Bool {
        if viewModel.isGenerating {
            return false // Stop button is always enabled
        }

        let hasText = !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Check if this is a direct tool command (doesn't need LLM loaded)
        let lowercased = viewModel.userInput.lowercased()
        let isDirectToolCommand = lowercased.contains("generate image") ||
                                  lowercased.contains("create image") ||
                                  lowercased.contains("make an image") ||
                                  lowercased.contains("generate video") ||
                                  lowercased.contains("create video") ||
                                  lowercased.contains("make a video") ||
                                  lowercased.contains("create animation") ||
                                  lowercased.hasPrefix("speak:") ||
                                  lowercased.hasPrefix("say:")

        // Button is enabled if:
        // - Has text AND (model is loaded OR is a direct tool command)
        return !hasText || (!viewModel.isModelLoaded && !isDirectToolCommand)
    }

    /// Color for the send button
    private var sendButtonColor: Color {
        if viewModel.isGenerating {
            return .red
        }

        // Check if this is a direct tool command
        let lowercased = viewModel.userInput.lowercased()
        let isDirectToolCommand = lowercased.contains("generate image") ||
                                  lowercased.contains("create image") ||
                                  lowercased.contains("make an image") ||
                                  lowercased.contains("generate video") ||
                                  lowercased.contains("create video") ||
                                  lowercased.contains("make a video") ||
                                  lowercased.contains("create animation") ||
                                  lowercased.hasPrefix("speak:") ||
                                  lowercased.hasPrefix("say:")

        // Use purple for direct tool commands (no LLM needed)
        if isDirectToolCommand && !viewModel.isModelLoaded {
            return .purple
        }

        if !viewModel.isModelLoaded {
            return Color.gray
        }

        let hasText = !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText ? Color.blue : Color.gray
    }

    /// Tooltip for the send button
    private var sendButtonTooltip: String {
        if viewModel.isGenerating {
            return "Stop generation"
        }

        // Check if this is a direct tool command
        let lowercased = viewModel.userInput.lowercased()
        let isDirectToolCommand = lowercased.contains("generate image") ||
                                  lowercased.contains("create image") ||
                                  lowercased.contains("make an image") ||
                                  lowercased.contains("generate video") ||
                                  lowercased.contains("create video") ||
                                  lowercased.contains("make a video") ||
                                  lowercased.contains("create animation") ||
                                  lowercased.hasPrefix("speak:") ||
                                  lowercased.hasPrefix("say:")

        if isDirectToolCommand && !viewModel.isModelLoaded {
            return "Execute tool (no model needed) (⌘↩)"
        }

        if !viewModel.isModelLoaded {
            return "Load a model first (or use tool commands)"
        }

        let hasText = !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText ? "Send message (⌘↩)" : "Type a message"
    }

    /// Token usage progress (0.0 to 1.0)
    private var tokenProgress: Double {
        guard viewModel.maxTokens > 0 else { return 0.0 }
        return Double(viewModel.inputTokenCount) / Double(viewModel.maxTokens)
    }

    /// Color for the token bar based on usage
    private var tokenBarColor: Color {
        if tokenProgress < 0.5 {
            return .green
        } else if tokenProgress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Subviews

    /// Conversation list sidebar
    private var conversationList: some View {
        List {
            Section {
                Button(action: { viewModel.newConversation() }) {
                    Label("New Conversation", systemImage: "plus.message")
                }
            }

            Section("Recent Conversations") {
                ForEach(viewModel.conversations) { conversation in
                    Button(action: { viewModel.loadConversation(conversation) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)

                            Text(conversation.lastMessagePreview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    /// Toolbar
    private var toolbar: some View {
        HStack {
            // Model selector
            ModelSelectorView()

            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isModelLoaded ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Git helper button
            Button(action: {
                Task {
                    await loadGitStatus()
                    showingGitHelper = true
                }
            }) {
                Label("Git", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(.plain)
            .help("Git helper")

            // GitHub panel button
            Button(action: { showingGitHubPanel = true }) {
                Image(systemName: "globe")
            }
            .buttonStyle(.plain)
            .help("GitHub Operations (⌘G)")

            // Build errors button
            if !buildErrors.isEmpty {
                Button(action: { showingBuildErrors = true }) {
                    Label("\(buildErrors.errorCount) errors", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Show build errors")
            }

            // Log viewer toggle button
            Button(action: {
                withAnimation {
                    showingLogViewer.toggle()
                }
            }) {
                Image(systemName: showingLogViewer ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    .foregroundColor(showingLogViewer ? .blue : .primary)
            }
            .buttonStyle(.plain)
            .help("Toggle Log Viewer (⌘L)")
            .keyboardShortcut("l", modifiers: .command)

            // Help button
            Button(action: { showingHelp = true }) {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.plain)
            .help("Help & Documentation (⌘?)")
            .keyboardShortcut("?", modifiers: .command)

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding()
    }

    /// Messages display area
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let conversation = viewModel.currentConversation {
                        ForEach(conversation.messages) { message in
                            MessageRowView(message: message)
                                .id(message.id)
                        }
                    } else {
                        // Welcome message
                        VStack(spacing: 16) {
                            Image(systemName: "message.circle")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)

                            Text("Welcome to MLX Code")
                                .font(.title)

                            Text("Start a conversation by typing a message below")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.currentConversation?.messages.count) {
                // Scroll to bottom when new message added
                if let lastMessage = viewModel.currentConversation?.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Input area
    private var inputArea: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text editor
                TextEditor(text: $viewModel.userInput)
                    .frame(minHeight: 60, maxHeight: 120)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .disabled(viewModel.isGenerating)

                // Send/Stop button
                Button(action: {
                    if viewModel.isGenerating {
                        viewModel.stopGeneration()
                    } else {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isGenerating ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(sendButtonColor)
                        .cornerRadius(22)
                }
                .buttonStyle(.plain)
                .disabled(sendButtonDisabled)
                .keyboardShortcut(.return, modifiers: [.command])
                .help(sendButtonTooltip)
            }

            // Token counter bar
            HStack(spacing: 8) {
                Text("\(viewModel.inputTokenCount) / \(viewModel.maxTokens) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        // Progress bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(tokenBarColor)
                            .frame(width: min(geometry.size.width * tokenProgress, geometry.size.width), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
    }

    /// Status bar
    private var statusBar: some View {
        HStack {
            // Message count
            if let conversation = viewModel.currentConversation {
                Text("\(conversation.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Prominent status message when generating
            if viewModel.isGenerating {
                HStack(spacing: 8) {
                    // Status message with icon
                    if viewModel.isWaitingForFirstToken {
                        Image(systemName: "brain.head.profile")
                            .font(.body)
                            .foregroundColor(.blue)
                        Text("Thinking...")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.body)
                            .foregroundColor(.green)
                        Text("Generating")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.isWaitingForFirstToken ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                )
            }

            // Performance metrics with speedometer gauges
            if viewModel.isGenerating && viewModel.showPerformanceMetrics && !viewModel.isWaitingForFirstToken {
                HStack(spacing: 16) {
                    // Token count gauge
                    SpeedometerGaugeView(
                        value: Double(viewModel.currentTokenCount),
                        maxValue: Double(viewModel.maxTokens),
                        label: "Tokens",
                        valueText: formatTokenCount(viewModel.currentTokenCount),
                        size: 70
                    )

                    // Tokens per second gauge
                    if viewModel.tokensPerSecond > 0 {
                        SpeedometerGaugeView(
                            value: viewModel.tokensPerSecond,
                            maxValue: 200, // Reasonable max speed
                            label: "t/s",
                            valueText: String(format: "%.0f", viewModel.tokensPerSecond),
                            size: 70
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            // Progress indicator
            if viewModel.isGenerating {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            // Enhanced background when generating
            viewModel.isGenerating ?
                Color.blue.opacity(0.05) :
                Color(NSColor.controlBackgroundColor)
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isGenerating)
    }

    // MARK: - Helper Methods

    /// Formats token count with K suffix if large
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return "\(count)"
    }

    /// Loads Git status for current project
    private func loadGitStatus() async {
        do {
            // Get current working directory (you may want to make this configurable)
            let projectPath = "/Volumes/Data/xcode/MLX Code"
            let status = try await GitService.shared.getStatus(in: projectPath)
            gitStatus = status
        } catch {
            viewModel.errorMessage = "Failed to load Git status: \(error.localizedDescription)"
        }
    }

    /// Parses build output and updates build errors
    /// - Parameter output: xcodebuild output
    func parseBuildOutput(_ output: String) {
        buildErrors = BuildErrorParser.parse(output)
    }

    // MARK: - Permission Checking

    /// Checks path permissions on startup
    private func checkPermissionsOnStartup() {
        // Delay check slightly to let UI load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            permissionErrors = settings.validateAllPathPermissions()
            if !permissionErrors.isEmpty {
                showingPermissionAlert = true
            }
        }
    }

    /// Formats permission errors for alert display
    private func formatPermissionErrors() -> String {
        var message = "Some directories lack write permissions:\n\n"
        for (label, error) in permissionErrors.sorted(by: { $0.key < $1.key }) {
            message += "• \(label): \(error)\n"
        }
        message += "\nOpen Settings to fix these issues or choose different directories."
        return message
    }
}

// MARK: - Git Helper View

/// View for displaying Git status and operations
struct GitHelperView: View {
    @Binding var gitStatus: GitStatus?
    @Environment(\.dismiss) private var dismiss
    @State private var commitMessage = ""
    @State private var generatingCommitMessage = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let status = gitStatus {
                    // Branch info
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Branch: \(status.branch)")
                            .font(.headline)
                    }

                    Divider()

                    // Changes section
                    if status.hasChanges {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Changes")
                                .font(.headline)

                            if !status.modifiedFiles.isEmpty {
                                ForEach(status.modifiedFiles, id: \.self) { file in
                                    Label(file, systemImage: "pencil.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }

                            if !status.addedFiles.isEmpty {
                                ForEach(status.addedFiles, id: \.self) { file in
                                    Label(file, systemImage: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }

                            if !status.deletedFiles.isEmpty {
                                ForEach(status.deletedFiles, id: \.self) { file in
                                    Label(file, systemImage: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Divider()

                        // Commit section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Commit Message")
                                    .font(.headline)

                                Spacer()

                                Button(action: { Task { await generateCommitMessage() } }) {
                                    Label("Generate with AI", systemImage: "sparkles")
                                }
                                .disabled(generatingCommitMessage)
                            }

                            TextEditor(text: $commitMessage)
                                .frame(height: 100)
                                .border(Color.gray.opacity(0.3))

                            Button("Commit Changes") {
                                Task { await commitChanges() }
                            }
                            .disabled(commitMessage.isEmpty || generatingCommitMessage)
                        }
                    } else {
                        Text("No changes to commit")
                            .foregroundColor(.secondary)
                    }

                    // Untracked files
                    if status.hasUntrackedFiles {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Untracked Files")
                                .font(.headline)

                            ForEach(status.untrackedFiles, id: \.self) { file in
                                Label(file, systemImage: "questionmark.circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Spacer()
                } else {
                    ProgressView("Loading Git status...")
                }
            }
            .padding()
            .navigationTitle("Git Helper")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func generateCommitMessage() async {
        generatingCommitMessage = true
        defer { generatingCommitMessage = false }

        do {
            let message = try await GitService.shared.generateCommitMessage(in: "/Volumes/Data/xcode/MLX Code")
            commitMessage = message
        } catch {
            // Handle error silently or show alert
            commitMessage = "chore: Update files"
        }
    }

    private func commitChanges() async {
        do {
            try await GitService.shared.commit(message: commitMessage, in: "/Volumes/Data/xcode/MLX Code")
            dismiss()
        } catch {
            // Handle error
        }
    }
}

// MARK: - Build Errors View

/// View for displaying build errors and warnings
struct BuildErrorsView: View {
    let errors: [BuildIssue]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeverity: BuildIssueSeverity?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Summary
                HStack {
                    Text(BuildErrorParser.generateSummary(errors))
                        .font(.headline)

                    Spacer()

                    // Severity filter
                    Picker("Filter", selection: $selectedSeverity) {
                        Text("All").tag(nil as BuildIssueSeverity?)
                        ForEach(BuildIssueSeverity.allCases, id: \.self) { severity in
                            Text(severity.displayName).tag(severity as BuildIssueSeverity?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                .padding()

                Divider()

                // Errors list
                List {
                    ForEach(filteredErrors) { issue in
                        BuildIssueRow(issue: issue)
                    }
                }
            }
            .navigationTitle("Build Issues")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var filteredErrors: [BuildIssue] {
        if let severity = selectedSeverity {
            return errors.filter { $0.severity == severity }
        }
        return errors
    }
}

/// Row view for a single build issue
struct BuildIssueRow: View {
    let issue: BuildIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.icon)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(issue.severity.displayName)
                            .font(.headline)
                            .foregroundColor(severityColor)

                        if !issue.location.isEmpty {
                            Text(issue.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(issue.message)
                        .font(.body)
                }

                Spacer()
            }

            // Suggestion
            if let suggestion = issue.suggestion {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)

                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 24)
            }

            // Notes
            if !issue.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issue.notes) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Text(note.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var severityColor: Color {
        switch issue.severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .note:
            return .blue
        }
    }
}

// MARK: - View Modifiers

struct SheetsModifier: ViewModifier {
    @Binding var showingSettings: Bool
    @Binding var showingGitHelper: Bool
    @Binding var showingGitHubPanel: Bool
    @Binding var showingBuildErrors: Bool
    @Binding var showingHelp: Bool
    @Binding var gitStatus: GitStatus?
    let buildErrors: [BuildIssue]

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingGitHelper) {
                GitHelperView(gitStatus: $gitStatus)
            }
            .sheet(isPresented: $showingGitHubPanel) {
                GitHubPanelView()
            }
            .sheet(isPresented: $showingBuildErrors) {
                BuildErrorsView(errors: buildErrors)
            }
            .sheet(isPresented: $showingHelp) {
                HelpView()
            }
    }
}

struct AlertsModifier: ViewModifier {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingPermissionAlert: Bool
    let permissionErrors: [String: String]
    @Binding var showingSettings: Bool
    let formatPermissionErrors: () -> String

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Write Permission Issues", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    showingSettings = true
                }
                Button("Dismiss") { }
            } message: {
                Text(formatPermissionErrors())
            }
    }
}

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var viewModel: ChatViewModel

    func body(content: Content) -> some View {
        content
            .background(
                Button("") {
                    viewModel.newConversation()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .hidden()
            )
            .background(
                Button("") {
                    Task {
                        await viewModel.regenerateLastResponse()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .hidden()
            )
    }
}

// MARK: - Preview

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .frame(width: 1000, height: 700)
    }
}
