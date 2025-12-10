//
//  Message.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents a chat message in the conversation
/// Conforms to Codable for persistence and Identifiable for SwiftUI lists
struct Message: Identifiable, Codable, Equatable {
    /// Unique identifier for the message
    let id: UUID

    /// Role of the message sender
    let role: MessageRole

    /// Content of the message
    var content: String

    /// Timestamp when the message was created
    let timestamp: Date

    /// Optional metadata for the message
    var metadata: [String: String]?

    /// Initializes a new message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - role: Role of the message sender
    ///   - content: Content of the message
    ///   - timestamp: Timestamp (defaults to current date)
    ///   - metadata: Optional metadata dictionary
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Returns a sanitized version of the message content for logging
    /// Removes any potentially sensitive information
    var sanitizedContent: String {
        var sanitized = content

        // Remove potential API keys (pattern: alphanumeric strings with specific prefixes)
        let apiKeyPatterns = [
            "sk-[a-zA-Z0-9]{32,}",
            "pk-[a-zA-Z0-9]{32,}",
            "[a-zA-Z0-9]{32,}"
        ]

        for pattern in apiKeyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "[REDACTED]"
                )
            }
        }

        // Truncate if too long
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200)) + "..."
        }

        return sanitized
    }
}

/// Enumeration of possible message roles
enum MessageRole: String, Codable, CaseIterable {
    /// Message from the user
    case user

    /// Message from the AI assistant
    case assistant

    /// System message (instructions, context)
    case system

    /// Display name for the role
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        }
    }
}

// MARK: - Message Extensions

extension Message {
    /// Creates a user message
    /// - Parameter content: Message content
    /// - Returns: A new Message with user role
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    /// Creates an assistant message
    /// - Parameter content: Message content
    /// - Returns: A new Message with assistant role
    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }

    /// Creates a system message
    /// - Parameter content: Message content
    /// - Returns: A new Message with system role
    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}

// MARK: - Validation

extension Message {
    /// Validates the message content
    /// - Returns: True if the message is valid
    func isValid() -> Bool {
        // Content should not be empty
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Content should not exceed reasonable length (1MB)
        guard content.utf8.count <= 1_000_000 else {
            return false
        }

        return true
    }
}
