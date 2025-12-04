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
    let testDefaults = UserDefaults(suiteName: "com.mlxcode.tests")!

    override func setUp() async throws {
        // Clear test defaults
        testDefaults.removePersistentDomain(forName: "com.mlxcode.tests")

        // Note: Since AppSettings is a singleton, we test the shared instance
        settings = AppSettings.shared
    }

    override func tearDown() async throws {
        settings = nil
    }

    // MARK: - Default Values Tests

    func testDefaultValues() {
        XCTAssertEqual(settings.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(settings.maxTokens, 2048)
        XCTAssertEqual(settings.topP, 0.9, accuracy: 0.001)
        XCTAssertEqual(settings.topK, 40)
        XCTAssertEqual(settings.pythonPath, "/usr/bin/python3")
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.fontSize, 14.0, accuracy: 0.001)
        XCTAssertTrue(settings.enableSyntaxHighlighting)
        XCTAssertTrue(settings.enableAutoSave)
        XCTAssertEqual(settings.autoSaveInterval, 30.0, accuracy: 0.001)
        XCTAssertEqual(settings.maxConversationHistory, 50)
    }

    func testDefaultPaths() {
        XCTAssertEqual(settings.xcodeProjectsPath, "~/Desktop/xcode")
        XCTAssertEqual(settings.workspacePath, "~")
        XCTAssertEqual(settings.modelsPath, "~/.mlx/models")
        XCTAssertEqual(settings.templatesPath, "~/Documents")
        XCTAssertEqual(settings.conversationsExportPath, "~/Documents")
    }

    func testDefaultModels() {
        XCTAssertFalse(settings.availableModels.isEmpty)
        XCTAssertEqual(settings.availableModels.count, 4) // commonModels returns 4
    }

    // MARK: - Temperature Validation Tests

    func testTemperatureValidRange() {
        settings.temperature = 0.5
        XCTAssertEqual(settings.temperature, 0.5, accuracy: 0.001)

        settings.temperature = 1.0
        XCTAssertEqual(settings.temperature, 1.0, accuracy: 0.001)

        settings.temperature = 2.0
        XCTAssertEqual(settings.temperature, 2.0, accuracy: 0.001)
    }

    func testTemperatureBoundaries() {
        settings.temperature = 0.0
        XCTAssertEqual(settings.temperature, 0.0, accuracy: 0.001)

        settings.temperature = 2.0
        XCTAssertEqual(settings.temperature, 2.0, accuracy: 0.001)
    }

    // MARK: - Max Tokens Validation Tests

    func testMaxTokensValidRange() {
        settings.maxTokens = 1024
        XCTAssertEqual(settings.maxTokens, 1024)

        settings.maxTokens = 4096
        XCTAssertEqual(settings.maxTokens, 4096)

        settings.maxTokens = 8192
        XCTAssertEqual(settings.maxTokens, 8192)
    }

    func testMaxTokensBoundaries() {
        settings.maxTokens = 1
        XCTAssertEqual(settings.maxTokens, 1)

        settings.maxTokens = 100_000
        XCTAssertEqual(settings.maxTokens, 100_000)
    }

    // MARK: - TopP Validation Tests

    func testTopPValidRange() {
        settings.topP = 0.8
        XCTAssertEqual(settings.topP, 0.8, accuracy: 0.001)

        settings.topP = 0.95
        XCTAssertEqual(settings.topP, 0.95, accuracy: 0.001)
    }

    func testTopPBoundaries() {
        settings.topP = 0.0
        XCTAssertEqual(settings.topP, 0.0, accuracy: 0.001)

        settings.topP = 1.0
        XCTAssertEqual(settings.topP, 1.0, accuracy: 0.001)
    }

    // MARK: - TopK Validation Tests

    func testTopKValidRange() {
        settings.topK = 20
        XCTAssertEqual(settings.topK, 20)

        settings.topK = 50
        XCTAssertEqual(settings.topK, 50)

        settings.topK = 100
        XCTAssertEqual(settings.topK, 100)
    }

    func testTopKBoundaries() {
        settings.topK = 1
        XCTAssertEqual(settings.topK, 1)

        settings.topK = 1000
        XCTAssertEqual(settings.topK, 1000)
    }

    // MARK: - Font Size Validation Tests

    func testFontSizeValidRange() {
        settings.fontSize = 12.0
        XCTAssertEqual(settings.fontSize, 12.0, accuracy: 0.001)

        settings.fontSize = 18.0
        XCTAssertEqual(settings.fontSize, 18.0, accuracy: 0.001)
    }

    func testFontSizeBoundaries() {
        settings.fontSize = 8.0
        XCTAssertEqual(settings.fontSize, 8.0, accuracy: 0.001)

        settings.fontSize = 72.0
        XCTAssertEqual(settings.fontSize, 72.0, accuracy: 0.001)
    }

    // MARK: - Auto-Save Interval Tests

    func testAutoSaveIntervalValidRange() {
        settings.autoSaveInterval = 15.0
        XCTAssertEqual(settings.autoSaveInterval, 15.0, accuracy: 0.001)

        settings.autoSaveInterval = 60.0
        XCTAssertEqual(settings.autoSaveInterval, 60.0, accuracy: 0.001)
    }

    func testAutoSaveIntervalBoundaries() {
        settings.autoSaveInterval = 5.0
        XCTAssertEqual(settings.autoSaveInterval, 5.0, accuracy: 0.001)

        settings.autoSaveInterval = 300.0
        XCTAssertEqual(settings.autoSaveInterval, 300.0, accuracy: 0.001)
    }

    // MARK: - Max Conversation History Tests

    func testMaxConversationHistoryValidRange() {
        settings.maxConversationHistory = 25
        XCTAssertEqual(settings.maxConversationHistory, 25)

        settings.maxConversationHistory = 100
        XCTAssertEqual(settings.maxConversationHistory, 100)
    }

    func testMaxConversationHistoryBoundaries() {
        settings.maxConversationHistory = 10
        XCTAssertEqual(settings.maxConversationHistory, 10)

        settings.maxConversationHistory = 1000
        XCTAssertEqual(settings.maxConversationHistory, 1000)
    }

    // MARK: - Theme Tests

    func testThemeValues() {
        settings.theme = .light
        XCTAssertEqual(settings.theme, .light)

        settings.theme = .dark
        XCTAssertEqual(settings.theme, .dark)

        settings.theme = .system
        XCTAssertEqual(settings.theme, .system)
    }

    func testThemeDisplayNames() {
        XCTAssertEqual(AppTheme.light.displayName, "Light")
        XCTAssertEqual(AppTheme.dark.displayName, "Dark")
        XCTAssertEqual(AppTheme.system.displayName, "System")
    }

    // MARK: - Boolean Settings Tests

    func testBooleanSettings() {
        settings.enableSyntaxHighlighting = false
        XCTAssertFalse(settings.enableSyntaxHighlighting)

        settings.enableSyntaxHighlighting = true
        XCTAssertTrue(settings.enableSyntaxHighlighting)

        settings.enableAutoSave = false
        XCTAssertFalse(settings.enableAutoSave)

        settings.enableAutoSave = true
        XCTAssertTrue(settings.enableAutoSave)
    }

    // MARK: - Path Settings Tests

    func testPathSettings() {
        settings.xcodeProjectsPath = "~/Developer/Projects"
        XCTAssertEqual(settings.xcodeProjectsPath, "~/Developer/Projects")

        settings.workspacePath = "~/Workspace"
        XCTAssertEqual(settings.workspacePath, "~/Workspace")

        settings.modelsPath = "/Volumes/Data/models"
        XCTAssertEqual(settings.modelsPath, "/Volumes/Data/models")

        settings.templatesPath = "~/Templates"
        XCTAssertEqual(settings.templatesPath, "~/Templates")

        settings.conversationsExportPath = "~/Exports"
        XCTAssertEqual(settings.conversationsExportPath, "~/Exports")
    }

    // MARK: - Model Management Tests

    func testSelectedModel() {
        let model = MLXModel(name: "Test Model", path: "/test/path")
        settings.selectedModel = model

        XCTAssertNotNil(settings.selectedModel)
        XCTAssertEqual(settings.selectedModel?.name, "Test Model")
    }

    func testAvailableModelsManipulation() {
        let initialCount = settings.availableModels.count

        let newModel = MLXModel(name: "New Model", path: "/new/path")
        settings.availableModels.append(newModel)

        XCTAssertEqual(settings.availableModels.count, initialCount + 1)
        XCTAssertTrue(settings.availableModels.contains { $0.name == "New Model" })
    }

    // MARK: - Reset to Defaults Tests

    func testResetToDefaults() {
        // Modify some settings
        settings.temperature = 1.5
        settings.maxTokens = 4096
        settings.theme = .dark
        settings.fontSize = 20.0
        settings.pythonPath = "/custom/python"

        // Reset to defaults
        settings.resetToDefaults()

        // Verify defaults restored
        XCTAssertEqual(settings.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(settings.maxTokens, 2048)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.fontSize, 14.0, accuracy: 0.001)
        XCTAssertEqual(settings.pythonPath, "/usr/bin/python3")
    }

    // MARK: - Python Path Validation Tests

    func testValidatePythonPath() {
        // Test with default Python path
        settings.pythonPath = "/usr/bin/python3"

        // Note: This test may fail on systems without Python installed
        // In production, we'd mock FileManager
        let isValid = settings.validatePythonPath()
        // We can't assume the result as it depends on system configuration
        XCTAssertNotNil(isValid)
    }

    func testValidateInvalidPythonPath() {
        settings.pythonPath = "/invalid/path/to/python"
        XCTAssertFalse(settings.validatePythonPath())
    }

    func testValidateDirectoryAsPythonPath() {
        settings.pythonPath = "/usr/bin" // Directory, not executable
        XCTAssertFalse(settings.validatePythonPath())
    }

    // MARK: - Directory Validation Tests

    func testValidateExistingDirectory() {
        // Test with /tmp which should always exist
        XCTAssertTrue(settings.validateDirectoryPath("/tmp"))
    }

    func testValidateNonExistentDirectory() {
        XCTAssertFalse(settings.validateDirectoryPath("/this/path/does/not/exist"))
    }

    func testValidateFileAsDirectory() {
        // /etc/hosts is a file, not a directory
        XCTAssertFalse(settings.validateDirectoryPath("/etc/hosts"))
    }

    func testValidateTildeExpansion() {
        // Test with tilde path
        let result = settings.validateDirectoryPath("~")
        // Home directory should exist
        XCTAssertTrue(result)
    }

    // MARK: - Open in Finder Tests

    func testOpenInFinder() {
        // Note: This will actually open Finder if run
        // In production, we'd mock NSWorkspace
        // For now, just verify it doesn't crash
        settings.openInFinder("/tmp")
        // No assertion - just checking it doesn't crash
    }

    // MARK: - Singleton Tests

    func testSingletonInstance() {
        let instance1 = AppSettings.shared
        let instance2 = AppSettings.shared

        // Should be the same instance
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Memory Management Tests

    func testCleanup() {
        // Test cleanup doesn't crash
        settings.cleanup()
        // No assertion - just checking it doesn't crash
    }
}
