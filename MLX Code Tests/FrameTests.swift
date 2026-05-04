//
//  FrameTests.swift
//  MLX Code Tests
//
//  Frame tests: singleton initialization, service instantiation,
//  view model availability, settings persistence on launch, and
//  model/conversation default states.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class FrameTests: XCTestCase {

    // MARK: - Singleton Services Available

    func testAppSettingsSingletonAvailable() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings, "AppSettings.shared should be available")
    }

    func testToolRegistrySingletonAvailable() {
        let registry = ToolRegistry.shared
        XCTAssertNotNil(registry, "ToolRegistry.shared should be available")
    }

    func testContextManagerSingletonAvailable() {
        let manager = ContextManager.shared
        XCTAssertNotNil(manager, "ContextManager.shared should be available")
    }

    func testKeychainManagerSingletonAvailable() {
        let keychain = KeychainManager.shared
        XCTAssertNotNil(keychain, "KeychainManager.shared should be available")
    }

    func testSlashCommandHandlerSingletonAvailable() {
        let handler = SlashCommandHandler.shared
        XCTAssertNotNil(handler, "SlashCommandHandler.shared should be available")
    }

    func testConversationManagerSingletonAvailable() {
        let manager = ConversationManager.shared
        XCTAssertNotNil(manager, "ConversationManager.shared should be available")
    }

    func testSessionManagerSingletonAvailable() {
        let manager = SessionManager.shared
        XCTAssertNotNil(manager, "SessionManager.shared should be available")
    }

    func testLogManagerSingletonAvailable() {
        let manager = LogManager.shared
        XCTAssertNotNil(manager, "LogManager.shared should be available")
    }

    func testNovaAPIServerSingletonAvailable() {
        let server = NovaAPIServer.shared
        XCTAssertNotNil(server, "NovaAPIServer.shared should be available")
    }

    // MARK: - ToolRegistry Built-In Registration

    func testToolRegistryHasMinimumTools() {
        let tools = ToolRegistry.shared.getAllTools()
        XCTAssertGreaterThanOrEqual(tools.count, 10,
            "ToolRegistry should register at least 10 built-in tools on init")
    }

    func testToolRegistryCoreToolsPresent() {
        let coreTools = ["bash", "file_operations", "grep", "glob"]
        for name in coreTools {
            XCTAssertNotNil(ToolRegistry.shared.getTool(name),
                "Core tool '\(name)' must be registered at startup")
        }
    }

    func testToolRegistryDevToolsPresent() {
        let devTools = ["xcode", "error_diagnosis", "test_generation",
                        "code_navigation", "git_integration"]
        for name in devTools {
            XCTAssertNotNil(ToolRegistry.shared.getTool(name),
                "Dev tool '\(name)' must be registered at startup")
        }
    }

    func testToolRegistryAllToolsHaveNames() {
        let tools = ToolRegistry.shared.getAllTools()
        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty,
                "Every registered tool must have a non-empty name")
        }
    }

    func testToolRegistryAllToolsHaveDescriptions() {
        let tools = ToolRegistry.shared.getAllTools()
        for tool in tools {
            XCTAssertFalse(tool.description.isEmpty,
                "Tool '\(tool.name)' must have a description")
        }
    }

    // MARK: - Settings Defaults on Launch

    func testSettingsHaveReasonableDefaults() {
        let settings = AppSettings.shared
        // These defaults should exist even on first launch
        XCTAssertGreaterThan(settings.maxTokens, 0, "maxTokens should have a positive default")
        XCTAssertGreaterThanOrEqual(settings.temperature, 0.0, "temperature should be non-negative")
        XCTAssertLessThanOrEqual(settings.temperature, 2.0, "temperature should not exceed 2.0")
        XCTAssertGreaterThan(settings.fontSize, 0, "fontSize should be positive")
    }

    func testSettingsPathsNotEmpty() {
        let settings = AppSettings.shared
        XCTAssertFalse(settings.xcodeProjectsPath.isEmpty, "Xcode projects path should have a default")
        XCTAssertFalse(settings.workspacePath.isEmpty, "Workspace path should have a default")
        XCTAssertFalse(settings.modelsPath.isEmpty, "Models path should have a default")
    }

    // MARK: - View Model Instantiation

    func testChatViewModelInstantiation() {
        let vm = ChatViewModel()
        XCTAssertNotNil(vm, "ChatViewModel should be instantiable")
        XCTAssertFalse(vm.isGenerating, "New ChatViewModel should not be generating")
    }

    func testProjectViewModelAvailable() {
        let vm = ProjectViewModel.shared
        XCTAssertNotNil(vm, "ProjectViewModel.shared should be available")
    }

    func testGitHubViewModelAvailable() {
        let vm = GitHubViewModel.shared
        XCTAssertNotNil(vm, "GitHubViewModel.shared should be available")
    }

    func testCodeAnalysisViewModelAvailable() {
        let vm = CodeAnalysisViewModel.shared
        XCTAssertNotNil(vm, "CodeAnalysisViewModel.shared should be available")
    }

    // MARK: - Default Model State

    func testDefaultModelFactoryMethod() {
        let model = MLXModel.default(basePath: "/tmp/test")
        XCTAssertFalse(model.name.isEmpty, "Default model should have a name")
        XCTAssertFalse(model.path.isEmpty, "Default model should have a path")
        XCTAssertGreaterThan(model.contextWindowSize ?? 0, 0,
            "Default model should have a context window")
    }

    func testCommonModelsFactoryMethod() {
        let models = MLXModel.commonModels(basePath: "/tmp/test")
        XCTAssertGreaterThan(models.count, 3, "Should provide multiple pre-configured models")
        for model in models {
            XCTAssertTrue(model.isValid(), "All common models should be valid")
        }
    }

    // MARK: - Default Conversation State

    func testNewConversationDefaults() {
        let conv = Conversation.new()
        XCTAssertEqual(conv.title, "New Conversation")
        XCTAssertTrue(conv.isEmpty)
        XCTAssertNotNil(conv.id)
        XCTAssertNotNil(conv.createdAt)
    }

    // MARK: - Prompt Template Library Available

    func testPromptTemplateLibraryLoaded() {
        let templates = PromptTemplateLibrary.all
        XCTAssertGreaterThan(templates.count, 0,
            "Prompt template library should be populated at startup")
    }

    func testAllTemplateCategoriesCovered() {
        let categories = Set(PromptTemplateLibrary.all.map { $0.category })
        // At minimum should cover the most important categories
        XCTAssertTrue(categories.contains(.review))
        XCTAssertTrue(categories.contains(.generate))
        XCTAssertTrue(categories.contains(.debug))
        XCTAssertTrue(categories.contains(.security))
    }

    // MARK: - ContextBudget Defaults

    func testContextBudgetFallbackWorks() {
        let budget = ContextBudget.forModel(nil, daemonContextWindow: nil)
        XCTAssertGreaterThan(budget.totalBudget, 0, "Fallback budget should be positive")
        XCTAssertGreaterThan(budget.conversationBudget, 0, "Conversation budget should be positive")
    }

    // MARK: - Slash Command Catalog

    func testSlashCommandCatalogLoaded() {
        let commands = SlashCommand.allCommands
        XCTAssertGreaterThan(commands.count, 10,
            "Should have at least 10 slash commands available on startup")
    }

    // MARK: - Memory System

    func testMemorySystemAvailable() {
        let memory = MemorySystem.shared
        XCTAssertNotNil(memory, "MemorySystem.shared should be available")
    }
}
