//
//  ConversationTests.swift
//  MLX Code Tests
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import XCTest
@testable import MLX_Code

/// Unit tests for Conversation and Message models
final class ConversationTests: XCTestCase {

    // MARK: - Message Tests

    func testMessageUserCreation() {
        let message = Message.user("Hello, world!")

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello, world!")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func testMessageAssistantCreation() {
        let message = Message.assistant("Hi there!")

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hi there!")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func testMessageSystemCreation() {
        let message = Message.system("You are a helpful assistant")

        XCTAssertEqual(message.role, .system)
        XCTAssertEqual(message.content, "You are a helpful assistant")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func testMessageEquality() {
        let id = UUID()
        let date = Date()

        let message1 = Message(id: id, role: .user, content: "Test", timestamp: date)
        let message2 = Message(id: id, role: .user, content: "Test", timestamp: date)
        let message3 = Message(id: UUID(), role: .user, content: "Test", timestamp: date)

        XCTAssertEqual(message1, message2) // Same ID
        XCTAssertNotEqual(message1, message3) // Different ID
    }

    func testMessageCodable() throws {
        let originalMessage = Message.user("Test message")

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMessage)

        // Decode
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decodedMessage.id, originalMessage.id)
        XCTAssertEqual(decodedMessage.role, originalMessage.role)
        XCTAssertEqual(decodedMessage.content, originalMessage.content)
    }

    // MARK: - Conversation Tests

    func testConversationInitialization() {
        let conversation = Conversation(title: "Test Conversation")

        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertNotNil(conversation.id)
        XCTAssertNotNil(conversation.createdAt)
        XCTAssertNotNil(conversation.lastActivity)
    }

    func testConversationNewFactory() {
        let conversation = Conversation.new(withFirstMessage: "Hello")

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages[0].role, .user)
        XCTAssertEqual(conversation.messages[0].content, "Hello")
        XCTAssertTrue(conversation.title.hasPrefix("Conversation"))
    }

    func testConversationAddMessage() {
        var conversation = Conversation(title: "Test")

        let userMessage = Message.user("User message")
        conversation.addMessage(userMessage)

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages[0].id, userMessage.id)

        let assistantMessage = Message.assistant("Assistant response")
        conversation.addMessage(assistantMessage)

        XCTAssertEqual(conversation.messages.count, 2)
        XCTAssertEqual(conversation.messages[1].id, assistantMessage.id)
    }

    func testConversationRemoveMessage() {
        var conversation = Conversation(title: "Test")

        let message1 = Message.user("Message 1")
        let message2 = Message.user("Message 2")
        let message3 = Message.user("Message 3")

        conversation.addMessage(message1)
        conversation.addMessage(message2)
        conversation.addMessage(message3)

        XCTAssertEqual(conversation.messages.count, 3)

        conversation.removeMessage(withId: message2.id)

        XCTAssertEqual(conversation.messages.count, 2)
        XCTAssertEqual(conversation.messages[0].id, message1.id)
        XCTAssertEqual(conversation.messages[1].id, message3.id)
    }

    func testConversationClearMessages() {
        var conversation = Conversation(title: "Test")

        conversation.addMessage(Message.user("Message 1"))
        conversation.addMessage(Message.user("Message 2"))

        XCTAssertEqual(conversation.messages.count, 2)

        conversation.clearMessages()

        XCTAssertTrue(conversation.messages.isEmpty)
    }

    func testConversationIsEmpty() {
        var conversation = Conversation(title: "Test")

        XCTAssertTrue(conversation.isEmpty)

        conversation.addMessage(Message.user("Test"))

        XCTAssertFalse(conversation.isEmpty)
    }

    func testConversationMessageCount() {
        var conversation = Conversation(title: "Test")

        XCTAssertEqual(conversation.messageCount, 0)

        conversation.addMessage(Message.user("Message 1"))
        XCTAssertEqual(conversation.messageCount, 1)

        conversation.addMessage(Message.assistant("Message 2"))
        XCTAssertEqual(conversation.messageCount, 2)
    }

    func testConversationLastMessagePreview() {
        var conversation = Conversation(title: "Test")

        XCTAssertEqual(conversation.lastMessagePreview, "No messages yet")

        conversation.addMessage(Message.user("First message"))
        XCTAssertEqual(conversation.lastMessagePreview, "First message")

        conversation.addMessage(Message.assistant("Second message"))
        XCTAssertEqual(conversation.lastMessagePreview, "Second message")

        // Test truncation
        let longMessage = String(repeating: "a", count: 200)
        conversation.addMessage(Message.user(longMessage))
        XCTAssertTrue(conversation.lastMessagePreview.count <= 103) // 100 + "..."
        XCTAssertTrue(conversation.lastMessagePreview.hasSuffix("..."))
    }

    func testConversationValidation() {
        // Valid conversation
        var validConv = Conversation(title: "Valid")
        validConv.addMessage(Message.user("Test"))
        XCTAssertTrue(validConv.isValid())

        // Invalid - empty title
        let invalidTitle = Conversation(title: "   ")
        XCTAssertFalse(invalidTitle.isValid())

        // Invalid - too many messages
        var tooManyMessages = Conversation(title: "Test")
        for i in 0..<10001 {
            tooManyMessages.addMessage(Message.user("Message \(i)"))
        }
        XCTAssertFalse(tooManyMessages.isValid())
    }

    func testConversationCodable() throws {
        var originalConversation = Conversation(title: "Test Conversation")
        originalConversation.addMessage(Message.user("User message"))
        originalConversation.addMessage(Message.assistant("Assistant response"))

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConversation)

        // Decode
        let decoder = JSONDecoder()
        let decodedConversation = try decoder.decode(Conversation.self, from: data)

        XCTAssertEqual(decodedConversation.id, originalConversation.id)
        XCTAssertEqual(decodedConversation.title, originalConversation.title)
        XCTAssertEqual(decodedConversation.messages.count, originalConversation.messages.count)
        XCTAssertEqual(decodedConversation.messages[0].content, "User message")
        XCTAssertEqual(decodedConversation.messages[1].content, "Assistant response")
    }

    func testConversationJSONData() {
        var conversation = Conversation(title: "Test")
        conversation.addMessage(Message.user("Test message"))

        // Export to JSON
        let jsonData = conversation.toJSONData()
        XCTAssertNotNil(jsonData)

        // Import from JSON
        let importedConversation = Conversation.fromJSONData(jsonData!)
        XCTAssertNotNil(importedConversation)
        XCTAssertEqual(importedConversation?.title, conversation.title)
        XCTAssertEqual(importedConversation?.messages.count, conversation.messages.count)
    }

    func testConversationLastActivityUpdate() throws {
        var conversation = Conversation(title: "Test")

        let initialActivity = conversation.lastActivity

        // Wait a bit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        conversation.addMessage(Message.user("New message"))

        XCTAssertGreaterThan(conversation.lastActivity, initialActivity)
    }

    func testConversationEquality() {
        let id = UUID()

        var conversation1 = Conversation(id: id, title: "Test", messages: [], createdAt: Date(), lastActivity: Date())
        var conversation2 = Conversation(id: id, title: "Test", messages: [], createdAt: Date(), lastActivity: Date())
        var conversation3 = Conversation(id: UUID(), title: "Test", messages: [], createdAt: Date(), lastActivity: Date())

        conversation1.addMessage(Message.user("Test"))
        conversation2.addMessage(Message.user("Test"))

        XCTAssertEqual(conversation1, conversation2) // Same ID
        XCTAssertNotEqual(conversation1, conversation3) // Different ID
    }

    // MARK: - MessageRole Tests

    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.system.rawValue, "system")
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
    }

    func testMessageRoleCodable() throws {
        let roles: [MessageRole] = [.system, .user, .assistant]

        for role in roles {
            let encoder = JSONEncoder()
            let data = try encoder.encode(role)

            let decoder = JSONDecoder()
            let decodedRole = try decoder.decode(MessageRole.self, from: data)

            XCTAssertEqual(role, decodedRole)
        }
    }
}
