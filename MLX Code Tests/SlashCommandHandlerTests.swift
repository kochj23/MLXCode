//
//  SlashCommandHandlerTests.swift
//  MLX Code Tests
//
//  Integration tests for SlashCommandHandler: command parsing,
//  suggestions, error handling, and command catalog completeness.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class SlashCommandHandlerTests: XCTestCase {

    private var handler: SlashCommandHandler!

    override func setUp() {
        super.setUp()
        handler = SlashCommandHandler.shared
    }

    // MARK: - Command Catalog

    func testAllCommandsHaveUniqueNames() {
        let names = SlashCommand.allCommands.map { $0.name }
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count,
            "All slash commands must have unique names")
    }

    func testAllCommandsHaveDescriptions() {
        for cmd in SlashCommand.allCommands {
            XCTAssertFalse(cmd.description.isEmpty,
                "Command /\(cmd.name) should have a description")
        }
    }

    func testAllCommandsHaveUsage() {
        for cmd in SlashCommand.allCommands {
            XCTAssertFalse(cmd.usage.isEmpty,
                "Command /\(cmd.name) should have usage text")
            XCTAssertTrue(cmd.usage.hasPrefix("/"),
                "Usage should start with /")
        }
    }

    func testCommandCategoryCoverage() {
        let categories = Set(SlashCommand.allCommands.map { $0.category })
        let expected: Set<SlashCommand.CommandCategory> = [.git, .code, .project, .ai, .system]
        for cat in expected {
            XCTAssertTrue(categories.contains(cat),
                "Category '\(cat.rawValue)' should have at least one command")
        }
    }

    func testExpectedCommandsExist() {
        let expectedNames = ["commit", "test", "help", "build", "clear", "review"]
        for name in expectedNames {
            let found = SlashCommand.allCommands.contains { $0.name == name }
            XCTAssertTrue(found, "Expected command /\(name) should exist")
        }
    }

    // MARK: - Suggestions

    func testSuggestionsWithSlashPrefix() {
        let suggestions = handler.getSuggestions(for: "/")
        XCTAssertEqual(suggestions.count, SlashCommand.allCommands.count,
            "Bare / should return all commands")
    }

    func testSuggestionsFiltering() {
        let suggestions = handler.getSuggestions(for: "/build")
        XCTAssertTrue(suggestions.contains { $0.name == "build" },
            "Typing /build should suggest the build command")
    }

    func testSuggestionsPartialMatch() {
        let suggestions = handler.getSuggestions(for: "/com")
        XCTAssertTrue(suggestions.contains { $0.name == "commit" },
            "Partial /com should match /commit")
    }

    func testSuggestionsNoMatchReturnsEmpty() {
        let suggestions = handler.getSuggestions(for: "/zzzznotacommand")
        XCTAssertTrue(suggestions.isEmpty,
            "Non-matching prefix should return empty suggestions")
    }

    func testSuggestionsWithoutSlashReturnsEmpty() {
        let suggestions = handler.getSuggestions(for: "build")
        XCTAssertTrue(suggestions.isEmpty,
            "Input without / prefix should return no suggestions")
    }

    // MARK: - Error Handling

    func testNotACommandError() async {
        do {
            _ = try await handler.execute("not a slash command")
            XCTFail("Should throw notACommand error")
        } catch let error as SlashCommandError {
            switch error {
            case .notACommand:
                break // expected
            default:
                XCTFail("Expected notACommand, got: \(error)")
            }
        } catch {
            XCTFail("Expected SlashCommandError, got: \(error)")
        }
    }

    func testUnknownCommandError() async {
        do {
            _ = try await handler.execute("/zzz_nonexistent_command")
            XCTFail("Should throw unknownCommand error")
        } catch let error as SlashCommandError {
            switch error {
            case .unknownCommand(let name):
                XCTAssertEqual(name, "zzz_nonexistent_command")
            default:
                XCTFail("Expected unknownCommand, got: \(error)")
            }
        } catch {
            XCTFail("Expected SlashCommandError, got: \(error)")
        }
    }

    // MARK: - SlashCommandError Descriptions

    func testSlashCommandErrorDescriptions() {
        let errors: [SlashCommandError] = [
            .notACommand,
            .invalidSyntax,
            .unknownCommand("zzz"),
            .missingArgument("file-path"),
            .executionFailed("timeout"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Help Command

    func testHelpCommandExecutes() async throws {
        let result = try await handler.execute("/help")
        XCTAssertTrue(result.contains("Available"), "Help output should contain command list")
        XCTAssertTrue(result.contains("/help"), "Help output should list itself")
    }

    func testHelpForSpecificCommand() async throws {
        let result = try await handler.execute("/help build")
        XCTAssertTrue(result.contains("build"), "Specific help should mention the command")
        XCTAssertTrue(result.contains("Usage"), "Specific help should include usage")
    }

    func testHelpForUnknownCommandErrors() async {
        do {
            _ = try await handler.execute("/help nonexistent")
            XCTFail("Should throw unknownCommand for help on non-existent command")
        } catch {
            // Expected
        }
    }

    // MARK: - Clear Command

    func testClearCommandExecutes() async throws {
        let result = try await handler.execute("/clear")
        XCTAssertTrue(result.lowercased().contains("clear"),
            "Clear command should confirm action")
    }
}
