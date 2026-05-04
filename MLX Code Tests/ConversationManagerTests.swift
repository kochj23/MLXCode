//
//  ConversationManagerTests.swift
//  MLX Code Tests
//
//  Integration tests for ConversationManager: conversation persistence,
//  search, branching, template creation, markdown export, and deletion.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class ConversationManagerTests: XCTestCase {

    private var manager: ConversationManager!

    override func setUp() {
        manager = ConversationManager.shared
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        let a = ConversationManager.shared
        let b = ConversationManager.shared
        XCTAssertTrue(a === b, "Should be the same object")
    }

    // MARK: - Save and Load

    func testSaveAndReloadConversation() throws {
        var conv = Conversation(title: "Test Save \(UUID().uuidString)")
        conv.addMessage(.user("Hello from test"))
        conv.addMessage(.assistant("Hi back"))

        try manager.save(conv)

        // Reload from disk
        manager.loadConversations()
        let found = manager.conversations.first { $0.id == conv.id }
        XCTAssertNotNil(found, "Saved conversation should be loadable from disk")
        XCTAssertEqual(found?.title, conv.title)
        XCTAssertEqual(found?.messageCount, 2)

        // Cleanup
        try? manager.delete(conv)
    }

    func testDeleteConversation() throws {
        let conv = Conversation(title: "Delete Me \(UUID().uuidString)")
        try manager.save(conv)
        manager.loadConversations()

        let existsBefore = manager.conversations.contains { $0.id == conv.id }
        XCTAssertTrue(existsBefore, "Conversation should exist after save")

        try manager.delete(conv)
        let existsAfter = manager.conversations.contains { $0.id == conv.id }
        XCTAssertFalse(existsAfter, "Conversation should be gone after delete")
    }

    // MARK: - Search

    func testSearchByTitle() throws {
        let uniqueTag = UUID().uuidString
        var conv = Conversation(title: "SearchTest-\(uniqueTag)")
        conv.addMessage(.user("Generic message"))
        try manager.save(conv)
        manager.loadConversations()

        manager.search(uniqueTag)
        XCTAssertTrue(manager.searchResults.contains { $0.id == conv.id },
            "Search should find conversation by title")

        // Cleanup
        manager.clearSearch()
        try? manager.delete(conv)
    }

    func testSearchByMessageContent() throws {
        let uniqueTag = UUID().uuidString
        var conv = Conversation(title: "MessageSearchTest")
        conv.addMessage(.user("special-keyword-\(uniqueTag)"))
        try manager.save(conv)
        manager.loadConversations()

        manager.search(uniqueTag)
        XCTAssertTrue(manager.searchResults.contains { $0.id == conv.id },
            "Search should find conversation by message content")

        // Cleanup
        manager.clearSearch()
        try? manager.delete(conv)
    }

    func testSearchNoResults() {
        manager.search("zzzz_no_conversation_has_this_text_\(UUID().uuidString)")
        XCTAssertTrue(manager.searchResults.isEmpty, "Search with no match should return empty")
    }

    func testClearSearch() {
        manager.search("test")
        manager.clearSearch()
        XCTAssertTrue(manager.searchResults.isEmpty, "clearSearch should empty results")
    }

    // MARK: - Branching

    func testCreateBranch() {
        var conv = Conversation(title: "Original")
        let msg1 = Message.user("First message")
        let msg2 = Message.assistant("First reply")
        let msg3 = Message.user("Second message")
        let msg4 = Message.assistant("Second reply")
        conv.addMessage(msg1)
        conv.addMessage(msg2)
        conv.addMessage(msg3)
        conv.addMessage(msg4)

        // Branch from msg2 (second message)
        let branch = manager.createBranch(from: conv, fromMessage: msg2)
        XCTAssertEqual(branch.messageCount, 2,
            "Branch should contain messages up to and including the branch point")
        XCTAssertEqual(branch.messages.last?.content, msg2.content)
        XCTAssertTrue(branch.title.contains("Branch"))
    }

    func testBranchFromFirstMessage() {
        var conv = Conversation(title: "Original")
        let msg1 = Message.user("Only message")
        conv.addMessage(msg1)
        conv.addMessage(.assistant("Reply"))

        let branch = manager.createBranch(from: conv, fromMessage: msg1)
        XCTAssertEqual(branch.messageCount, 1,
            "Branching from first message should include only that message")
    }

    func testBranchFromNonexistentMessage() {
        var conv = Conversation(title: "Original")
        conv.addMessage(.user("Hello"))

        let fakeMessage = Message.user("Not in conversation")
        let branch = manager.createBranch(from: conv, fromMessage: fakeMessage)
        XCTAssertEqual(branch.id, conv.id,
            "Branching from non-existent message should return original conversation")
    }

    // MARK: - Templates

    func testSaveAndLoadTemplate() throws {
        var conv = Conversation(title: "Template Source")
        conv.addMessage(.user("Template prompt"))
        conv.addMessage(.assistant("Template response"))

        let templateName = "Test Template \(UUID().uuidString)"
        try manager.saveAsTemplate(conv, name: templateName, description: "A test template")

        manager.loadTemplates()
        let found = manager.templates.first { $0.name == templateName }
        XCTAssertNotNil(found, "Template should be loadable after saving")
        XCTAssertEqual(found?.messages.count, 2)

        // Cleanup
        if let template = found {
            try? manager.deleteTemplate(template)
        }
    }

    func testCreateFromTemplate() throws {
        var conv = Conversation(title: "Source")
        conv.addMessage(.user("Starting prompt"))

        let templateName = "FromTemplate \(UUID().uuidString)"
        try manager.saveAsTemplate(conv, name: templateName, description: "Test")
        manager.loadTemplates()

        guard let template = manager.templates.first(where: { $0.name == templateName }) else {
            XCTFail("Template should exist")
            return
        }

        let newConv = manager.createFromTemplate(template)
        XCTAssertEqual(newConv.title, templateName)
        XCTAssertEqual(newConv.messageCount, 1)
        XCTAssertEqual(newConv.messages.first?.content, "Starting prompt")
        XCTAssertNotEqual(newConv.id, conv.id, "New conversation should have a different ID")

        // Cleanup
        try? manager.deleteTemplate(template)
    }

    func testDeleteTemplate() throws {
        var conv = Conversation(title: "ToDelete")
        conv.addMessage(.user("Prompt"))

        let name = "DeleteMe \(UUID().uuidString)"
        try manager.saveAsTemplate(conv, name: name, description: "Will delete")
        manager.loadTemplates()

        guard let template = manager.templates.first(where: { $0.name == name }) else {
            XCTFail("Template should exist before deletion")
            return
        }

        try manager.deleteTemplate(template)
        manager.loadTemplates()

        let stillExists = manager.templates.contains { $0.name == name }
        XCTAssertFalse(stillExists, "Template should be gone after deletion")
    }

    // MARK: - Markdown Export

    func testExportAsMarkdown() throws {
        var conv = Conversation(title: "Export Test")
        conv.addMessage(.user("Question about Swift"))
        conv.addMessage(.assistant("Here is the answer..."))

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-test-\(UUID().uuidString).md")

        try manager.exportAsMarkdown(conv, to: tempFile)

        let content = try String(contentsOf: tempFile, encoding: .utf8)
        XCTAssertTrue(content.contains("# Export Test"), "Markdown should contain title")
        XCTAssertTrue(content.contains("User"), "Markdown should contain User role")
        XCTAssertTrue(content.contains("Assistant"), "Markdown should contain Assistant role")
        XCTAssertTrue(content.contains("Question about Swift"))
        XCTAssertTrue(content.contains("Here is the answer..."))

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    // MARK: - ConversationTemplate Codable

    func testConversationTemplateCodableRoundTrip() throws {
        let template = ConversationTemplate(
            name: "Codable Template",
            description: "Testing Codable",
            messages: [
                Message.user("Hello"),
                Message.assistant("Hi there")
            ]
        )

        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(ConversationTemplate.self, from: data)

        XCTAssertEqual(decoded.id, template.id)
        XCTAssertEqual(decoded.name, template.name)
        XCTAssertEqual(decoded.description, template.description)
        XCTAssertEqual(decoded.messages.count, template.messages.count)
    }
}
