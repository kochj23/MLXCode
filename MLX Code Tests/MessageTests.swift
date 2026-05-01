//
//  MessageTests.swift
//  MLX Code Tests
//
//  Unit tests for Message model: creation, validation, Codable conformance,
//  sanitization, and edge cases.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class MessageTests: XCTestCase {

    // MARK: - Creation and Defaults

    func testUserMessageCreation() {
        let msg = Message.user("Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNotNil(msg.id)
    }

    func testAssistantMessageCreation() {
        let msg = Message.assistant("Hi there")
        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.content, "Hi there")
    }

    func testSystemMessageCreation() {
        let msg = Message.system("You are helpful")
        XCTAssertEqual(msg.role, .system)
        XCTAssertEqual(msg.content, "You are helpful")
    }

    func testTimestampIsSet() {
        let before = Date()
        let msg = Message.user("test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(msg.timestamp, before)
        XCTAssertLessThanOrEqual(msg.timestamp, after)
    }

    func testUniqueIds() {
        let msg1 = Message.user("a")
        let msg2 = Message.user("b")
        XCTAssertNotEqual(msg1.id, msg2.id, "Each message should have a unique ID")
    }

    // MARK: - Validation

    func testValidMessage() {
        let msg = Message.user("Hello world")
        XCTAssertTrue(msg.isValid())
    }

    func testEmptyMessageIsInvalid() {
        let msg = Message(role: .user, content: "")
        XCTAssertFalse(msg.isValid(), "Empty content should be invalid")
    }

    func testWhitespaceOnlyMessageIsInvalid() {
        let msg = Message(role: .user, content: "   \n\t  ")
        XCTAssertFalse(msg.isValid(), "Whitespace-only content should be invalid")
    }

    func testExcessivelyLongMessageIsInvalid() {
        let longContent = String(repeating: "a", count: 1_000_001)
        let msg = Message(role: .user, content: longContent)
        XCTAssertFalse(msg.isValid(), "Content exceeding 1MB should be invalid")
    }

    func testMessageAtMaxLengthIsValid() {
        let content = String(repeating: "a", count: 1_000_000)
        let msg = Message(role: .user, content: content)
        XCTAssertTrue(msg.isValid(), "Content at exactly 1MB should be valid")
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let original = Message(
            role: .user,
            content: "Test message",
            metadata: ["key": "value"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.metadata?["key"], "value")
    }

    func testAllRolesCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for role in MessageRole.allCases {
            let msg = Message(role: role, content: "test")
            let data = try encoder.encode(msg)
            let decoded = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(decoded.role, role, "Role \(role.rawValue) should survive encoding round-trip")
        }
    }

    // MARK: - Sanitized Content

    func testSanitizedContentRedactsAPIKeys() {
        let msg = Message.user("My key is sk-abcdefghijklmnopqrstuvwxyz123456789012")
        let sanitized = msg.sanitizedContent
        XCTAssertTrue(sanitized.contains("[REDACTED]"), "API key pattern should be redacted")
        XCTAssertFalse(sanitized.contains("sk-abcdefghijklmnop"), "Raw API key should not appear")
    }

    func testSanitizedContentTruncatesLongMessages() {
        let longContent = String(repeating: "word ", count: 100)
        let msg = Message.user(longContent)
        let sanitized = msg.sanitizedContent
        XCTAssertLessThanOrEqual(sanitized.count, 203, "Sanitized content should be truncated (200 + ...)")
    }

    func testSanitizedContentShortMessageUnchangedStructure() {
        let msg = Message.user("Hello world")
        let sanitized = msg.sanitizedContent
        // Short messages without API key patterns should not be empty
        XCTAssertFalse(sanitized.isEmpty, "Short safe message should produce non-empty sanitized output")
    }

    // MARK: - MessageRole

    func testDisplayNames() {
        XCTAssertEqual(MessageRole.user.displayName, "You")
        XCTAssertEqual(MessageRole.assistant.displayName, "Assistant")
        XCTAssertEqual(MessageRole.system.displayName, "System")
    }

    func testRoleRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    // MARK: - Equatable

    func testEqualMessagesAreEqual() {
        let id = UUID()
        let date = Date()
        let msg1 = Message(id: id, role: .user, content: "test", timestamp: date)
        let msg2 = Message(id: id, role: .user, content: "test", timestamp: date)
        XCTAssertEqual(msg1, msg2)
    }

    func testDifferentIdsAreNotEqual() {
        let msg1 = Message(role: .user, content: "test")
        let msg2 = Message(role: .user, content: "test")
        XCTAssertNotEqual(msg1, msg2, "Messages with different IDs should not be equal")
    }

    // MARK: - Metadata

    func testMetadataIsOptional() {
        let msg = Message.user("test")
        XCTAssertNil(msg.metadata, "Default metadata should be nil")
    }

    func testMetadataCanBeSet() {
        let msg = Message(role: .user, content: "test", metadata: ["source": "extension"])
        XCTAssertEqual(msg.metadata?["source"], "extension")
    }
}
