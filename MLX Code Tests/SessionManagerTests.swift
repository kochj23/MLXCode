//
//  SessionManagerTests.swift
//  MLX Code Tests
//
//  Functional tests for SessionManager and AppSession: save/load round-trip,
//  session existence checks, clearing, Codable conformance, and error handling.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

@MainActor
final class SessionManagerTests: XCTestCase {

    private var manager: SessionManager!

    override func setUp() async throws {
        manager = SessionManager.shared
        // Clean state
        try? manager.clearSession()
    }

    override func tearDown() async throws {
        try? manager.clearSession()
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        let a = SessionManager.shared
        let b = SessionManager.shared
        XCTAssertTrue(a === b, "Shared instance should be the same object")
    }

    // MARK: - No Saved Session

    func testLoadWithNoSessionThrows() {
        try? manager.clearSession()
        XCTAssertThrowsError(try manager.loadSession()) { error in
            guard let sessionError = error as? SessionError else {
                XCTFail("Expected SessionError, got: \(error)")
                return
            }
            switch sessionError {
            case .noSavedSession:
                break // expected
            default:
                XCTFail("Expected noSavedSession, got: \(sessionError)")
            }
        }
    }

    func testHasSessionReturnsFalseWhenNone() {
        try? manager.clearSession()
        XCTAssertFalse(manager.hasSession(), "Should return false when no session saved")
    }

    // MARK: - Save and Load Round-Trip

    func testSaveAndLoadSession() throws {
        let conv = Conversation(title: "Test Session")
        let model = MLXModel(name: "TestModel", path: "/tmp/model")

        try manager.saveSession(
            conversation: conv,
            selectedModel: model,
            openFiles: ["/tmp/file1.swift", "/tmp/file2.swift"],
            indexedProject: "/Volumes/Data/xcode/MLX Code"
        )

        XCTAssertTrue(manager.hasSession(), "Session should exist after saving")

        let loaded = try manager.loadSession()
        XCTAssertEqual(loaded.conversation?.title, "Test Session")
        XCTAssertEqual(loaded.selectedModelId, model.id)
        XCTAssertEqual(loaded.openFiles.count, 2)
        XCTAssertEqual(loaded.indexedProject, "/Volumes/Data/xcode/MLX Code")
        XCTAssertNotNil(loaded.savedAt)
    }

    func testSaveSessionWithNilConversation() throws {
        try manager.saveSession(
            conversation: nil,
            selectedModel: nil,
            openFiles: [],
            indexedProject: nil
        )

        let loaded = try manager.loadSession()
        XCTAssertNil(loaded.conversation)
        XCTAssertNil(loaded.selectedModelId)
        XCTAssertTrue(loaded.openFiles.isEmpty)
        XCTAssertNil(loaded.indexedProject)
    }

    // MARK: - Clear Session

    func testClearSession() throws {
        // Save a session first
        try manager.saveSession(
            conversation: Conversation(title: "To Delete"),
            selectedModel: nil,
            openFiles: [],
            indexedProject: nil
        )
        XCTAssertTrue(manager.hasSession())

        try manager.clearSession()
        XCTAssertFalse(manager.hasSession(), "Session should be gone after clearing")
    }

    func testClearSessionWhenNoneExistsDoesNotCrash() throws {
        try? manager.clearSession()
        // Should not throw
        XCTAssertNoThrow(try manager.clearSession())
    }

    // MARK: - Overwrite Behavior

    func testSaveOverwritesPreviousSession() throws {
        try manager.saveSession(
            conversation: Conversation(title: "First"),
            selectedModel: nil,
            openFiles: ["a.swift"],
            indexedProject: nil
        )

        try manager.saveSession(
            conversation: Conversation(title: "Second"),
            selectedModel: nil,
            openFiles: ["b.swift"],
            indexedProject: nil
        )

        let loaded = try manager.loadSession()
        XCTAssertEqual(loaded.conversation?.title, "Second",
            "Second save should overwrite first")
        XCTAssertEqual(loaded.openFiles, ["b.swift"])
    }

    // MARK: - AppSession Codable

    func testAppSessionCodableRoundTrip() throws {
        let session = AppSession(
            conversation: Conversation(title: "Codable Test"),
            selectedModelId: UUID(),
            openFiles: ["file1.swift", "file2.swift"],
            indexedProject: "/path/to/project",
            savedAt: Date()
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(AppSession.self, from: data)

        XCTAssertEqual(decoded.conversation?.title, session.conversation?.title)
        XCTAssertEqual(decoded.selectedModelId, session.selectedModelId)
        XCTAssertEqual(decoded.openFiles, session.openFiles)
        XCTAssertEqual(decoded.indexedProject, session.indexedProject)
    }

    // MARK: - SessionError Descriptions

    func testSessionErrorDescriptions() {
        let errors: [SessionError] = [.noSavedSession, .corruptedSession]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
