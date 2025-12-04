//
//  LogViewerView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Log viewer interface for debugging
struct LogViewerView: View {
    /// All logs
    @State private var logs: [AppLogger.LogEntry] = []

    /// Selected log level filter
    @State private var selectedLevel: AppLogger.Level?

    /// Selected category filter
    @State private var selectedCategory: String?

    /// Search query
    @State private var searchQuery = ""

    /// Auto-refresh toggle
    @State private var autoRefresh = true

    /// Refresh timer
    @State private var refreshTimer: Timer?

    /// Statistics
    @State private var statistics: AppLogger.LogStatistics?

    /// Sheet presentations
    @State private var showingExportSheet = false
    @State private var showingStatistics = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            HSplitView {
                // Sidebar - Filters
                sidebar
                    .frame(minWidth: 200, maxWidth: 250)

                // Main content - Logs
                logList
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            refreshLogs()
            if autoRefresh {
                startAutoRefresh()
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .sheet(isPresented: $showingStatistics) {
            statisticsView
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: LogDocument(logs: filteredLogs),
            contentType: .plainText,
            defaultFilename: "mlx-code-logs-\(Date().ISO8601Format()).txt"
        ) { result in
            if case .failure(let error) = result {
                logError("LogViewer", "Failed to export logs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            // Title
            Text("Application Logs")
                .font(.headline)

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 200)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Auto-refresh toggle
            Toggle("Auto-refresh", isOn: $autoRefresh)
                .onChange(of: autoRefresh) { _, newValue in
                    if newValue {
                        startAutoRefresh()
                    } else {
                        stopAutoRefresh()
                    }
                }

            // Refresh button
            Button(action: refreshLogs) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh logs")

            // Statistics button
            Button(action: { showingStatistics = true }) {
                Image(systemName: "chart.bar")
            }
            .help("View statistics")

            // Export button
            Button(action: { showingExportSheet = true }) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export logs")

            // Clear button
            Button(action: clearLogs) {
                Image(systemName: "trash")
            }
            .help("Clear logs")
        }
        .padding()
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section("Log Level") {
                Button(action: { selectedLevel = nil }) {
                    HStack {
                        Text("All")
                        Spacer()
                        if selectedLevel == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)

                ForEach(AppLogger.Level.allCases, id: \.self) { level in
                    Button(action: { selectedLevel = level }) {
                        HStack {
                            Text("\(level.emoji) \(level.rawValue)")
                            Spacer()
                            if selectedLevel == level {
                                Image(systemName: "checkmark")
                            }
                            Text("\(count(for: level))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Category") {
                Button(action: { selectedCategory = nil }) {
                    HStack {
                        Text("All")
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)

                ForEach(uniqueCategories, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredLogs) { log in
                    LogRowView(log: log)
                }
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        VStack(spacing: 20) {
            Text("Log Statistics")
                .font(.title)

            if let stats = statistics {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Total Logs:")
                            .font(.headline)
                        Spacer()
                        Text("\(stats.totalLogs)")
                    }

                    Divider()

                    Group {
                        statRow("🔍 Debug", count: stats.debugCount)
                        statRow("ℹ️ Info", count: stats.infoCount)
                        statRow("⚠️ Warning", count: stats.warningCount)
                        statRow("❌ Error", count: stats.errorCount)
                        statRow("🔥 Critical", count: stats.criticalCount)
                    }

                    Divider()

                    Text("Top Categories:")
                        .font(.headline)

                    ForEach(stats.topCategories, id: \.key) { category, count in
                        HStack {
                            Text(category)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(width: 400)
            }

            Button("Close") {
                showingStatistics = false
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }

    private func statRow(_ label: String, count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var filteredLogs: [AppLogger.LogEntry] {
        var result = logs

        // Filter by level
        if let level = selectedLevel {
            result = result.filter { $0.level == level }
        }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchQuery) }
        }

        return result
    }

    private var uniqueCategories: [String] {
        Array(Set(logs.map { $0.category })).sorted()
    }

    private func count(for level: AppLogger.Level) -> Int {
        logs.filter { $0.level == level }.count
    }

    // MARK: - Actions

    private func refreshLogs() {
        Task {
            let allLogs = await AppLogger.shared.getAllLogs()
            let stats = await AppLogger.shared.getStatistics()

            await MainActor.run {
                logs = allLogs
                statistics = stats
            }
        }
    }

    private func clearLogs() {
        Task {
            await AppLogger.shared.clearLogs()
            await MainActor.run {
                logs = []
            }
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refreshLogs()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let log: AppLogger.LogEntry

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main log line
            HStack(alignment: .top, spacing: 8) {
                // Level emoji
                Text(log.level.emoji)

                // Timestamp
                Text(log.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 180, alignment: .leading)

                // Category
                Text(log.category)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor)
                    .cornerRadius(4)

                // Message
                Text(log.message)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(isExpanded ? nil : 1)

                Spacer()

                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()

                    HStack {
                        Text("File:")
                            .foregroundColor(.secondary)
                        Text(log.file)
                            .font(.system(.caption, design: .monospaced))
                    }

                    HStack {
                        Text("Function:")
                            .foregroundColor(.secondary)
                        Text(log.function)
                            .font(.system(.caption, design: .monospaced))
                    }

                    HStack {
                        Text("Line:")
                            .foregroundColor(.secondary)
                        Text("\(log.line)")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .font(.caption)
                .padding(.leading, 40)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackgroundColor)
        .cornerRadius(4)
    }

    private var categoryColor: Color {
        Color.blue.opacity(0.2)
    }

    private var rowBackgroundColor: Color {
        switch log.level {
        case .debug:
            return Color.clear
        case .info:
            return Color.blue.opacity(0.05)
        case .warning:
            return Color.yellow.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .critical:
            return Color.red.opacity(0.2)
        }
    }
}

// MARK: - Log Document (for export)

import UniformTypeIdentifiers

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var logs: [AppLogger.LogEntry]

    init(logs: [AppLogger.LogEntry]) {
        self.logs = logs
    }

    init(configuration: ReadConfiguration) throws {
        logs = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = logs.map { $0.detailedMessage }.joined(separator: "\n\n")
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

struct LogViewerView_Previews: PreviewProvider {
    static var previews: some View {
        LogViewerView()
    }
}
