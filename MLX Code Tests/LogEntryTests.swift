//
//  LogEntryTests.swift
//  MLX Code Tests
//
//  Unit tests for LogEntry and LogManager: entry creation, level filtering,
//  category tracking, export, Codable conformance, and capacity limits.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class LogEntryTests: XCTestCase {

    // MARK: - LogEntry Creation

    func testLogEntryCreation() {
        let entry = LogEntry(level: .info, category: "Test", message: "Hello")
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.category, "Test")
        XCTAssertEqual(entry.message, "Hello")
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.timestamp)
    }

    func testLogEntryWithMetadata() {
        let entry = LogEntry(
            level: .error,
            category: "Network",
            message: "Connection failed",
            metadata: ["url": "https://example.com", "code": "500"]
        )
        XCTAssertEqual(entry.metadata?["url"], "https://example.com")
        XCTAssertEqual(entry.metadata?["code"], "500")
    }

    func testLogEntryDefaultMetadataNil() {
        let entry = LogEntry(level: .debug, category: "Test", message: "msg")
        XCTAssertNil(entry.metadata)
    }

    // MARK: - Formatted Time

    func testFormattedTimeNotEmpty() {
        let entry = LogEntry(level: .info, category: "Test", message: "msg")
        XCTAssertFalse(entry.formattedTime.isEmpty, "Formatted time should not be empty")
        // Format is HH:mm:ss.SSS
        XCTAssertTrue(entry.formattedTime.contains(":"), "Formatted time should contain colons")
    }

    // MARK: - Level Icons

    func testLevelIcons() {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        for level in levels {
            let entry = LogEntry(level: level, category: "Test", message: "msg")
            XCTAssertFalse(entry.levelIcon.isEmpty,
                "Level \(level.rawValue) should have an icon")
        }
    }

    // MARK: - LogLevel

    func testLogLevelRawValues() {
        XCTAssertEqual(LogLevel.debug.rawValue, "DEBUG")
        XCTAssertEqual(LogLevel.info.rawValue, "INFO")
        XCTAssertEqual(LogLevel.warning.rawValue, "WARNING")
        XCTAssertEqual(LogLevel.error.rawValue, "ERROR")
        XCTAssertEqual(LogLevel.critical.rawValue, "CRITICAL")
    }

    func testLogLevelCaseIterable() {
        XCTAssertEqual(LogLevel.allCases.count, 5, "Should have 5 log levels")
    }

    func testLogLevelDisplayNames() {
        for level in LogLevel.allCases {
            XCTAssertEqual(level.displayName, level.rawValue)
        }
    }

    // MARK: - Codable Round-Trip

    func testLogEntryCodableRoundTrip() throws {
        let original = LogEntry(
            level: .warning,
            category: "Security",
            message: "Suspicious activity detected",
            metadata: ["ip": "10.0.0.1"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogEntry.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.level, original.level)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.metadata?["ip"], "10.0.0.1")
    }

    func testLogLevelCodableRoundTrip() throws {
        for level in LogLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(LogLevel.self, from: data)
            XCTAssertEqual(decoded, level, "LogLevel \(level.rawValue) should survive Codable round-trip")
        }
    }
}

// MARK: - LogManager Tests

@MainActor
final class LogManagerTests: XCTestCase {

    private var logManager: LogManager!

    override func setUp() {
        logManager = LogManager.shared
        logManager.clear()
        logManager.isEnabled = true
        logManager.minimumLevel = .debug
        logManager.selectedCategories = []
    }

    override func tearDown() {
        logManager.clear()
    }

    // MARK: - Singleton

