//
//  ConversationManager.swift
//  MLX Code
//
//  Advanced conversation management with templates and search
//  Created on 2025-12-09
//

import Foundation
import Combine

/// Manages conversations with templates, export, and search
@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var templates: [ConversationTemplate] = []
    @Published var searchResults: [Conversation] = []

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var conversationsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MLX Code/Conversations")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var templatesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MLX Code/Templates")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        loadConversations()
        loadTemplates()
    }

    // MARK: - Conversation Operations

    /// Saves a conversation to disk
    func save(_ conversation: Conversation) throws {
        let url = conversationsDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        let data = try JSONEncoder().encode(conversation)
        try data.write(to: url)
    }

    /// Loads all saved conversations
    func loadConversations() {
        do {
            let files = try fileManager.contentsOfDirectory(at: conversationsDirectory, includingPropertiesForKeys: nil)
            conversations = files.compactMap { url in
                guard url.pathExtension == "json",
                      let data = try? Data(contentsOf: url),
                      let conversation = try? JSONDecoder().decode(Conversation.self, from: data) else {
                    return nil
                }
                return conversation
            }
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }

    /// Exports conversation as markdown
    /// - Parameters:
    ///   - conversation: Conversation to export
    ///   - destination: Export file URL
    func exportAsMarkdown(_ conversation: Conversation, to destination: URL) throws {
        var markdown = "# \(conversation.title)\n\n"
        markdown += "**Created:** \(conversation.createdAt.formatted())\n"
        markdown += "**Modified:** \(conversation.updatedAt.formatted())\n\n"
        markdown += "---\n\n"

        for message in conversation.messages {
            let role = message.role == .user ? "User" : "Assistant"
            markdown += "## \(role)\n\n"
            markdown += "\(message.content)\n\n"
            markdown += "---\n\n"
        }

        try markdown.write(to: destination, atomically: true, encoding: .utf8)
    }

    /// Deletes a conversation
    func delete(_ conversation: Conversation) throws {
        let url = conversationsDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        try fileManager.removeItem(at: url)
        conversations.removeAll { $0.id == conversation.id }
    }

    // MARK: - Templates

    /// Saves a conversation as a template
    func saveAsTemplate(_ conversation: Conversation, name: String, description: String) throws {
        let template = ConversationTemplate(
            name: name,
            description: description,
            messages: conversation.messages
        )

        let url = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        let data = try JSONEncoder().encode(template)
        try data.write(to: url)

        templates.append(template)
    }

    /// Loads all templates
    func loadTemplates() {
        do {
            let files = try fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil)
            templates = files.compactMap { url in
                guard url.pathExtension == "json",
                      let data = try? Data(contentsOf: url),
                      let template = try? JSONDecoder().decode(ConversationTemplate.self, from: data) else {
                    return nil
                }
                return template
            }
        } catch {
            print("Failed to load templates: \(error)")
        }
    }

    /// Creates a new conversation from a template
    func createFromTemplate(_ template: ConversationTemplate) -> Conversation {
        return Conversation(
            title: template.name,
            messages: template.messages
        )
    }

    /// Deletes a template
    func deleteTemplate(_ template: ConversationTemplate) throws {
        let url = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        try fileManager.removeItem(at: url)
        templates.removeAll { $0.id == template.id }
    }

    // MARK: - Search

    /// Searches conversations by content
    /// - Parameter query: Search query
    func search(_ query: String) {
        let lowercaseQuery = query.lowercased()

        searchResults = conversations.filter { conversation in
            // Check title
            if conversation.title.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Check messages
            for message in conversation.messages {
                if message.content.lowercased().contains(lowercaseQuery) {
                    return true
                }
            }

            return false
        }
    }

    /// Clears search results
    func clearSearch() {
        searchResults = []
    }

    // MARK: - Branching

    /// Creates a new conversation branch from a message
    /// - Parameters:
    ///   - conversation: Original conversation
    ///   - fromMessage: Message to branch from
    /// - Returns: New branched conversation
    func createBranch(from conversation: Conversation, fromMessage: Message) -> Conversation {
        guard let messageIndex = conversation.messages.firstIndex(where: { $0.id == fromMessage.id }) else {
            return conversation
        }

        // Create new conversation with messages up to and including the branch point
        let branchedMessages = Array(conversation.messages.prefix(through: messageIndex))

        return Conversation(
            title: "\(conversation.title) (Branch)",
            messages: branchedMessages
        )
    }
}

/// Conversation template for reuse
struct ConversationTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let messages: [Message]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, description: String, messages: [Message]) {
        self.id = id
        self.name = name
        self.description = description
        self.messages = messages
        self.createdAt = Date()
    }
}
