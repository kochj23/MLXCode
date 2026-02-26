//
//  KeychainManager.swift
//  MLX Code
//
//  Created on 2026-02-26.
//  Author: Jordan Koch
//
//  Secure credential storage using macOS Keychain.
//  All API keys and secrets MUST use this instead of UserDefaults.
//

import Foundation
import Security

/// Thread-safe Keychain wrapper for storing API keys and credentials securely.
/// Uses kSecClassGenericPassword items with service-scoped access.
final class KeychainManager {
    static let shared = KeychainManager()

    private let servicePrefix = "com.jordankoch.mlxcode"

    private init() {}

    // MARK: - Public API

    /// Save a string value to the Keychain.
    /// - Parameters:
    ///   - value: The secret string to store (e.g. an API key).
    ///   - key: A logical key name (e.g. "OpenAI_Key").
    /// - Throws: KeychainError on failure.
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any existing item first to avoid errSecDuplicateItem
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  serviceName(for: key),
            kSecAttrAccount as String:  key,
            kSecValueData as String:    data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load a string value from the Keychain.
    /// - Parameter key: The logical key name.
    /// - Returns: The stored string, or an empty string if not found.
    func load(forKey key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  serviceName(for: key),
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    /// Delete a value from the Keychain.
    /// - Parameter key: The logical key name.
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  serviceName(for: key),
            kSecAttrAccount as String:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migration

    /// Migrate a key from UserDefaults to Keychain, then remove from UserDefaults.
    /// Only migrates if the Keychain doesn't already have a value for that key.
    func migrateFromUserDefaults(userDefaultsKey: String, keychainKey: String) {
        let existing = load(forKey: keychainKey)
        guard existing.isEmpty else { return } // Already in Keychain

        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: userDefaultsKey), !value.isEmpty {
            try? save(value, forKey: keychainKey)
            defaults.removeObject(forKey: userDefaultsKey)
            NSLog("[KeychainManager] Migrated %@ from UserDefaults to Keychain", keychainKey)
        }
    }

    // MARK: - Private

    private func serviceName(for key: String) -> String {
        "\(servicePrefix).\(key)"
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case encodingFailed
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Failed to encode string as UTF-8 data"
            case .saveFailed(let status):
                return "Keychain save failed with status \(status)"
            }
        }
    }
}
