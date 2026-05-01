//
//  ConversationTests.swift
//  MLX Code Tests
//
//  Unit tests for Conversation model: creation, message management,
//  validation, Codable round-trip, and factory methods.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class ConversationTests: XCTestCase {

    // MARK: - Creation

    func testNewConversation() {
        let conv = Conversation(title: "Test")
        XCTAssertEqual(conv.title, "Test")
        XCTAssertTrue(conv.messages.isEmpty)
        XCTAssertNotNil(conv.id)
    }

    func testFactoryNewConversation() {
        let conv = Conversation.new()
        XCTAssertEqual(conv.title, "New Conversation")
        XCTAssertTrue(conv.isEmpty)
    }

    func testFactoryNewWithFirstMessage() {
        let conv = Conversation.new(withFirstMessage: "Hello")
        XCTAssertEqual(conv.messageCount, 1)
        XCTAssertEqual(conv.messages.first?.content, "Hello")
        XCTAssertEqual(conv.messages.first?.role, .user)
    }

    func testAutoTitleFromFirstUserMessage() {
        let messages = [Message.user("Write a SwiftUI view for user profiles")]
        let conv = Conversation.withAutoTitle(messages: messages)
        XCTAssertTrue(conv.title.contains("SwiftUI"), "Auto-title should derive from first user message")
    }

    func testAutoTitleTruncatesLongMessages() {
        let longMessage = String(repeating: "a", count: 100)
        let messages = [Message.user(longMessage)]
        let conv = Conversation.withAutoTitle(messages: messages)
        XCTAssertLessThanOrEqual(conv.title.count, 53, "Auto-title should truncate to ~50 chars + ...")
    }

    func testAutoTitleDefaultsWhenNoUserMessage() {
        let messages = [Message.system("System prompt")]
        let conv = Conversation.withAutoTitle(messages: messages)
        XCTAssertEqual(conv.title, "New Conversation")
    }

    // MARK: - Message Management

    func testAddMessage() {
        var conv = Conversation(title: "Test")
        conv.addMessage(.user("Hello"))
        XCTAssertEqual(conv.messageCount, 1)
        XCTAssertFalse(conv.isEmpty)
    }

    func testRemoveMessage() {
        var conv = Conversation(title: "Test")
        let msg = Message.user("To be removed")
        conv.addMessage(msg)
        XCTAssertEqual(conv.messageCount, 1)

        conv.removeMessage(withId: msg.id)
        XCTAssertEqual(conv.messageCount, 0)
    }

    func testRemoveNonexistentMessageDoesNothing() {
        var conv = Conversation(title: "Test")
        conv.addMessage(.user("Keep"))
        conv.removeMessage(withId: UUID()) // Random UUID
        XCTAssertEqual(conv.messageCount, 1, "Removing non-existent message should not affect count")
    }

    func testUpdateMessage() {
        var conv = Conversation(title: "Test")
        let msg = Message.user("Original")
        conv.addMessage(msg)

        conv.updateMessage(withId: msg.id, content: "Updated")
        XCTAssertEqual(conv.messages.first?.content, "Updated")
    }

    func testClearMessages() {
        var conv = Conversation(title: "Test")
        conv.addMessage(.user("One"))
        conv.addMessage(.assistant("Two"))
        conv.clearMessages()
        XCTAssertTrue(conv.isEmpty)
        XCTAssertEqual(conv.messageCount, 0)
    }

    // MARK: - Computed Properties

    func testLastMessagePreview() {
        var conv = Conversation(title: "Test")
        XCTAssertEqual(conv.lastMessagePreview, "No messages")

        conv.addMessage(.user("Hello there"))
        XCTAssertEqual(conv.lastMessagePreview, "Hello there")
    }

    func testLastMessagePreviewTruncates() {
        var conv = Conversation(title: "Test")
        let longContent = String(repeating: "word ", count: 50)
        conv.addMessage(.user(longContent))
        XCTAssertLessThanOrEqual(conv.lastMessagePreview.count, 103) // 100 + "..."
    }

    func testLastActivity() {
        let conv = Conversation(title: "Test")
        XCTAssertEqual(conv.lastActivity, conv.createdAt, "No messages = lastActivity is createdAt")
    }

    func testLastActivityWithMessages() {
        var conv = Conversation(title: "Test")
        let msg = Message.user("Latest")
        conv.addMessage(msg)
        XCTAssertEqual(conv.lastActivity, msg.timestamp)
    }

    // MARK: - Validation

    func testValidConversation() {
        var conv = Conversation(title: "Test")
        conv.addMessage(.user("Hello"))
        XCTAssertTrue(conv.isValid())
    }

    func testEmptyTitleIsInvalid() {
        let conv = Conversation(title: "")
        XCTAssertFalse(conv.isValid(), "Empty title should be invalid")
    }

    func testWhitespaceTitleIsInvalid() {
        let conv = Conversation(title: "   ")
        XCTAssertFalse(conv.isValid(), "Whitespace-only title should be invalid")
    }

    func testConversationWithInvalidMessageIsInvalid() {
        var conv = Conversation(title: "Test")
        conv.messages.append(Message(role: .user, content: ""))
        XCTAssertFalse(conv.isValid(), "Conversation with invalid message should be invalid")
    }

    // MARK: - Codable Round-Trip (JSON Export/Import)

    func testJSONExportImport() {
        var conv = Conversation(title: "Exported")
        conv.addMessage(.user("Hello"))
        conv.addMessage(.assistant("Hi!"))

        guard let data = conv.toJSONData() else {
            XCTFail("JSON export should not return nil")
            return
        }

        guard let imported = Conversation.fromJSONData(data) else {
            XCTFail("JSON import should not return nil")
            return
        }

        XCTAssertEqual(imported.id, conv.id)
        XCTAssertEqual(imported.title, conv.title)
        XCTAssertEqual(imported.messageCount, conv.messageCount)
        XCTAssertEqual(imported.messages.first?.content, "Hello")
    }

    func testInvalidJSONReturnsNil() {
        let badData = "not json".data(using: .utf8)!
        XCTAssertNil(Conversation.fromJSONData(badData))
    }

    // MARK: - Tags

    func testTagsAreOptional() {
        let conv = Conversation(title: "Test")
        XCTAssertNil(conv.tags)
    }

    func testTagsCanBeSet() {
        let conv = Conversation(title: "Test", tags: ["swift", "refactor"])
        XCTAssertEqual(conv.tags?.count, 2)
        XCTAssertTrue(conv.tags?.contains("swift") ?? false)
    }

    // MARK: - updatedAt

    func testAddMessageUpdatesTimestamp() {
        var conv = Conversation(title: "Test")
        let originalUpdate = conv.updatedAt

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)
        conv.addMessage(.user("New"))
        XCTAssertGreaterThan(conv.updatedAt, originalUpdate, "updatedAt should advance after adding a message")
    }
}
