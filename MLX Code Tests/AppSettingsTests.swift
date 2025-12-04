//
//  AppSettingsTests.swift
//  MLX Code Tests
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import XCTest
@testable import MLX_Code

/// Unit tests for AppSettings
@MainActor
final class AppSettingsTests: XCTestCase {

    var settings: AppSettings!

    override func setUp() async throws {
        settings = AppSettings.shared
    }

    override func tearDown() async throws {
        // Reset to defaults after each test
        settings.resetToDefaults()
    }

    // MARK: - Temperature Tests

    func testTemperatureDefaultValue() {
        XCTAssertEqual(settings.temperature, 0.7, "Default temperature should be 0.7")
    }

    func testTemperatureValidation() {
        settings.temperature = 2.5 // Exceeds max
        settings.saveSettings()
        settings.loadSettings()

        // Should be clamped to valid range
        XCTAssertLessThanOrEqual(settings.temperature, 2.0, "Temperature should not exceed 2.0")
    }

    // MARK: - Max Tokens Tests

    func testMaxTokensDefaultValue() {
        XCTAssertEqual(settings.maxTokens, 2048, "Default max tokens should be 2048")
    }

    func testMaxTokensValidation() {
        settings.maxTokens = 200_000 // Exceeds max
        settings.saveSettings()
        settings.loadSettings()

        // Should be clamped to valid range
        XCTAssertLessThanOrEqual(settings.maxTokens, 100_000, "Max tokens should not exceed 100,000")
    }

    // MARK: - Python Path Tests

    func testPythonPathValidation() {
        settings.pythonPath = "/usr/bin/python3"
        let isValid = settings.validatePythonPath()

        // /usr/bin/python3 should exist on macOS
        XCTAssertTrue(isValid, "Python path /usr/bin/python3 should be valid")
    }

    func testInvalidPythonPath() {
        settings.pythonPath = "/invalid/path/to/python"
        let isValid = settings.validatePythonPath()

        XCTAssertFalse(isValid, "Invalid Python path should return false")
    }

    // MARK: - Path Validation Tests

    func testDirectoryPathValidation() {
        let validPath = "~"
        let isValid = settings.validateDirectoryPath(validPath)

        XCTAssertTrue(isValid, "Home directory should be valid")
    }

    func testInvalidDirectoryPath() {
        let invalidPath = "/invalid/nonexistent/directory"
        let isValid = settings.validateDirectoryPath(invalidPath)

        XCTAssertFalse(isValid, "Nonexistent directory should return false")
    }

    // MARK: - Settings Persistence Tests

    func testSettingsPersistence() {
        // Set custom values
        settings.temperature = 1.5
        settings.maxTokens = 4096
        settings.theme = .dark
        settings.fontSize = 18.0

        // Save settings
        settings.saveSettings()

        // Load settings
        settings.loadSettings()

        // Verify persistence
        XCTAssertEqual(settings.temperature, 1.5, "Temperature should persist")
        XCTAssertEqual(settings.maxTokens, 4096, "Max tokens should persist")
        XCTAssertEqual(settings.theme, .dark, "Theme should persist")
        XCTAssertEqual(settings.fontSize, 18.0, "Font size should persist")
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        // Modify settings
        settings.temperature = 1.8
        settings.maxTokens = 8192
        settings.theme = .light

        // Reset
        settings.resetToDefaults()

        // Verify defaults
        XCTAssertEqual(settings.temperature, 0.7, "Temperature should reset to default")
        XCTAssertEqual(settings.maxTokens, 2048, "Max tokens should reset to default")
        XCTAssertEqual(settings.theme, .system, "Theme should reset to system")
    }

    // MARK: - Paths Tests

    func testDefaultPaths() {
        settings.resetToDefaults()

        XCTAssertEqual(settings.xcodeProjectsPath, "~/Desktop/xcode", "Default Xcode projects path incorrect")
        XCTAssertEqual(settings.workspacePath, "~", "Default workspace path incorrect")
        XCTAssertEqual(settings.modelsPath, "~/.mlx/models", "Default models path incorrect")
        XCTAssertEqual(settings.templatesPath, "~/Documents", "Default templates path incorrect")
        XCTAssertEqual(settings.conversationsExportPath, "~/Documents", "Default conversations path incorrect")
    }
}
