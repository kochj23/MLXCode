//
//  MLXPythonToolkitSettings.swift
//  Universal Python MLX Toolkit Configuration
//
//  Drop this file into any Xcode project to add Python MLX configuration
//  with a status indicator light
//
//  Created on 2025-12-06
//  Author: Jordan Koch
//

import Foundation
import SwiftUI
import Combine

// MARK: - Python MLX Status

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

// MARK: - Settings Manager

/// Python MLX toolkit configuration manager
@MainActor
class MLXPythonToolkitSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = MLXPythonToolkitSettings()

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
        static let pythonPath = "MLXPythonToolkitPath"
        static let mlxPath = "MLXToolkitPath"
        static let autoCheckOnLaunch = "MLXToolkitAutoCheck"
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

        let result = await Task.detached {
            return await self.performMLXCheck()
        }.value

        status = result.status
        pythonVersion = result.pythonVersion
        mlxVersion = result.mlxVersion

        isChecking = false

        print("[MLXPythonToolkit] Status: \(status.rawValue)")
    }

    /// Auto-detect Python and MLX installation
    func autoDetect() async -> Bool {
        print("[MLXPythonToolkit] Auto-detecting...")

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
                print("[MLXPythonToolkit] ✅ Found at: \(path)")
                saveSettings()
                return true
            }
        }

        return false
    }

    /// Install MLX toolkit via pip
    func installMLXToolkit() async -> (success: Bool, output: String) {
        print("[MLXPythonToolkit] Installing...")

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

            let success = process.terminationStatus == 0
            if success {
                await checkMLXAvailability()
            }

            return (success, output + "\n" + errorOutput)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func performMLXCheck() async -> (status: MLXPythonStatus, pythonVersion: String?, mlxVersion: String?) {
        guard FileManager.default.fileExistsAtPath(pythonPath) else {
            return (.pythonNotFound, nil, nil)
        }

        let pythonVer = await runCommand(path: pythonPath, args: ["--version"])
        let mlxCheck = await runCommand(path: pythonPath, args: ["-c", "import mlx.core"])

        guard mlxCheck != nil else {
            return (.mlxNotInstalled, pythonVer, nil)
        }

        let mlxVer = await runCommand(path: pythonPath, args: ["-c", "import mlx.core; print(mlx.core.__version__)"])
        let testImport = await runCommand(path: pythonPath, args: ["-c", "import mlx.core as mx; import mlx.nn as nn; print('OK')"])

        if testImport?.contains("OK") == true {
            return (.available, pythonVer, mlxVer)
        } else {
            return (.error, pythonVer, mlxVer)
        }
    }

    private func runCommand(path: String, args: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        pythonPath = userDefaults.string(forKey: Keys.pythonPath) ?? "/opt/homebrew/bin/python3"
        mlxPath = userDefaults.string(forKey: Keys.mlxPath)
        autoCheckOnLaunch = userDefaults.object(forKey: Keys.autoCheckOnLaunch) as? Bool ?? true
    }

    func saveSettings() {
        userDefaults.set(pythonPath, forKey: Keys.pythonPath)
        if let mlxPath = mlxPath {
            userDefaults.set(mlxPath, forKey: Keys.mlxPath)
        }
        userDefaults.set(autoCheckOnLaunch, forKey: Keys.autoCheckOnLaunch)
    }
}

// MARK: - SwiftUI View

/// Python MLX toolkit settings view with status indicator
struct MLXPythonToolkitSettingsView: View {
    @StateObject private var settings = MLXPythonToolkitSettings.shared
    @State private var showingAutoDetectResult = false
    @State private var autoDetectSuccess = false
    @State private var showingInstallResult = false
    @State private var installOutput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Python MLX Toolkit")
                .font(.headline)

            // Python path
            VStack(alignment: .leading, spacing: 8) {
                Text("Python Executable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Python path", text: $settings.pythonPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse") {
                        browsePythonPath()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Status indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(settings.status.color)
                    .frame(width: 16, height: 16)
                    .shadow(color: settings.status.color.opacity(0.5), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.status.rawValue)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(settings.status.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if settings.isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Version info
            if let pyVer = settings.pythonVersion {
                Text("Python: \(pyVer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let mlxVer = settings.mlxVersion {
                Text("MLX: \(mlxVer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Action buttons
            HStack(spacing: 10) {
                Button("Check Now") {
                    Task { await settings.checkMLXAvailability() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.isChecking)

                Button("Auto-Detect") {
                    Task {
                        autoDetectSuccess = await settings.autoDetect()
                        showingAutoDetectResult = true
                    }
                }
                .buttonStyle(.bordered)
                .disabled(settings.isChecking)

                Button("Install MLX") {
                    Task {
                        let result = await settings.installMLXToolkit()
                        installOutput = result.output
                        showingInstallResult = true
                    }
                }
                .buttonStyle(.bordered)
                .disabled(settings.status == .pythonNotFound || settings.isChecking)
            }

            Toggle("Check on launch", isOn: $settings.autoCheckOnLaunch)
                .font(.subheadline)

            Text("MLX toolkit enables advanced AI features. If not installed, the app will use available alternatives.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .alert("Auto-Detection", isPresented: $showingAutoDetectResult) {
            Button("OK") { }
        } message: {
            Text(autoDetectSuccess ?
                "Found MLX at: \(settings.pythonPath)" :
                "Could not find Python with MLX installed")
        }
        .alert("Installation", isPresented: $showingInstallResult) {
            Button("OK") { }
        } message: {
            Text(installOutput)
        }
    }

    private func browsePythonPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Select Python Executable"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin/")

        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.pythonPath = url.path
                Task {
                    await settings.checkMLXAvailability()
                }
            }
        }
    }
}
