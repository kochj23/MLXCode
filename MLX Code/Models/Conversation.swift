//
//  Conversation.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents a conversation thread with multiple messages
/// Conforms to Codable for persistence and Identifiable for SwiftUI lists
struct Conversation: Identifiable, Codable, Equatable {
    /// Unique identifier for the conversation
    let id: UUID

    /// Title of the conversation
    var title: String

    /// Array of messages in the conversation
    var messages: [Message]

    /// Date when the conversation was created
    let createdAt: Date

    /// Date when the conversation was last updated
    var updatedAt: Date

    /// Optional tags for categorizing conversations
    var tags: [String]?

    /// Initializes a new conversation
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - title: Title of the conversation
    ///   - messages: Initial messages (defaults to empty array)
    ///   - createdAt: Creation date (defaults to current date)
    ///   - updatedAt: Last update date (defaults to current date)
    ///   - tags: Optional tags for categorization
    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }
}

// MARK: - Computed Properties

extension Conversation {
    /// Returns a preview of the last message for display in conversation lists
    var lastMessagePreview: String {
        guard let lastMessage = messages.last else {
            return "No messages"
        }

        let preview = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Truncate to 100 characters
        if preview.count > 100 {
            return String(preview.prefix(100)) + "..."
        }

        return preview
    }

    /// Returns the number of messages in the conversation
    var messageCount: Int {
        messages.count
    }

    /// Returns true if the conversation has no messages
    var isEmpty: Bool {
        messages.isEmpty
    }

    /// Returns the last message timestamp, or creation date if no messages
    var lastActivity: Date {
        messages.last?.timestamp ?? createdAt
    }
}

// MARK: - Message Management

extension Conversation {
    /// Adds a new message to the conversation
    /// - Parameter message: The message to add
    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }

    /// Removes a message from the conversation
    /// - Parameter messageId: The ID of the message to remove
    mutating func removeMessage(withId messageId: UUID) {
        messages.removeAll { $0.id == messageId }
        updatedAt = Date()
    }

    /// Updates a message in the conversation
    /// - Parameters:
    ///   - messageId: The ID of the message to update
    ///   - content: The new content for the message
    mutating func updateMessage(withId messageId: UUID, content: String) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].content = content
            updatedAt = Date()
        }
    }

    /// Clears all messages from the conversation
    mutating func clearMessages() {
        messages.removeAll()
        updatedAt = Date()
    }
}

// MARK: - Factory Methods

extension Conversation {
    /// Creates a new conversation with a default title
    /// - Parameter firstMessage: Optional first message to include
    /// - Returns: A new Conversation instance
    static func new(withFirstMessage firstMessage: String? = nil) -> Conversation {
        var conversation = Conversation(title: "New Conversation")

        if let message = firstMessage {
            conversation.addMessage(.user(message))
        }

        return conversation
    }

    /// Creates a conversation with an auto-generated title based on first message
    /// - Parameter messages: Initial messages
    /// - Returns: A new Conversation instance
    static func withAutoTitle(messages: [Message]) -> Conversation {
        var title: String
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let preview = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            title = String(preview.prefix(50))
            if preview.count > 50 {
                title = title + "..."
            }
        } else {
            title = "New Conversation"
        }

        return Conversation(title: title, messages: messages)
    }
}

// MARK: - Validation

extension Conversation {
    /// Validates the conversation
    /// - Returns: True if the conversation is valid
    func isValid() -> Bool {
        // Title should not be empty
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // All messages should be valid
        for message in messages {
            guard message.isValid() else {
                return false
            }
        }

        return true
    }
}

// MARK: - Export/Import

extension Conversation {
    /// Exports the conversation to JSON data
    /// - Returns: JSON data representation or nil if encoding fails
    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(self)
    }

    /// Imports a conversation from JSON data
    /// - Parameter data: JSON data to decode
    /// - Returns: A Conversation instance or nil if decoding fails
    static func fromJSONData(_ data: Data) -> Conversation? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(Conversation.self, from: data)
    }
}
