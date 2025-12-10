//
//  SessionManager.swift
//  MLX Code
//
//  Saves and resumes complete application state
//  Created on 2025-12-09
//

import Foundation

/// Manages application session persistence
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private var sessionFile: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MLX Code/Sessions")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("current_session.json")
    }

    private init() {}

    // MARK: - Save/Load Session

    /// Saves current application state
    func saveSession(
        conversation: Conversation?,
        selectedModel: MLXModel?,
        openFiles: [String],
        indexedProject: String?
    ) throws {
        let session = AppSession(
            conversation: conversation,
            selectedModelId: selectedModel?.id,
            openFiles: openFiles,
            indexedProject: indexedProject,
            savedAt: Date()
        )

        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionFile)

        print("💾 Session saved")
    }

    /// Loads last saved session
    func loadSession() throws -> AppSession {
        guard fileManager.fileExists(atPath: sessionFile.path) else {
            throw SessionError.noSavedSession
        }

        let data = try Data(contentsOf: sessionFile)
        let session = try JSONDecoder().decode(AppSession.self, from: data)

        print("📂 Session loaded from \(session.savedAt.formatted())")
        return session
    }

    /// Checks if a saved session exists
    func hasSession() -> Bool {
        return fileManager.fileExists(atPath: sessionFile.path)
    }

    /// Deletes saved session
    func clearSession() throws {
        if fileManager.fileExists(atPath: sessionFile.path) {
            try fileManager.removeItem(at: sessionFile)
            print("🗑️  Session cleared")
        }
    }

    /// Auto-saves session periodically
    func startAutoSave(
        getState: @escaping () -> (
            conversation: Conversation?,
            model: MLXModel?,
            files: [String],
            project: String?
        )
    ) {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let state = getState()
                try? self?.saveSession(
                    conversation: state.conversation,
                    selectedModel: state.model,
                    openFiles: state.files,
                    indexedProject: state.project
                )
            }
        }
    }
}

// MARK: - Session Model

/// Represents a saved application session
struct AppSession: Codable {
    let conversation: Conversation?
    let selectedModelId: UUID?
    let openFiles: [String]
    let indexedProject: String?
    let savedAt: Date
}

/// Session errors
enum SessionError: LocalizedError {
    case noSavedSession
    case corruptedSession

    var errorDescription: String? {
        switch self {
        case .noSavedSession:
            return "No saved session found"
        case .corruptedSession:
            return "Saved session is corrupted"
        }
    }
}
