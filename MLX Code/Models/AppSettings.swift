//
//  AppSettings.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Combine
import AppKit

/// Image generation quality presets
enum ImageQuality: String, CaseIterable, Codable {
    case fast = "fast"
    case balanced = "balanced"
    case high = "high"

    var displayName: String {
        switch self {
        case .fast: return "Fast (4 steps)"
        case .balanced: return "Balanced (20 steps)"
        case .high: return "High Quality (50 steps)"
        }
    }

    var steps: Int {
        switch self {
        case .fast: return 4
        case .balanced: return 20
        case .high: return 50
        }
    }

    var description: String {
        switch self {
        case .fast: return "Quick results, good for iteration (2-5s)"
        case .balanced: return "Good quality, reasonable speed (5-15s)"
        case .high: return "Best quality, slower (10-30s)"
        }
    }
}

/// Image generation model configuration
struct ImageModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let speed: String
    let quality: String
    let size: String
    let huggingFaceId: String
    let isCustom: Bool

    init(id: String, name: String, description: String, speed: String, quality: String, size: String, huggingFaceId: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.speed = speed
        self.quality = quality
        self.size = size
        self.huggingFaceId = huggingFaceId
        self.isCustom = isCustom
    }
}

/// Singleton class managing application settings
/// Thread-safe using @MainActor annotation
@MainActor
class AppSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = AppSettings()

    // MARK: - Published Properties

    /// Currently selected MLX model
    @Published var selectedModel: MLXModel?

    /// Available MLX models
    @Published var availableModels: [MLXModel] = []

    /// Temperature setting (0.0 to 2.0)
    @Published var temperature: Double = 0.7

    /// Maximum tokens to generate
    @Published var maxTokens: Int = 2048

    /// Top-p sampling parameter
    @Published var topP: Double = 0.9

    /// Top-k sampling parameter
    @Published var topK: Int = 40

    /// Path to Python executable
    @Published var pythonPath: String = "/usr/bin/python3"

    /// Theme preference
    @Published var theme: AppTheme = .system

    /// Font size for chat
    @Published var fontSize: Double = 14.0

    /// Enable syntax highlighting
    @Published var enableSyntaxHighlighting: Bool = true

    /// Enable auto-save
    @Published var enableAutoSave: Bool = true

    /// Auto-save interval in seconds
    @Published var autoSaveInterval: TimeInterval = 30.0

    /// Maximum conversation history
    @Published var maxConversationHistory: Int = 50

    // MARK: - Path Settings

    /// Xcode projects directory
    @Published var xcodeProjectsPath: String = "~/Desktop/xcode"

    /// Default workspace directory
    @Published var workspacePath: String = "~"

    /// Custom model storage directory
    @Published var modelsPath: String = ""

    /// Templates export/import directory
    @Published var templatesPath: String = "~/Documents"

    /// Conversation export directory
    @Published var conversationsExportPath: String = "~/Documents"

    // MARK: - Image Generation Settings

    /// Selected image generation model
    @Published var selectedImageModel: String = "sdxl-turbo"

    /// Image generation quality setting
    @Published var imageQuality: ImageQuality = .balanced

    /// Available image generation models (mutable for custom models)
    @Published var availableImageModels: [ImageModel] = [
        ImageModel(id: "sdxl-turbo", name: "SDXL-Turbo ⭐", description: "Fast (2-5s), Good quality, 7GB", speed: "2-5s", quality: "Good", size: "7GB", huggingFaceId: "stabilityai/sdxl-turbo", isCustom: false),
        ImageModel(id: "sd-2.1", name: "Stable Diffusion 2.1", description: "Balanced (5-15s), Excellent quality, 5GB", speed: "5-15s", quality: "Excellent", size: "5GB", huggingFaceId: "stabilityai/stable-diffusion-2-1", isCustom: false),
        ImageModel(id: "flux", name: "FLUX", description: "Best quality (10-30s), Professional, 24GB", speed: "10-30s", quality: "Professional", size: "24GB", huggingFaceId: "black-forest-labs/FLUX.1-schnell", isCustom: false),
        ImageModel(id: "sdxl-base", name: "SDXL Base", description: "High quality (8-15s), Detailed, 7GB", speed: "8-15s", quality: "Excellent", size: "7GB", huggingFaceId: "stabilityai/stable-diffusion-xl-base-1.0", isCustom: false),
        ImageModel(id: "sd-1.5", name: "SD 1.5 Classic", description: "Fast (3-8s), Classic quality, 4GB", speed: "3-8s", quality: "Good", size: "4GB", huggingFaceId: "runwayml/stable-diffusion-v1-5", isCustom: false)
    ]

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let selectedModelId = "selectedModelId"
        static let availableModels = "availableModels"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let topP = "topP"
        static let topK = "topK"
        static let pythonPath = "pythonPath"
        static let theme = "theme"
        static let fontSize = "fontSize"
        static let enableSyntaxHighlighting = "enableSyntaxHighlighting"
        static let enableAutoSave = "enableAutoSave"
        static let autoSaveInterval = "autoSaveInterval"
        static let maxConversationHistory = "maxConversationHistory"
        static let xcodeProjectsPath = "xcodeProjectsPath"
        static let workspacePath = "workspacePath"
        static let modelsPath = "modelsPath"
        static let templatesPath = "templatesPath"
        static let conversationsExportPath = "conversationsExportPath"
        static let selectedImageModel = "selectedImageModel"
        static let imageQuality = "imageQuality"
    }

    // MARK: - Initialization

    private init() {
        // Initialize models path with smart default before loading settings
        if modelsPath.isEmpty {
            modelsPath = Self.detectWritableModelsPath()
        }
        loadSettings()
        setupObservers()
    }

    // MARK: - Smart Default Path Detection

    /// Detects the first writable location for models storage
    /// Tries multiple common paths and returns the first one that's writable
    /// - Returns: Path to writable models directory (tilde format)
    nonisolated static func detectWritableModelsPath() -> String {
        let fileManager = FileManager.default

        // Candidate paths in order of preference
        let candidatePaths = [
            "~/.mlx/models",                                          // Original default (for backward compatibility)
            "~/Documents/MLXCode/models",                            // Most likely writable on work machines
            "~/Library/Application Support/MLXCode/models",          // Standard macOS app location
            "\(NSTemporaryDirectory())MLXCode/models"                // Fallback for extreme cases
        ]

        for candidatePath in candidatePaths {
            let expandedPath = (candidatePath as NSString).expandingTildeInPath

            // Try to create directory if it doesn't exist
            if !fileManager.fileExists(atPath: expandedPath) {
                do {
                    try fileManager.createDirectory(
                        atPath: expandedPath,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    print("[AppSettings] ✅ Created models directory: \(candidatePath)")
                } catch {
                    print("[AppSettings] ⚠️ Failed to create \(candidatePath): \(error.localizedDescription)")
                    continue
                }
            }

            // Test write permissions
            let testFileName = ".mlx_write_test_\(UUID().uuidString)"
            let testFileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(testFileName)

            do {
                try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
                try? fileManager.removeItem(at: testFileURL)

                print("[AppSettings] ✅ Found writable models path: \(candidatePath)")
                return candidatePath
            } catch {
                print("[AppSettings] ⚠️ No write permission for \(candidatePath): \(error.localizedDescription)")
                continue
            }
        }

        // Fallback to original default if all else fails
        print("[AppSettings] ⚠️ Using fallback default: ~/Documents/MLXCode/models")
        return "~/Documents/MLXCode/models"
    }

    // MARK: - Public Methods

    /// Loads settings from UserDefaults
    func loadSettings() {
        // Load temperature with validation
        let loadedTemp = userDefaults.double(forKey: Keys.temperature)
        if loadedTemp > 0 {
            temperature = min(max(loadedTemp, 0.0), 2.0)
        }

        // Load max tokens with validation
        let loadedMaxTokens = userDefaults.integer(forKey: Keys.maxTokens)
        if loadedMaxTokens > 0 {
            maxTokens = min(max(loadedMaxTokens, 1), 100_000)
        }

        // Load top-p with validation
        let loadedTopP = userDefaults.double(forKey: Keys.topP)
        if loadedTopP > 0 {
            topP = min(max(loadedTopP, 0.0), 1.0)
        }

        // Load top-k with validation
        let loadedTopK = userDefaults.integer(forKey: Keys.topK)
        if loadedTopK > 0 {
            topK = min(max(loadedTopK, 1), 1000)
        }

        // Load python path with validation
        if let path = userDefaults.string(forKey: Keys.pythonPath), !path.isEmpty {
            pythonPath = path
        }

        // Load theme
        if let themeRaw = userDefaults.string(forKey: Keys.theme),
           let loadedTheme = AppTheme(rawValue: themeRaw) {
            theme = loadedTheme
        }

        // Load font size with validation
        let loadedFontSize = userDefaults.double(forKey: Keys.fontSize)
        if loadedFontSize > 0 {
            fontSize = min(max(loadedFontSize, 8.0), 72.0)
        }

        // Load boolean preferences
        enableSyntaxHighlighting = userDefaults.bool(forKey: Keys.enableSyntaxHighlighting)
        enableAutoSave = userDefaults.bool(forKey: Keys.enableAutoSave)

        // Load auto-save interval with validation
        let loadedInterval = userDefaults.double(forKey: Keys.autoSaveInterval)
        if loadedInterval > 0 {
            autoSaveInterval = min(max(loadedInterval, 5.0), 300.0)
        }

        // Load max conversation history with validation
        let loadedHistory = userDefaults.integer(forKey: Keys.maxConversationHistory)
        if loadedHistory > 0 {
            maxConversationHistory = min(max(loadedHistory, 10), 1000)
        }

        // Load path settings with validation
        if let path = userDefaults.string(forKey: Keys.xcodeProjectsPath), !path.isEmpty {
            xcodeProjectsPath = path
        }

        if let path = userDefaults.string(forKey: Keys.workspacePath), !path.isEmpty {
            workspacePath = path
        }

        if let path = userDefaults.string(forKey: Keys.modelsPath), !path.isEmpty {
            modelsPath = path
        } else {
            // No saved path, use smart default
            modelsPath = Self.detectWritableModelsPath()
            print("[AppSettings] 🔍 No saved models path, using smart default: \(modelsPath)")
        }

        if let path = userDefaults.string(forKey: Keys.templatesPath), !path.isEmpty {
            templatesPath = path
        }

        if let path = userDefaults.string(forKey: Keys.conversationsExportPath), !path.isEmpty {
            conversationsExportPath = path
        }

        // Load image generation settings
        if let imageModel = userDefaults.string(forKey: Keys.selectedImageModel), !imageModel.isEmpty {
            selectedImageModel = imageModel
        }

        if let qualityRaw = userDefaults.string(forKey: Keys.imageQuality),
           let loadedQuality = ImageQuality(rawValue: qualityRaw) {
            imageQuality = loadedQuality
        }

        // Load available models
        if let modelsData = userDefaults.data(forKey: Keys.availableModels),
           let models = try? JSONDecoder().decode([MLXModel].self, from: modelsData) {
            availableModels = models
        } else {
            // Initialize with default models
            availableModels = MLXModel.commonModels()
        }

        // Load selected model
        if let selectedModelId = userDefaults.string(forKey: Keys.selectedModelId),
           let uuid = UUID(uuidString: selectedModelId) {
            selectedModel = availableModels.first { $0.id == uuid }
        }
    }

    /// Saves all settings to UserDefaults
    func saveSettings() {
        userDefaults.set(temperature, forKey: Keys.temperature)
        userDefaults.set(maxTokens, forKey: Keys.maxTokens)
        userDefaults.set(topP, forKey: Keys.topP)
        userDefaults.set(topK, forKey: Keys.topK)
        userDefaults.set(pythonPath, forKey: Keys.pythonPath)
        userDefaults.set(theme.rawValue, forKey: Keys.theme)
        userDefaults.set(fontSize, forKey: Keys.fontSize)
        userDefaults.set(enableSyntaxHighlighting, forKey: Keys.enableSyntaxHighlighting)
        userDefaults.set(enableAutoSave, forKey: Keys.enableAutoSave)
        userDefaults.set(autoSaveInterval, forKey: Keys.autoSaveInterval)
        userDefaults.set(maxConversationHistory, forKey: Keys.maxConversationHistory)

        // Save path settings
        userDefaults.set(xcodeProjectsPath, forKey: Keys.xcodeProjectsPath)
        userDefaults.set(workspacePath, forKey: Keys.workspacePath)
        userDefaults.set(modelsPath, forKey: Keys.modelsPath)
        userDefaults.set(templatesPath, forKey: Keys.templatesPath)
        userDefaults.set(conversationsExportPath, forKey: Keys.conversationsExportPath)

        // Save image generation settings
        userDefaults.set(selectedImageModel, forKey: Keys.selectedImageModel)
        userDefaults.set(imageQuality.rawValue, forKey: Keys.imageQuality)

        // Save selected model ID
        if let modelId = selectedModel?.id.uuidString {
            userDefaults.set(modelId, forKey: Keys.selectedModelId)
        }

        // Save available models
        if let modelsData = try? JSONEncoder().encode(availableModels) {
            userDefaults.set(modelsData, forKey: Keys.availableModels)
        }
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        temperature = 0.7
        maxTokens = 2048
        topP = 0.9
        topK = 40
        pythonPath = "/usr/bin/python3"
        theme = .system
        fontSize = 14.0
        enableSyntaxHighlighting = true
        enableAutoSave = true
        autoSaveInterval = 30.0
        maxConversationHistory = 50

        // Reset path settings to defaults
        xcodeProjectsPath = "~/Desktop/xcode"
        workspacePath = "~"
        modelsPath = Self.detectWritableModelsPath() // Use smart default
        templatesPath = "~/Documents"
        conversationsExportPath = "~/Documents"

        availableModels = MLXModel.commonModels()
        selectedModel = availableModels.first

        saveSettings()
    }

    /// Validates Python path exists
    /// - Returns: True if the Python path is valid
    func validatePythonPath() -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        let expandedPath = (pythonPath as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            return false
        }

        // Should be a file, not a directory
        guard !isDirectory.boolValue else {
            return false
        }

        // Check if file is executable
        return fileManager.isExecutableFile(atPath: expandedPath)
    }

    /// Validates if a directory path exists
    /// - Parameter path: Path to validate (supports tilde expansion)
    /// - Returns: True if the path exists and is a directory
    func validateDirectoryPath(_ path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        let expandedPath = (path as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            return false
        }

        return isDirectory.boolValue
    }

    /// Checks if a directory has write permissions
    /// - Parameter path: Path to check (supports tilde expansion)
    /// - Returns: True if the directory exists and is writable
    func hasWritePermission(for path: String) -> Bool {
        let fileManager = FileManager.default
        let expandedPath = (path as NSString).expandingTildeInPath

        // First check if directory exists
        guard validateDirectoryPath(path) else {
            return false
        }

        // Check if writable
        return fileManager.isWritableFile(atPath: expandedPath)
    }

    /// Attempts to create a test file to verify write access
    /// - Parameter path: Directory path to test (supports tilde expansion)
    /// - Returns: Result with success or error message
    func testWriteAccess(for path: String) -> Result<Void, PermissionError> {
        let fileManager = FileManager.default
        let expandedPath = (path as NSString).expandingTildeInPath

        // Check if directory exists
        guard validateDirectoryPath(path) else {
            return .failure(.directoryNotFound(expandedPath))
        }

        // Create test file URL
        let testFileName = ".mlx_write_test_\(UUID().uuidString)"
        let testFileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(testFileName)

        do {
            // Try to write test file
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)

            // Clean up test file
            try? fileManager.removeItem(at: testFileURL)

            return .success(())
        } catch {
            return .failure(.noWritePermission(error.localizedDescription))
        }
    }

    /// Validates all path settings have write permissions
    /// - Returns: Dictionary of path labels to error messages (empty if all valid)
    func validateAllPathPermissions() -> [String: String] {
        var errors: [String: String] = [:]

        let pathsToCheck: [(label: String, path: String)] = [
            ("Models Path", modelsPath),
            ("Templates Path", templatesPath),
            ("Conversations Path", conversationsExportPath)
        ]

        for (label, path) in pathsToCheck {
            switch testWriteAccess(for: path) {
            case .failure(let error):
                errors[label] = error.localizedDescription
            case .success:
                break
            }
        }

        return errors
    }

    /// Opens a directory path in Finder
    /// - Parameter path: Path to open (supports tilde expansion)
    func openInFinder(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    /// Sets up observers for auto-saving settings
    private func setupObservers() {
        // Observe scalar settings
        $temperature
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $maxTokens
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $topP
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $topK
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $pythonPath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $theme
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $fontSize
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $enableSyntaxHighlighting
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $enableAutoSave
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $autoSaveInterval
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $maxConversationHistory
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        // Observe model changes
        $selectedModel
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $availableModels
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        // Observe path changes
        $xcodeProjectsPath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $workspacePath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $modelsPath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $templatesPath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $conversationsExportPath
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }
}

// MARK: - AppTheme

/// Application theme preference
enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
}

// MARK: - Memory Safety

extension AppSettings {
    /// Cleans up resources - call this in deinit if needed
    func cleanup() {
        cancellables.removeAll()
    }
}

// MARK: - Permission Error

/// Errors related to directory permissions
enum PermissionError: LocalizedError {
    case directoryNotFound(String)
    case noWritePermission(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory does not exist: \(path)"
        case .noWritePermission(let details):
            return "No write permission: \(details)"
        }
    }
}
