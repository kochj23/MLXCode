//
//  GitHubSettings.swift
//  MLX Code
//
//  GitHub account and API configuration
//  Created on 2025-12-09
//

import Foundation
import Combine

/// GitHub account configuration
@MainActor
class GitHubSettings: ObservableObject {
    static let shared = GitHubSettings()

    // MARK: - Published Properties

    /// GitHub username
    @Published var username: String = ""

    /// GitHub personal access token (stored securely)
    @Published var hasToken: Bool = false

    /// Default repository owner (for PR creation)
    @Published var defaultOwner: String = ""

    /// Default repository name
    @Published var defaultRepo: String = ""

    /// Default branch name
    @Published var defaultBranch: String = "main"

    /// Whether to auto-push after commit
    @Published var autoPushCommits: Bool = false

    /// Whether to auto-create PRs
    @Published var autoCreatePRs: Bool = false

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let username = "github_username"
        static let defaultOwner = "github_default_owner"
        static let defaultRepo = "github_default_repo"
        static let defaultBranch = "github_default_branch"
        static let autoPushCommits = "github_auto_push"
        static let autoCreatePRs = "github_auto_create_prs"
    }

    private let keychainService = "com.local.mlxcode.github"

    private init() {
        loadSettings()
        setupObservers()
    }

    // MARK: - Token Management (Keychain)

    /// Stores GitHub token securely in Keychain
    func saveToken(_ token: String) throws {
        guard !token.isEmpty else {
            throw GitHubError.invalidToken
        }

        // Validate token format (ghp_...)
        if !token.hasPrefix("ghp_") && !token.hasPrefix("github_pat_") {
            throw GitHubError.invalidToken
        }

        let tokenData = token.data(using: .utf8)!

        // Keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username,
            kSecValueData as String: tokenData
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw GitHubError.keychainError("Failed to save token: \(status)")
        }

        hasToken = true
        print("🔐 GitHub token saved to Keychain")
    }

    /// Retrieves GitHub token from Keychain
    func getToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw GitHubError.keychainError("No token found")
        }

        guard let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw GitHubError.keychainError("Invalid token data")
        }

        return token
    }

    /// Deletes token from Keychain
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitHubError.keychainError("Failed to delete token: \(status)")
        }

        hasToken = false
        print("🗑️  GitHub token deleted")
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        username = userDefaults.string(forKey: Keys.username) ?? ""
        defaultOwner = userDefaults.string(forKey: Keys.defaultOwner) ?? ""
        defaultRepo = userDefaults.string(forKey: Keys.defaultRepo) ?? ""
        defaultBranch = userDefaults.string(forKey: Keys.defaultBranch) ?? "main"
        autoPushCommits = userDefaults.bool(forKey: Keys.autoPushCommits)
        autoCreatePRs = userDefaults.bool(forKey: Keys.autoCreatePRs)

        // Check if token exists
        hasToken = (try? getToken()) != nil

        print("📂 GitHub settings loaded")
    }

    func saveSettings() {
        userDefaults.set(username, forKey: Keys.username)
        userDefaults.set(defaultOwner, forKey: Keys.defaultOwner)
        userDefaults.set(defaultRepo, forKey: Keys.defaultRepo)
        userDefaults.set(defaultBranch, forKey: Keys.defaultBranch)
        userDefaults.set(autoPushCommits, forKey: Keys.autoPushCommits)
        userDefaults.set(autoCreatePRs, forKey: Keys.autoCreatePRs)

        print("💾 GitHub settings saved")
    }

    private func setupObservers() {
        $username
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $defaultOwner
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $defaultRepo
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $defaultBranch
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $autoPushCommits
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $autoCreatePRs
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }

    // MARK: - Validation

    /// Tests GitHub connection
    func testConnection() async throws -> GitHubConnectionStatus {
        guard !username.isEmpty else {
            throw GitHubError.missingUsername
        }

        let token = try getToken()

        // Test with GitHub API
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-H", "Authorization: token \(token)",
            "-H", "Accept: application/vnd.github.v3+json",
            "https://api.github.com/user"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 && output.contains("\"login\"") {
            return GitHubConnectionStatus(
                connected: true,
                username: username,
                message: "✅ Connected successfully"
            )
        } else {
            return GitHubConnectionStatus(
                connected: false,
                username: nil,
                message: "❌ Authentication failed. Check token."
            )
        }
    }

    /// Resets all GitHub settings
    func resetSettings() {
        username = ""
        defaultOwner = ""
        defaultRepo = ""
        defaultBranch = "main"
        autoPushCommits = false
        autoCreatePRs = false

        try? deleteToken()

        saveSettings()
    }
}

// MARK: - Supporting Types

/// GitHub connection test result
struct GitHubConnectionStatus {
    let connected: Bool
    let username: String?
    let message: String
}

/// GitHub configuration errors
enum GitHubError: LocalizedError {
    case invalidToken
    case missingUsername
    case keychainError(String)
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid GitHub token format. Must start with 'ghp_' or 'github_pat_'"
        case .missingUsername:
            return "GitHub username is required"
        case .keychainError(let details):
            return "Keychain error: \(details)"
        case .connectionFailed:
            return "Failed to connect to GitHub"
        }
    }
}
