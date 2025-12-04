//
//  AppLogger.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import OSLog

/// Enhanced application-wide logging system with debug capabilities
/// Allows debugging system issues without needing console access
actor AppLogger {
    /// Shared logger instance
    static let shared = AppLogger()

    /// Log level
    enum Level: String, Codable, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }
    }

    /// Log entry
    struct LogEntry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let level: Level
        let category: String
        let message: String
        let file: String
        let function: String
        let line: Int

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var formattedMessage: String {
            "\(level.emoji) [\(formattedTimestamp)] [\(category)] \(message)"
        }

        var detailedMessage: String {
            """
            \(level.emoji) [\(formattedTimestamp)] [\(level.rawValue)] [\(category)]
            Message: \(message)
            Location: \(file):\(line) in \(function)
            """
        }
    }

    // MARK: - Properties

    /// In-memory log buffer (last 1000 entries)
    private var logBuffer: [LogEntry] = []
    private let maxBufferSize = 1000

    /// File URL for persistent logs
    private var logFileURL: URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let logsDirectory = appSupport.appendingPathComponent("MLX Code/Logs")

        // Create directory if needed
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // Log file name with date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        return logsDirectory.appendingPathComponent("mlx-code-\(dateString).log")
    }

    /// Whether to write logs to file
    var enableFileLogging = true

    /// Whether to enable debug logging
    var enableDebugLogging = true

    /// Minimum log level to record
    var minimumLogLevel: Level = .debug

    /// OSLog logger
    private let osLogger = Logger(subsystem: "com.mlxcode.app", category: "AppLogger")

    // MARK: - Initialization

    private init() {
        log(.info, category: "AppLogger", "AppLogger initialized")
    }

    // MARK: - Logging Methods

    /// Logs a message with the specified level and category
    /// - Parameters:
    ///   - level: Log level
    ///   - category: Log category (e.g., "MLX", "UI", "Network")
    ///   - message: Log message
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    func log(
        _ level: Level,
        category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Skip debug logs if disabled
        if level == .debug && !enableDebugLogging {
            return
        }

        // Skip if below minimum log level
        if level.rawValue < minimumLogLevel.rawValue {
            return
        }

        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line
        )

        // Add to buffer
        logBuffer.append(entry)

        // Trim buffer if needed
        if logBuffer.count > maxBufferSize {
            logBuffer.removeFirst(logBuffer.count - maxBufferSize)
        }

        // Write to OSLog
        osLogger.log(level: level.osLogType, "\(category): \(message)")

        // Write to file
        if enableFileLogging {
            writeToFile(entry)
        }

        // Print to console in debug builds
        #if DEBUG
        print(entry.formattedMessage)
        #endif
    }

    /// Debug log
    func debug(
        _ category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, category: category, message, file: file, function: function, line: line)
    }

    /// Info log
    func info(
        _ category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, category: category, message, file: file, function: function, line: line)
    }

    /// Warning log
    func warning(
        _ category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, category: category, message, file: file, function: function, line: line)
    }

    /// Error log
    func error(
        _ category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, category: category, message, file: file, function: function, line: line)
    }

    /// Critical log
    func critical(
        _ category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.critical, category: category, message, file: file, function: function, line: line)
    }

    // MARK: - Log Retrieval

    /// Gets all logs in memory
    func getAllLogs() -> [LogEntry] {
        return logBuffer
    }

    /// Gets logs filtered by level
    func getLogs(level: Level) -> [LogEntry] {
        return logBuffer.filter { $0.level == level }
    }

    /// Gets logs filtered by category
    func getLogs(category: String) -> [LogEntry] {
        return logBuffer.filter { $0.category == category }
    }

    /// Searches logs by message content
    func searchLogs(_ query: String) -> [LogEntry] {
        return logBuffer.filter { $0.message.localizedCaseInsensitiveContains(query) }
    }

    /// Gets recent logs (last N entries)
    func getRecentLogs(count: Int = 100) -> [LogEntry] {
        let startIndex = max(0, logBuffer.count - count)
        return Array(logBuffer[startIndex...])
    }

    // MARK: - File Operations

    /// Writes log entry to file
    private func writeToFile(_ entry: LogEntry) {
        guard let url = logFileURL else { return }

        let logLine = "\(entry.formattedMessage)\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                // Create new file
                try? data.write(to: url)
            }
        }
    }

    /// Exports logs to a file
    func exportLogs(to url: URL) throws {
        let logs = logBuffer.map { $0.detailedMessage }.joined(separator: "\n\n")
        try logs.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Exports logs as JSON
    func exportLogsAsJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(logBuffer)
        try data.write(to: url)
    }

    /// Clears all in-memory logs
    func clearLogs() {
        logBuffer.removeAll()
        log(.info, category: "AppLogger", "Logs cleared")
    }

    /// Deletes all log files
    func deleteLogFiles() throws {
        guard let logsDirectory = logFileURL?.deletingLastPathComponent() else { return }

        let fileManager = FileManager.default
        let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil)

        for file in logFiles where file.pathExtension == "log" {
            try fileManager.removeItem(at: file)
        }

        log(.info, category: "AppLogger", "Log files deleted")
    }

    /// Gets log file URL
    func getLogFileURL() -> URL? {
        return logFileURL
    }

    // MARK: - Statistics

    /// Gets log statistics
    func getStatistics() -> LogStatistics {
        let total = logBuffer.count
        let byLevel = Dictionary(grouping: logBuffer, by: { $0.level })
            .mapValues { $0.count }

        let byCategory = Dictionary(grouping: logBuffer, by: { $0.category })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        return LogStatistics(
            totalLogs: total,
            debugCount: byLevel[.debug] ?? 0,
            infoCount: byLevel[.info] ?? 0,
            warningCount: byLevel[.warning] ?? 0,
            errorCount: byLevel[.error] ?? 0,
            criticalCount: byLevel[.critical] ?? 0,
            topCategories: Array(byCategory.prefix(5))
        )
    }

    struct LogStatistics {
        let totalLogs: Int
        let debugCount: Int
        let infoCount: Int
        let warningCount: Int
        let errorCount: Int
        let criticalCount: Int
        let topCategories: [(key: String, value: Int)]
    }
}

// MARK: - Global Convenience Functions

/// Global debug log function
func logDebug(
    _ category: String,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await AppLogger.shared.debug(category, message, file: file, function: function, line: line)
    }
}

/// Global info log function
func logInfo(
    _ category: String,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await AppLogger.shared.info(category, message, file: file, function: function, line: line)
    }
}

/// Global warning log function
func logWarning(
    _ category: String,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await AppLogger.shared.warning(category, message, file: file, function: function, line: line)
    }
}

/// Global error log function
func logError(
    _ category: String,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await AppLogger.shared.error(category, message, file: file, function: function, line: line)
    }
}

/// Global critical log function
func logCritical(
    _ category: String,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await AppLogger.shared.critical(category, message, file: file, function: function, line: line)
    }
}