    func testSharedInstance() {
        let a = LogManager.shared
        let b = LogManager.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - Logging

    func testBasicLogging() {
        logManager.info("Test message", category: "UnitTest")
        XCTAssertEqual(logManager.logs.count, 1)
        XCTAssertEqual(logManager.logs.first?.message, "Test message")
        XCTAssertEqual(logManager.logs.first?.level, .info)
    }

    func testConvenienceMethods() {
        logManager.debug("d", category: "T")
        logManager.info("i", category: "T")
        logManager.warning("w", category: "T")
        logManager.error("e", category: "T")
        logManager.critical("c", category: "T")
        XCTAssertEqual(logManager.logs.count, 5)
    }

    func testDisabledLogging() {
        logManager.isEnabled = false
        logManager.info("Should not appear", category: "T")
        XCTAssertTrue(logManager.logs.isEmpty, "Logs should not be recorded when disabled")
    }

    // MARK: - Level Filtering

    func testMinimumLevelFiltering() {
        logManager.minimumLevel = .warning
        logManager.debug("d", category: "T")
        logManager.info("i", category: "T")
        logManager.warning("w", category: "T")
        logManager.error("e", category: "T")
        XCTAssertEqual(logManager.logs.count, 2,
            "Only warning and above should be recorded when minimumLevel = .warning")
    }

    func testMinimumLevelCriticalOnly() {
        logManager.minimumLevel = .critical
        logManager.debug("d", category: "T")
        logManager.info("i", category: "T")
        logManager.warning("w", category: "T")
        logManager.error("e", category: "T")
        logManager.critical("c", category: "T")
        XCTAssertEqual(logManager.logs.count, 1)
        XCTAssertEqual(logManager.logs.first?.level, .critical)
    }

    // MARK: - Category Tracking

    func testCategoryTracking() {
        logManager.info("a", category: "Network")
        logManager.info("b", category: "Security")
        logManager.info("c", category: "Network")

        XCTAssertTrue(logManager.availableCategories.contains("Network"))
        XCTAssertTrue(logManager.availableCategories.contains("Security"))
        XCTAssertEqual(logManager.availableCategories.count, 2)
    }

    // MARK: - Category Filtering

    func testFilteredLogsByCategory() {
        logManager.info("a", category: "Network")
        logManager.info("b", category: "Security")
        logManager.info("c", category: "Network")

        logManager.selectedCategories = ["Network"]
        let filtered = logManager.filteredLogs()
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "Network" })
    }

    func testFilteredLogsEmptyCategoryShowsAll() {
        logManager.info("a", category: "A")
        logManager.info("b", category: "B")

        logManager.selectedCategories = []
        let filtered = logManager.filteredLogs()
        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - Capacity

    func testMaxLogsCapacity() {
        for i in 0..<10100 {
            logManager.info("Log \(i)", category: "Stress")
        }
        XCTAssertLessThanOrEqual(logManager.logs.count, logManager.maxLogs,
            "Logs should be trimmed to maxLogs")
    }

    // MARK: - Clear

    func testClearRemovesAllLogs() {
        logManager.info("a", category: "A")
        logManager.error("b", category: "B")
        logManager.clear()
        XCTAssertTrue(logManager.logs.isEmpty)
        XCTAssertTrue(logManager.availableCategories.isEmpty)
    }

    // MARK: - Export

    func testExportToString() {
        logManager.info("Hello world", category: "Test")
        logManager.error("Something broke", category: "Test")

        let exported = logManager.exportToString()
        XCTAssertFalse(exported.isEmpty)
        XCTAssertTrue(exported.contains("Hello world"))
        XCTAssertTrue(exported.contains("Something broke"))
        XCTAssertTrue(exported.contains("[INFO]"))
        XCTAssertTrue(exported.contains("[ERROR]"))
    }

    func testExportEmptyLogs() {
        let exported = logManager.exportToString()
        XCTAssertTrue(exported.isEmpty, "Exporting empty logs should produce empty string")
    }

    // MARK: - Metadata

    func testLogWithMetadata() {
        logManager.log(.info, category: "Net", message: "Request", metadata: ["url": "https://a.com"])
        XCTAssertEqual(logManager.logs.first?.metadata?["url"], "https://a.com")
    }
}
