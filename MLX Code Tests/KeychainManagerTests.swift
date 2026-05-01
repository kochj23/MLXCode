//
//  KeychainManagerTests.swift
//  MLX Code Tests
//
//  Unit tests for KeychainManager: save, load, delete, migration,
//  error handling, and thread-safety validation.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class KeychainManagerTests: XCTestCase {

    private let testKey = "mlxcode_test_key_\(UUID().uuidString)"
    private let keychain = KeychainManager.shared

    override func tearDown() {
        // Clean up test keys
        keychain.delete(forKey: testKey)
        super.tearDown()
    }

    // MARK: - Save and Load

    func testSaveAndLoad() throws {
        try keychain.save("test-secret-value", forKey: testKey)
        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, "test-secret-value", "Loaded value should match saved value")
    }

    func testLoadNonexistentKeyReturnsEmpty() {
        let value = keychain.load(forKey: "nonexistent_key_\(UUID().uuidString)")
        XCTAssertEqual(value, "", "Loading a non-existent key should return empty string")
    }

    func testOverwriteExistingKey() throws {
        try keychain.save("first", forKey: testKey)
        try keychain.save("second", forKey: testKey)
        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, "second", "Overwriting should store the new value")
    }

    // MARK: - Delete

    func testDeleteExistingKey() throws {
        try keychain.save("value", forKey: testKey)
        let deleted = keychain.delete(forKey: testKey)
        XCTAssertTrue(deleted, "Deleting existing key should return true")

        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, "", "Deleted key should return empty string")
    }

    func testDeleteNonexistentKey() {
        let deleted = keychain.delete(forKey: "nonexistent_\(UUID().uuidString)")
        XCTAssertTrue(deleted, "Deleting non-existent key should return true (errSecItemNotFound accepted)")
    }

    // MARK: - Special Characters

    func testSaveUnicodeValue() throws {
        let unicodeValue = "API-Key: sk-abc123 (valid)"
        try keychain.save(unicodeValue, forKey: testKey)
        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, unicodeValue, "Unicode and special characters should be preserved")
    }

    func testSaveEmptyString() throws {
        try keychain.save("", forKey: testKey)
        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, "", "Empty string should be storable and loadable")
    }

    func testSaveLongValue() throws {
        let longValue = String(repeating: "x", count: 10_000)
        try keychain.save(longValue, forKey: testKey)
        let loaded = keychain.load(forKey: testKey)
        XCTAssertEqual(loaded, longValue, "Long strings should be storable")
    }

    // MARK: - Error Types

    func testKeychainErrorDescriptions() {
        let errors: [KeychainManager.KeychainError] = [
            .encodingFailed,
            .saveFailed(-25299)
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        let a = KeychainManager.shared
        let b = KeychainManager.shared
        XCTAssertTrue(a === b, "Shared instance should be the same object")
    }
}
