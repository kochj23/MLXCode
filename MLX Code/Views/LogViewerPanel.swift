//
//  LogViewerPanel.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Live log viewer panel with filtering and export
struct LogViewerPanel: View {
    /// Log manager
    @ObservedObject private var logManager = LogManager.shared

    /// Search text
    @State private var searchText = ""

    /// Auto-scroll to bottom
    @State private var autoScroll = true

    /// Show metadata
    @State private var showMetadata = false

    /// Scroll proxy for auto-scrolling
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            header

            Divider()

            // Filters
            filters

            Divider()

            // Log list
            logList

            Divider()

            // Footer with stats
            footer
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Live Logs", systemImage: "list.bullet.rectangle")
                .font(.headline)

            Spacer()

            // Auto-scroll toggle
            Toggle(isOn: $autoScroll) {
                Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .foregroundColor(autoScroll ? .blue : .gray)
            }
            .toggleStyle(.button)
            .help("Auto-scroll to new logs")

            // Metadata toggle
            Toggle(isOn: $showMetadata) {
                Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
                    .foregroundColor(showMetadata ? .blue : .gray)
            }
            .toggleStyle(.button)
            .help("Show metadata")

            // Export button
            Button(action: exportLogs) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export logs")

            // Clear button
            Button(action: {
                logManager.clear()
            }) {
                Image(systemName: "trash")
            }
            .help("Clear all logs")
        }
        .padding(8)
    }

    // MARK: - Filters

    private var filters: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)

            // Level and category filters
            HStack {
                // Level filter
                Menu {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(action: {
                            logManager.minimumLevel = level
                        }) {
                            HStack {
                                Text(level.displayName)
                                if logManager.minimumLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Level: \(logManager.minimumLevel.displayName)")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)

                // Category filter
                if !logManager.availableCategories.isEmpty {
                    Menu {
                        Button("Show All") {
                            logManager.selectedCategories.removeAll()
                        }

                        Divider()

                        ForEach(Array(logManager.availableCategories).sorted(), id: \.self) { category in
                            Button(action: {
                                if logManager.selectedCategories.contains(category) {
                                    logManager.selectedCategories.remove(category)
                                } else {
                                    logManager.selectedCategories.insert(category)
                                }
                            }) {
                                HStack {
                                    Text(category)
                                    if logManager.selectedCategories.contains(category) ||
                                       logManager.selectedCategories.isEmpty {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Category: \(categoryFilterText)")
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                }

                Spacer()
            }
        }
        .padding(8)
    }

    private var categoryFilterText: String {
        if logManager.selectedCategories.isEmpty {
            return "All"
        } else if logManager.selectedCategories.count == 1 {
            return logManager.selectedCategories.first!
        } else {
            return "\(logManager.selectedCategories.count) selected"
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredLogs) { log in
                        LogEntryRow(entry: log, showMetadata: showMetadata)
                            .id(log.id)
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(8)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: logManager.logs.count) {
                if autoScroll {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(filteredLogs.count) / \(logManager.logs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let lastLog = logManager.logs.last {
                Text("Last: \(lastLog.formattedTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }

    // MARK: - Filtering

    private var filteredLogs: [LogEntry] {
        var logs = logManager.filteredLogs()

        // Apply search filter
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return logs
    }

    // MARK: - Export

    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "mlx-code-logs-\(Date().timeIntervalSince1970).txt"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            let content = logManager.exportToString()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    let showMetadata: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Timestamp
                Text(entry.formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                // Level icon
                Image(systemName: entry.levelIcon)
                    .foregroundColor(entry.levelColor)
                    .frame(width: 20)

                // Category
                Text(entry.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)

                // Message
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Metadata (if enabled and available)
            if showMetadata, let metadata = entry.metadata, !metadata.isEmpty {
                HStack {
                    Spacer().frame(width: 108) // Align with message
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key + ":")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(metadata[key] ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(entry.level == .error || entry.level == .critical ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Preview

struct LogViewerPanel_Previews: PreviewProvider {
    static var previews: some View {
        LogViewerPanel()
            .frame(width: 600, height: 400)
            .onAppear {
                // Add sample logs
                let logManager = LogManager.shared
                logManager.debug("Debug message", category: "Test")
                logManager.info("Info message", category: "MLX")
                logManager.warning("Warning message", category: "Python")
                logManager.error("Error message", category: "Chat")
                logManager.critical("Critical message", category: "System")
            }
    }
}
