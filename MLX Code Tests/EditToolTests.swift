//
//  EditToolTests.swift
//  MLX Code Tests
//
//  Unit tests for EditTool: exact-string file edits, uniqueness enforcement,
//  multi-edit application, backup creation, changed-line counting, and the
//  EditError surface. These exercise the deterministic edit-application logic
//  that mutates user files, so correctness here is security/data-integrity
//  critical. All I/O is confined to a per-test temp directory.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class EditToolTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditToolTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func writeFile(_ name: String, _ contents: String) throws -> String {
        let path = tempDir.appendingPathComponent(name).path
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Single Edit

    func testEditReplacesUniqueString() async throws {
        let path = try writeFile("a.txt", "hello world\nsecond line\n")

        let result = try await EditTool.shared.edit(
            filePath: path, oldString: "hello world", newString: "goodbye world")

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.filePath, path)
        XCTAssertEqual(try read(path), "goodbye world\nsecond line\n",
            "Only the matched substring should be replaced")
    }

    func testEditCreatesBackupWithOriginalContents() async throws {
        let original = "let x = 1\nlet y = 2\n"
        let path = try writeFile("b.swift", original)

        let result = try await EditTool.shared.edit(
            filePath: path, oldString: "let x = 1", newString: "let x = 42")

        XCTAssertFalse(result.backupPath.isEmpty, "A backup path should be returned")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.backupPath),
            "Backup file should exist on disk")
        XCTAssertEqual(try read(result.backupPath), original,
            "Backup should preserve the pre-edit contents exactly")
    }

    func testEditThrowsWhenFileMissing() async {
        let missing = tempDir.appendingPathComponent("does-not-exist.txt").path
        do {
            _ = try await EditTool.shared.edit(
                filePath: missing, oldString: "a", newString: "b")
            XCTFail("Editing a missing file should throw")
        } catch let error as EditError {
            guard case .fileNotFound = error else {
                return XCTFail("Expected .fileNotFound, got \(error)")
            }
        } catch {
            XCTFail("Expected EditError, got \(error)")
        }
    }

    func testEditThrowsWhenStringNotFound() async throws {
        let path = try writeFile("c.txt", "the quick brown fox")
        do {
            _ = try await EditTool.shared.edit(
                filePath: path, oldString: "lazy dog", newString: "x")
            XCTFail("Missing search string should throw")
        } catch let error as EditError {
            guard case .stringNotFound = error else {
                return XCTFail("Expected .stringNotFound, got \(error)")
            }
        }
        XCTAssertEqual(try read(path), "the quick brown fox",
            "File must be untouched when the edit fails")
    }

    func testEditThrowsNotUniqueWhenAmbiguous() async throws {
        let path = try writeFile("d.txt", "foo bar foo baz foo")
        do {
            _ = try await EditTool.shared.edit(
                filePath: path, oldString: "foo", newString: "X")
            XCTFail("Non-unique oldString without replaceAll should throw")
        } catch let error as EditError {
            guard case .notUnique(_, let count) = error else {
                return XCTFail("Expected .notUnique, got \(error)")
            }
            XCTAssertEqual(count, 3, "Should report the true occurrence count")
        }
        XCTAssertEqual(try read(path), "foo bar foo baz foo",
            "Ambiguous edit must not mutate the file")
    }

    func testEditReplaceAllReplacesEveryOccurrence() async throws {
        let path = try writeFile("e.txt", "foo foo foo")

        let result = try await EditTool.shared.edit(
            filePath: path, oldString: "foo", newString: "bar", replaceAll: true)

        XCTAssertTrue(result.success)
        XCTAssertEqual(try read(path), "bar bar bar",
            "replaceAll should replace all matches even when non-unique")
    }

    func testEditReportsChangedLineCount() async throws {
        let path = try writeFile("f.txt", "line1\nline2\nline3\n")

        let result = try await EditTool.shared.edit(
            filePath: path, oldString: "line2", newString: "CHANGED")

        XCTAssertEqual(result.linesChanged, 1,
            "Changing content on a single line should count as one changed line")
    }

    // MARK: - Multi Edit

    func testMultiEditAppliesAllEdits() async throws {
        let path = try writeFile("g.txt", "alpha beta gamma")

        let result = try await EditTool.shared.multiEdit(
            filePath: path,
            edits: [(old: "alpha", new: "1"), (old: "gamma", new: "3")])

        XCTAssertTrue(result.success)
        XCTAssertEqual(try read(path), "1 beta 3",
            "All provided edits should be applied in order")
    }

    func testMultiEditIsAtomicOnMissingString() async throws {
        let original = "one two three"
        let path = try writeFile("h.txt", original)

        do {
            _ = try await EditTool.shared.multiEdit(
                filePath: path,
                edits: [(old: "one", new: "1"), (old: "NOPE", new: "x")])
            XCTFail("multiEdit should throw when any oldString is absent")
        } catch let error as EditError {
            guard case .stringNotFound = error else {
                return XCTFail("Expected .stringNotFound, got \(error)")
            }
        }
        XCTAssertEqual(try read(path), original,
            "No edits should be written if validation fails for any edit")
    }

    // MARK: - Error Surface

    func testEditErrorDescriptions() {
        XCTAssertEqual(
            EditError.fileNotFound("/x/y").errorDescription,
            "File not found: /x/y")
        XCTAssertEqual(
            EditError.notUnique("abc", 4).errorDescription,
            "String appears 4 times (must be unique). Use replaceAll=true or provide more context.")
        XCTAssertTrue(
            EditError.stringNotFound("needle-in-haystack").errorDescription?
                .contains("needle-in-haystack") ?? false,
            "stringNotFound description should include (a prefix of) the missing string")
    }
}
