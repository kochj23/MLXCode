//
//  PythonService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for managing Python subprocess execution
/// Handles MLX Python script execution in a secure manner
actor PythonService {
    /// Shared singleton instance
    static let shared = PythonService()

    /// Current running process
    private var currentProcess: Process?

    /// Output pipe for reading stdout
    private var outputPipe: Pipe?

    /// Error pipe for reading stderr
    private var errorPipe: Pipe?

    /// Callback for receiving output
    private var outputCallback: ((String) -> Void)?

    private init() {}

    // MARK: - Public Methods

    /// Executes a Python script asynchronously
    /// - Parameters:
    ///   - scriptPath: Path to the Python script
    ///   - arguments: Command line arguments
    ///   - workingDirectory: Working directory for execution
    ///   - outputHandler: Callback for handling output
    /// - Throws: PythonServiceError if execution fails
    func executeScript(
        at scriptPath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        outputHandler: @escaping (String) -> Void
    ) async throws {
        // Validate script path
        guard SecurityUtils.validateFilePath(scriptPath) else {
            throw PythonServiceError.invalidPath(scriptPath)
        }

        // Expand path
        let expandedPath = (scriptPath as NSString).expandingTildeInPath

        // Verify script exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw PythonServiceError.scriptNotFound(expandedPath)
        }

        // Get Python path from settings
        let pythonPath = await AppSettings.shared.pythonPath
        let expandedPythonPath = (pythonPath as NSString).expandingTildeInPath

        // Verify Python exists
        guard FileManager.default.fileExists(atPath: expandedPythonPath) else {
            throw PythonServiceError.pythonNotFound(expandedPythonPath)
        }

        // Store output callback
        self.outputCallback = outputHandler

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: expandedPythonPath)
        process.arguments = [expandedPath] + arguments

        // Set working directory if provided
        if let workDir = workingDirectory {
            let expandedWorkDir = (workDir as NSString).expandingTildeInPath
            process.currentDirectoryURL = URL(fileURLWithPath: expandedWorkDir)
        }

        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        // Setup output handlers
        setupOutputHandler(pipe: outputPipe, isError: false)
        setupOutputHandler(pipe: errorPipe, isError: true)

        // Store process
        self.currentProcess = process

        // Launch process
        do {
            try process.run()
            await SecureLogger.shared.info("Python script started: \(scriptPath)", category: "PythonService")
        } catch {
            await SecureLogger.shared.error("Failed to launch Python script: \(error.localizedDescription)", category: "PythonService")
            throw PythonServiceError.executionFailed(error)
        }
    }

    /// Executes a Python command and waits for completion
    /// - Parameters:
    ///   - command: Python code to execute
    ///   - timeout: Maximum execution time in seconds
    /// - Returns: Command output
    /// - Throws: PythonServiceError if execution fails
    func executeCommand(_ command: String, timeout: TimeInterval = 30.0) async throws -> String {
        // 🔒 CRITICAL SECURITY: Validate Python code before execution
        let validatedCommand = try CommandValidator.validatePythonCommand(command)

        // Get Python path
        let pythonPath = await AppSettings.shared.pythonPath
        let expandedPythonPath = (pythonPath as NSString).expandingTildeInPath

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: expandedPythonPath)
        process.arguments = ["-c", validatedCommand]

        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Launch process
        try process.run()

        // Wait for completion with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        // Terminate if still running
        if process.isRunning {
            process.terminate()
            throw PythonServiceError.timeout
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        // Check for errors
        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PythonServiceError.commandFailed(errorString)
        }

        let output = String(data: outputData, encoding: .utf8) ?? ""
        return output
    }

    /// Terminates the currently running Python process
    func terminate() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
            currentProcess = nil
            Task {
                await SecureLogger.shared.info("Python process terminated", category: "PythonService")
            }
        }
    }

    /// Checks if a Python process is currently running
    /// - Returns: True if a process is running
    func isRunning() -> Bool {
        return currentProcess?.isRunning ?? false
    }

    // MARK: - Private Methods

    /// Sets up output handler for a pipe
    /// - Parameters:
    ///   - pipe: The pipe to monitor
    ///   - isError: Whether this is the error pipe
    private func setupOutputHandler(pipe: Pipe, isError: Bool) {
        let fileHandle = pipe.fileHandleForReading

        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let output = String(data: data, encoding: .utf8) {
                Task { [weak self] in
                    await self?.handleOutput(output, isError: isError)
                }
            }
        }
    }

    /// Handles output from the Python process
    /// - Parameters:
    ///   - output: The output string
    ///   - isError: Whether this is error output
    private func handleOutput(_ output: String, isError: Bool) async {
        let prefix = isError ? "[ERROR] " : ""
        let formattedOutput = prefix + output

        // Log output
        if isError {
            await SecureLogger.shared.warning("Python stderr: \(output)", category: "PythonService")
        } else {
            await SecureLogger.shared.debug("Python stdout: \(output)", category: "PythonService")
        }

        // Call output callback
        outputCallback?(formattedOutput)
    }

    /// Cleans up resources
    func cleanup() {
        terminate()
        outputPipe = nil
        errorPipe = nil
        outputCallback = nil
    }
}

// MARK: - Error Types

/// Errors that can occur during Python service operations
enum PythonServiceError: LocalizedError {
    case invalidPath(String)
    case scriptNotFound(String)
    case pythonNotFound(String)
    case executionFailed(Error)
    case timeout
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid script path: \(path)"
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .pythonNotFound(let path):
            return "Python executable not found: \(path)"
        case .executionFailed(let error):
            return "Failed to execute Python script: \(error.localizedDescription)"
        case .timeout:
            return "Python command execution timed out"
        case .commandFailed(let message):
            return "Python command failed: \(message)"
        }
    }
}

// MARK: - Python Environment Info

extension PythonService {
    /// Gets information about the Python environment
    /// - Returns: Dictionary containing Python version and path info
    func getPythonInfo() async throws -> [String: String] {
        let versionCommand = "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
        let version = try await executeCommand(versionCommand, timeout: 5.0)

        let pathCommand = "import sys; print(sys.executable)"
        let path = try await executeCommand(pathCommand, timeout: 5.0)

        return [
            "version": version.trimmingCharacters(in: .whitespacesAndNewlines),
            "path": path.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    /// Checks if required Python packages are installed
    /// - Parameter packages: Array of package names to check
    /// - Returns: Dictionary mapping package names to installed status
    func checkPackages(_ packages: [String]) async throws -> [String: Bool] {
        var results: [String: Bool] = [:]

        for package in packages {
            let command = "import importlib.util; print('1' if importlib.util.find_spec('\(package)') else '0')"
            do {
                let output = try await executeCommand(command, timeout: 5.0)
                results[package] = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            } catch {
                results[package] = false
            }
        }

        return results
    }
}
