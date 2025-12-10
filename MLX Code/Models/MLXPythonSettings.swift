//
//  MLXPythonSettings.swift
//  MLX Code
//
//  Python MLX toolkit configuration and health monitoring
//  Created on 2025-12-06
//

import Foundation
import SwiftUI
import Combine

/// Python MLX toolkit status
enum MLXPythonStatus: String, Codable {
    case unknown = "Unknown"
    case available = "Available"
    case pythonNotFound = "Python Not Found"
    case mlxNotInstalled = "MLX Not Installed"
    case error = "Error"

    /// Color for status indicator
    var color: Color {
        switch self {
        case .unknown:
            return .gray
        case .available:
            return .green
        case .pythonNotFound, .error:
            return .red
        case .mlxNotInstalled:
            return .yellow
        }
    }

    /// User-friendly status message
    var message: String {
        switch self {
        case .unknown:
            return "Not checked yet"
        case .available:
            return "MLX toolkit ready"
        case .pythonNotFound:
            return "Python not found at specified path"
        case .mlxNotInstalled:
            return "Python found, but MLX is not installed"
        case .error:
            return "Error checking MLX status"
        }
    }
}

/// Python MLX toolkit configuration manager
@MainActor
class MLXPythonSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = MLXPythonSettings()

    // MARK: - Published Properties

    /// Python executable path
    @Published var pythonPath: String = "/opt/homebrew/bin/python3"

    /// MLX installation path (auto-detected)
    @Published var mlxPath: String?

    /// Current status
    @Published var status: MLXPythonStatus = .unknown

    /// Python version
    @Published var pythonVersion: String?

    /// MLX version
    @Published var mlxVersion: String?

    /// Last check timestamp
    @Published var lastCheckTime: Date?

    /// Auto-check on launch
    @Published var autoCheckOnLaunch: Bool = true

    /// Currently checking
    @Published var isChecking: Bool = false

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let pythonPath = "MLXPythonPath"
        static let mlxPath = "MLXPath"
        static let autoCheckOnLaunch = "MLXAutoCheckOnLaunch"
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupObservers()

        if autoCheckOnLaunch {
            Task {
                await checkMLXAvailability()
            }
        }
    }

    private func setupObservers() {
        // Save settings when they change
        $pythonPath
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)

        $autoCheckOnLaunch
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Check MLX availability asynchronously
    func checkMLXAvailability() async {
        isChecking = true
        lastCheckTime = Date()

        // Check in background
        let result = await Task.detached {
            return await self.performMLXCheck()
        }.value

        status = result.status
        pythonVersion = result.pythonVersion
        mlxVersion = result.mlxVersion

        isChecking = false

        print("[MLXPython] Status check complete: \(status.rawValue)")
    }

    /// Auto-detect Python and MLX installation
    func autoDetect() async -> Bool {
        print("[MLXPython] Starting auto-detection...")

        let commonPaths = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/opt/anaconda3/bin/python",
            "/opt/miniconda3/bin/python",
            "\(NSHomeDirectory())/.pyenv/shims/python"
        ]

        for path in commonPaths {
            pythonPath = path
            await checkMLXAvailability()

            if status == .available {
                print("[MLXPython] ✅ Found working Python with MLX at: \(path)")
                saveSettings()
                return true
            }
        }

        print("[MLXPython] ❌ Auto-detection failed")
        return false
    }

    /// Install MLX toolkit via pip
    func installMLXToolkit() async -> (success: Bool, output: String) {
        print("[MLXPython] Installing MLX toolkit...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-m", "pip", "install", "mlx"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let fullOutput = output + "\n" + errorOutput

            let success = process.terminationStatus == 0

            if success {
                print("[MLXPython] ✅ MLX installed successfully")
                await checkMLXAvailability()
            } else {
                print("[MLXPython] ❌ MLX installation failed")
            }

            return (success, fullOutput)
        } catch {
            print("[MLXPython] Exception installing MLX: \(error)")
            return (false, error.localizedDescription)
        }
    }

    /// Reset to default Python path
    func resetToDefault() {
        pythonPath = "/opt/homebrew/bin/python3"
        saveSettings()
    }

    // MARK: - Private Methods

    private func performMLXCheck() async -> (status: MLXPythonStatus, pythonVersion: String?, mlxVersion: String?) {
        // Check if Python exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: pythonPath) else {
            print("[MLXPython] ❌ Python not found at: \(pythonPath)")
            return (.pythonNotFound, nil, nil)
        }

        print("[MLXPython] ✓ Python found at: \(pythonPath)")

        // Get Python version
        let pythonVer = await runCommand(path: pythonPath, args: ["--version"])
        print("[MLXPython] Python version: \(pythonVer ?? "Unknown")")

        // Check if MLX is installed
        let mlxCheck = await runCommand(path: pythonPath, args: ["-c", "import mlx.core"])
        guard mlxCheck != nil else {
            print("[MLXPython] ⚠️ MLX toolkit not installed")
            return (.mlxNotInstalled, pythonVer, nil)
        }

        // Get MLX version
        let mlxVer = await runCommand(path: pythonPath, args: ["-c", "import mlx.core; print(mlx.core.__version__)"])
        print("[MLXPython] ✓ MLX version: \(mlxVer ?? "Unknown")")

        // Test MLX import
        let testImport = await runCommand(path: pythonPath, args: ["-c", "import mlx.core as mx; import mlx.nn as nn; print('OK')"])

        if testImport?.contains("OK") == true {
            print("[MLXPython] ✅ MLX toolkit is working!")
            return (.available, pythonVer, mlxVer)
        } else {
            print("[MLXPython] ❌ MLX import test failed")
            return (.error, pythonVer, mlxVer)
        }
    }

    private func runCommand(path: String, args: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                return nil
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return output
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        pythonPath = userDefaults.string(forKey: Keys.pythonPath) ?? "/opt/homebrew/bin/python3"
        mlxPath = userDefaults.string(forKey: Keys.mlxPath)
        autoCheckOnLaunch = userDefaults.bool(forKey: Keys.autoCheckOnLaunch)

        // Set default if not previously saved
        if userDefaults.object(forKey: Keys.autoCheckOnLaunch) == nil {
            autoCheckOnLaunch = true
        }

        print("[MLXPython] Settings loaded: Python=\(pythonPath)")
    }

    func saveSettings() {
        userDefaults.set(pythonPath, forKey: Keys.pythonPath)

        if let mlxPath = mlxPath {
            userDefaults.set(mlxPath, forKey: Keys.mlxPath)
        }

        userDefaults.set(autoCheckOnLaunch, forKey: Keys.autoCheckOnLaunch)

        print("[MLXPython] Settings saved")
    }
}

/// App theme preference
enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}
