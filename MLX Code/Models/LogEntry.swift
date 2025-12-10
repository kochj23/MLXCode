//
//  LogEntry.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents a single log entry
struct LogEntry: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// Timestamp when log was created
    let timestamp: Date

    /// Log severity level
    let level: LogLevel

    /// Category/source of the log
    let category: String

    /// Log message
    let message: String

    /// Optional metadata
    var metadata: [String: String]?

    /// Initialize a new log entry
    init(level: LogLevel, category: String, message: String, metadata: [String: String]? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
    }

    /// Formatted timestamp string
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Color for the log level
    var levelColor: Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }

    /// Icon for the log level
    var levelIcon: String {
        switch level {
        case .debug: return "ant.circle"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "flame.fill"
        }
    }
}

/// Log severity levels
enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    var displayName: String {
        return rawValue
    }
}

/// Manages application-wide logging
@MainActor
class LogManager: ObservableObject {
    /// Shared singleton instance
    static let shared = LogManager()

    /// All log entries
    @Published private(set) var logs: [LogEntry] = []

    /// Maximum number of logs to keep in memory
    let maxLogs = 10000

    /// Whether logging is enabled
    @Published var isEnabled = true

    /// Minimum log level to capture
    @Published var minimumLevel: LogLevel = .debug

    /// Selected categories filter (empty = show all)
    @Published var selectedCategories: Set<String> = []

    /// Available categories
    @Published private(set) var availableCategories: Set<String> = []

    private init() {}

    /// Add a log entry
    func log(_ level: LogLevel, category: String, message: String, metadata: [String: String]? = nil) {
        guard isEnabled else { return }

        // Check if level is high enough
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        guard let currentIndex = levels.firstIndex(of: level),
              let minIndex = levels.firstIndex(of: minimumLevel),
              currentIndex >= minIndex else {
            return
        }

        let entry = LogEntry(level: level, category: category, message: message, metadata: metadata)

        logs.append(entry)
        availableCategories.insert(category)

        // Trim old logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    /// Convenience methods
    func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(.debug, category: category, message: message, metadata: metadata)
    }

    func info(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(.info, category: category, message: message, metadata: metadata)
    }

    func warning(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(.warning, category: category, message: message, metadata: metadata)
    }

    func error(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(.error, category: category, message: message, metadata: metadata)
    }

    func critical(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(.critical, category: category, message: message, metadata: metadata)
    }

    /// Clear all logs
    func clear() {
        logs.removeAll()
        availableCategories.removeAll()
    }

    /// Export logs to string
    func exportToString() -> String {
        return logs.map { entry in
            "[\(entry.formattedTime)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }

    /// Get filtered logs
    func filteredLogs() -> [LogEntry] {
        if selectedCategories.isEmpty {
            return logs
        }
        return logs.filter { selectedCategories.contains($0.category) }
    }
}
