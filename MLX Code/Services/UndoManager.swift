//
//  UndoManager.swift
//  MLX Code
//
//  Undo/Redo system for file operations
//  Created on 2025-12-09
//

import Foundation

/// Manages undo/redo for file operations
@MainActor
class FileUndoManager: ObservableObject {
    static let shared = FileUndoManager()

    // MARK: - Published Properties

    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    // MARK: - Private Properties

    private var undoStack: [FileOperation] = []
    private var redoStack: [FileOperation] = []
    private let maxStackSize = 50

    private init() {}

    // MARK: - Recording Operations

    /// Records a file operation for undo
    func recordOperation(_ operation: FileOperation) {
        // Clear redo stack when new operation recorded
        redoStack.removeAll()

        // Add to undo stack
        undoStack.append(operation)

        // Limit stack size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }

        updateCanUndoRedo()
        print("📝 Recorded operation: \(operation.type) on \(operation.filePath)")
    }

    // MARK: - Undo/Redo

    /// Undoes the last operation
    func undo() async throws {
        guard let operation = undoStack.popLast() else {
            throw UndoError.nothingToUndo
        }

        print("↩️  Undoing: \(operation.type) on \(operation.filePath)")

        // Execute undo
        try await operation.undo()

        // Move to redo stack
        redoStack.append(operation)

        updateCanUndoRedo()
    }

    /// Redoes the last undone operation
    func redo() async throws {
        guard let operation = redoStack.popLast() else {
            throw UndoError.nothingToRedo
        }

        print("↪️  Redoing: \(operation.type) on \(operation.filePath)")

        // Execute redo
        try await operation.redo()

        // Move back to undo stack
        undoStack.append(operation)

        updateCanUndoRedo()
    }

    /// Clears all undo/redo history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
        print("🗑️  Cleared undo/redo history")
    }

    /// Gets undo/redo stack info
    func getHistory() -> (undoCount: Int, redoCount: Int, operations: [FileOperation]) {
        return (undoStack.count, redoStack.count, undoStack)
    }

    // MARK: - Private Methods

    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - File Operation

/// Represents a file operation that can be undone/redone
class FileOperation {
    let id: UUID
    let filePath: String
    let type: OperationType
    let timestamp: Date

    // State for undo/redo
    private let beforeContent: String?
    private let afterContent: String?
    private let fileExistedBefore: Bool

    enum OperationType: String {
        case create = "Create"
        case edit = "Edit"
        case delete = "Delete"
    }

    init(
        filePath: String,
        type: OperationType,
        beforeContent: String? = nil,
        afterContent: String? = nil,
        fileExistedBefore: Bool = false
    ) {
        self.id = UUID()
        self.filePath = filePath
        self.type = type
        self.timestamp = Date()
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.fileExistedBefore = fileExistedBefore
    }

    /// Undoes the operation
    func undo() async throws {
        let fileManager = FileManager.default

        switch type {
        case .create:
            // Delete created file
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }

        case .edit:
            // Restore original content
            if let before = beforeContent {
                try before.write(toFile: filePath, atomically: true, encoding: .utf8)
            }

        case .delete:
            // Restore deleted file
            if let before = beforeContent {
                try before.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Redoes the operation
    func redo() async throws {
        let fileManager = FileManager.default

        switch type {
        case .create, .edit:
            // Restore modified content
            if let after = afterContent {
                try after.write(toFile: filePath, atomically: true, encoding: .utf8)
            }

        case .delete:
            // Delete file again
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }
        }
    }

    /// Creates a FileOperation for editing a file
    static func edit(
        path: String,
        beforeContent: String,
        afterContent: String
    ) -> FileOperation {
        return FileOperation(
            filePath: path,
            type: .edit,
            beforeContent: beforeContent,
            afterContent: afterContent,
            fileExistedBefore: true
        )
    }

    /// Creates a FileOperation for creating a file
    static func create(
        path: String,
        content: String
    ) -> FileOperation {
        return FileOperation(
            filePath: path,
            type: .create,
            beforeContent: nil,
            afterContent: content,
            fileExistedBefore: false
        )
    }

    /// Creates a FileOperation for deleting a file
    static func delete(
        path: String,
        content: String
    ) -> FileOperation {
        return FileOperation(
            filePath: path,
            type: .delete,
            beforeContent: content,
            afterContent: nil,
            fileExistedBefore: true
        )
    }
}

// MARK: - Errors

enum UndoError: LocalizedError {
    case nothingToUndo
    case nothingToRedo
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToUndo:
            return "Nothing to undo"
        case .nothingToRedo:
            return "Nothing to redo"
        case .operationFailed(let details):
            return "Operation failed: \(details)"
        }
    }
}
