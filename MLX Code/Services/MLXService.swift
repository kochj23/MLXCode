//
//  MLXService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for interacting with MLX language models
/// Manages model loading, inference, and streaming responses via Python bridge
actor MLXService {
    /// Shared singleton instance
    static let shared = MLXService()

    /// Currently loaded model
    private var loadedModel: MLXModel?

    /// Whether a model is currently loaded
    private var isModelLoaded = false

    /// Whether inference is currently running
    private var isInferenceRunning = false

    /// Python daemon process for persistent MLX inference
    private var daemonProcess: Process?

    /// Input pipe to daemon process
    private var inputPipe: Pipe?

    /// Output pipe from daemon process
    private var outputPipe: Pipe?

    /// Buffer for reading daemon output
    private var outputBuffer = Data()

    /// Queue for processing daemon responses
    private var responseQueue: [PythonResponse] = []

    /// Whether the daemon is running and healthy
    private var isDaemonRunning = false

    /// Daemon health check task
    private var healthCheckTask: Task<Void, Never>?

    private init() {
        // Start daemon on init
        Task {
            try? await startDaemon()
        }
    }

    // MARK: - Model Management

    /// Loads an MLX model
    /// - Parameter model: The model to load
    /// - Throws: MLXServiceError if loading fails
    func loadModel(_ model: MLXModel) async throws {
        print("🔵🔵🔵 MLXService.loadModel() called for: \(model.name)")
        await LogManager.shared.info("Loading model: \(model.name)", category: "MLX")
        await SecureLogger.shared.info("🔵 loadModel() called for: \(model.name)", category: "MLXService")

        // Validate model
        print("🔍🔍🔍 Validating model...")
        guard model.isValid() else {
            print("❌❌❌ Model validation FAILED")
            await SecureLogger.shared.error("❌ Model validation failed", category: "MLXService")
            throw MLXServiceError.invalidModel
        }

        print("✅✅✅ Model validation passed")
        await SecureLogger.shared.info("✅ Model validation passed", category: "MLXService")

        guard model.isDownloaded else {
            print("❌❌❌ Model not downloaded")
            await SecureLogger.shared.error("❌ Model not downloaded", category: "MLXService")
            throw MLXServiceError.modelNotDownloaded
        }

        print("✅✅✅ Model is marked as downloaded")
        await SecureLogger.shared.info("✅ Model is marked as downloaded", category: "MLXService")

        // Expand model path
        let expandedPath = (model.path as NSString).expandingTildeInPath
        print("📁📁📁 Expanded path: \(expandedPath)")
        await SecureLogger.shared.info("📁 Expanded path: \(expandedPath)", category: "MLXService")

        // Verify model directory exists
        var isDirectory: ObjCBool = false
        let directoryExists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        print("🔍🔍🔍 Directory check - exists: \(directoryExists), isDirectory: \(isDirectory.boolValue)")
        await SecureLogger.shared.info("🔍 Directory check - exists: \(directoryExists), isDirectory: \(isDirectory.boolValue)", category: "MLXService")

        guard directoryExists, isDirectory.boolValue else {
            print("❌❌❌ Model directory not found or not a directory: \(expandedPath)")
            await SecureLogger.shared.error("❌ Model directory not found or not a directory: \(expandedPath)", category: "MLXService")
            throw MLXServiceError.modelNotFound(expandedPath)
        }

        print("✅✅✅ Model directory exists and is valid")
        await SecureLogger.shared.info("✅ Model directory exists and is valid", category: "MLXService")

        // Verify model has required files (config.json as indicator)
        let configPath = (expandedPath as NSString).appendingPathComponent("config.json")
        let configExists = FileManager.default.fileExists(atPath: configPath)

        print("🔍🔍🔍 Config check - exists: \(configExists) at: \(configPath)")
        await SecureLogger.shared.info("🔍 Config check - exists: \(configExists) at: \(configPath)", category: "MLXService")

        guard configExists else {
            print("❌❌❌ Config file missing: \(configPath)")
            await SecureLogger.shared.error("❌ Config file missing: \(configPath)", category: "MLXService")
            throw MLXServiceError.modelNotFound("\(expandedPath) (config.json missing)")
        }

        print("✅✅✅ Config file found")
        await SecureLogger.shared.info("✅ Config file found", category: "MLXService")

        // Start daemon if not running
        print("🔄🔄🔄 Starting daemon...")
        await SecureLogger.shared.info("🔄 Starting daemon...", category: "MLXService")
        try await startDaemon()
        print("✅✅✅ Daemon ready")
        await SecureLogger.shared.info("✅ Daemon ready", category: "MLXService")

        // Send load command to Python
        let loadCommand: [String: Any] = [
            "type": "load_model",
            "model_path": expandedPath
        ]

        print("📤📤📤 Sending to daemon - model_path: '\(expandedPath)'")
        await SecureLogger.shared.info("📤 Sending load_model command with path: '\(expandedPath)'", category: "MLXService")
        try await sendDaemonCommand(loadCommand)
        await SecureLogger.shared.info("✅ Load command sent", category: "MLXService")

        // Wait for response (may receive debug messages first)
        await SecureLogger.shared.info("⏳ Waiting for daemon load response...", category: "MLXService")
        var finalResponse: PythonResponse?

        // Read responses until we get the final load result
        while finalResponse == nil {
            let response = try await readDaemonResponse()

            if response.type == "debug" {
                // Log debug messages from daemon
                if let message = response.message {
                    print("🐛 Daemon debug: \(message)")
                    await SecureLogger.shared.info("🐛 Daemon: \(message)", category: "MLXService")
                }
            } else if response.success != nil {
                // This is the load response (has success field, no type field)
                finalResponse = response
            } else if response.type != nil {
                // Other typed response
                finalResponse = response
            }
        }

        let response = finalResponse!
        await SecureLogger.shared.info("📥 Received load response - success: \(response.success ?? false), cached: \(response.cached ?? false)", category: "MLXService")

        guard response.success == true else {
            let errorMsg = response.error ?? "Unknown error loading model"
            await LogManager.shared.error("Model load failed: \(errorMsg)", category: "MLX")
            await SecureLogger.shared.error("❌ Model load failed: \(errorMsg)", category: "MLXService")
            throw MLXServiceError.generationFailed(errorMsg)
        }

        loadedModel = model
        isModelLoaded = true

        await LogManager.shared.info("Model loaded successfully: \(model.name)", category: "MLX")
        await SecureLogger.shared.info("✅ MLX model loaded successfully: \(model.name)", category: "MLXService")
    }

    /// Unloads the currently loaded model
    func unloadModel() async {
        guard isModelLoaded else { return }

        await SecureLogger.shared.info("Unloading MLX model", category: "MLXService")

        do {
            let unloadCommand: [String: Any] = [
                "type": "unload_model"
            ]

            try await sendDaemonCommand(unloadCommand)
            _ = try await readDaemonResponse()
        } catch {
            await SecureLogger.shared.warning("Error unloading model: \(error.localizedDescription)", category: "MLXService")
        }

        loadedModel = nil
        isModelLoaded = false

        await SecureLogger.shared.info("MLX model unloaded", category: "MLXService")
    }

    /// Gets the currently loaded model
    /// - Returns: The loaded model, or nil if none is loaded
    func getCurrentModel() -> MLXModel? {
        return loadedModel
    }

    /// Checks if a model is currently loaded
    /// - Returns: True if a model is loaded
    func isLoaded() -> Bool {
        return isModelLoaded
    }

    // MARK: - Inference

    /// Generates text completion from the model
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - parameters: Generation parameters (uses model defaults if nil)
    ///   - streamHandler: Optional callback for streaming tokens
    /// - Returns: Generated text
    /// - Throws: MLXServiceError if generation fails
    func generate(
        prompt: String,
        parameters: ModelParameters? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        await SecureLogger.shared.info("🟢 generate() called with prompt length: \(prompt.count)", category: "MLXService")

        // Ensure model is loaded
        guard isModelLoaded, let model = loadedModel else {
            await SecureLogger.shared.error("❌ No model loaded", category: "MLXService")
            throw MLXServiceError.noModelLoaded
        }

        await SecureLogger.shared.info("✅ Model is loaded: \(model.name)", category: "MLXService")

        // Prevent concurrent inference
        guard !isInferenceRunning else {
            await SecureLogger.shared.warning("⚠️ Inference already in progress", category: "MLXService")
            throw MLXServiceError.inferenceInProgress
        }

        await SecureLogger.shared.info("✅ No concurrent inference, proceeding", category: "MLXService")

        isInferenceRunning = true
        defer { isInferenceRunning = false }

        // Sanitize prompt
        let sanitizedPrompt = SecurityUtils.sanitizeUserInput(prompt)
        await SecureLogger.shared.info("✅ Prompt sanitized", category: "MLXService")

        // Use provided parameters or model defaults
        let genParams = parameters ?? model.parameters
        await SecureLogger.shared.info("📊 Parameters: temp=\(genParams.temperature), max_tokens=\(genParams.maxTokens)", category: "MLXService")

        // Validate parameters
        guard genParams.isValid() else {
            await SecureLogger.shared.error("❌ Invalid parameters", category: "MLXService")
            throw MLXServiceError.invalidParameters
        }

        await SecureLogger.shared.info("✅ Parameters validated", category: "MLXService")
        await SecureLogger.shared.info("🚀 Starting inference...", category: "MLXService")

        // Send generate command to Python
        let generateCommand: [String: Any] = [
            "type": "generate",
            "prompt": sanitizedPrompt,
            "max_tokens": genParams.maxTokens,
            "temperature": genParams.temperature,
            "top_p": genParams.topP,
            "repetition_penalty": genParams.repetitionPenalty,
            "stream": streamHandler != nil
        ]

        await SecureLogger.shared.info("📤 Sending generate command to daemon...", category: "MLXService")
        try await sendDaemonCommand(generateCommand)
        await SecureLogger.shared.info("✅ Command sent to daemon", category: "MLXService")

        var fullResponse = ""

        // Read streaming responses
        await SecureLogger.shared.info("👂 Listening for daemon responses...", category: "MLXService")
        while true {
            let response = try await readDaemonResponse()
            await SecureLogger.shared.info("📥 Received response type: \(response.type ?? "nil")", category: "MLXService")

            if response.type == "token" {
                // Streaming token
                if let token = response.token {
                    fullResponse += token
                    await SecureLogger.shared.info("🔹 Token received (length: \(token.count))", category: "MLXService")
                    streamHandler?(token)
                }
            } else if response.type == "complete" {
                // Generation complete - DON'T overwrite accumulated tokens!
                await SecureLogger.shared.info("✅ Complete signal received, total response length: \(fullResponse.count)", category: "MLXService")
                break
            } else if response.type == "done" {
                // Generation complete (alternate signal)
                await SecureLogger.shared.info("✅ Generation done signal received", category: "MLXService")
                break
            } else if response.error != nil {
                await SecureLogger.shared.error("❌ Python error: \(response.error!)", category: "MLXService")
                throw MLXServiceError.generationFailed(response.error!)
            }
        }

        await SecureLogger.shared.info("✅ Inference completed, response length: \(fullResponse.count)", category: "MLXService")

        return fullResponse
    }

    /// Generates a chat completion
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - parameters: Generation parameters
    ///   - streamHandler: Optional callback for streaming tokens
    /// - Returns: Generated assistant message
    /// - Throws: MLXServiceError if generation fails
    func chatCompletion(
        messages: [Message],
        parameters: ModelParameters? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        await SecureLogger.shared.info("🔵 chatCompletion() called with \(messages.count) messages", category: "MLXService")

        // Convert messages to prompt format
        let prompt = formatMessagesAsPrompt(messages)
        await SecureLogger.shared.info("✅ Formatted prompt (length: \(prompt.count) chars)", category: "MLXService")
        await SecureLogger.shared.info("📝 Prompt preview: \(prompt.prefix(200))...", category: "MLXService")

        // Generate response
        await SecureLogger.shared.info("🔄 Calling generate() with prompt...", category: "MLXService")
        let result = try await generate(
            prompt: prompt,
            parameters: parameters,
            streamHandler: streamHandler
        )

        await SecureLogger.shared.info("✅ chatCompletion() returning response (length: \(result.count))", category: "MLXService")
        return result
    }

    // MARK: - Model Discovery

    /// Discovers available MLX models on the system
    /// - Returns: Array of discovered models
    func discoverModels() async throws -> [MLXModel] {
        await SecureLogger.shared.info("Discovering MLX models", category: "MLXService")

        var discoveredModels: [MLXModel] = []

        // Get models path from settings
        let settingsModelsPath = await AppSettings.shared.modelsPath
        let expandedModelsPath = (settingsModelsPath as NSString).expandingTildeInPath

        // Common model directories (try all potential locations)
        let searchPaths = [
            expandedModelsPath,                                      // User's configured path
            "~/.mlx/models",                                         // Original default
            "~/Documents/MLXCode/models",                           // Work machine friendly
            "~/Library/Application Support/MLXCode/models",         // Standard macOS location
            "\(NSTemporaryDirectory())MLXCode/models"               // Fallback location
        ]

        for path in searchPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)

            guard FileManager.default.fileExists(atPath: expandedPath) else {
                continue
            }

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )

                for item in contents {
                    if let model = try? await parseModelDirectory(item) {
                        discoveredModels.append(model)
                    }
                }
            } catch {
                await SecureLogger.shared.warning("Failed to scan directory \(path): \(error.localizedDescription)", category: "MLXService")
            }
        }

        await SecureLogger.shared.info("Discovered \(discoveredModels.count) models", category: "MLXService")

        return discoveredModels
    }

    // MARK: - Daemon Management

    /// Starts the persistent MLX daemon
    private func startDaemon() async throws {
        await SecureLogger.shared.info("🟣 startDaemon() called", category: "MLXService")

        // Check if already running
        if let process = daemonProcess, process.isRunning, isDaemonRunning {
            await SecureLogger.shared.info("✅ Daemon already running (PID: \(process.processIdentifier))", category: "MLXService")
            return
        }

        await SecureLogger.shared.info("🔍 Getting daemon script path...", category: "MLXService")

        // Get daemon script path (use mlx_daemon.py instead of mlx_inference.py)
        let scriptPath = getDaemonScriptPath()
        await SecureLogger.shared.info("📝 Daemon script path: \(scriptPath)", category: "MLXService")

        // Check if path is empty
        if scriptPath.isEmpty {
            await SecureLogger.shared.error("❌ Daemon script path is EMPTY!", category: "MLXService")
            await SecureLogger.shared.error("❌ Bundle path: \(Bundle.main.bundlePath)", category: "MLXService")
            await SecureLogger.shared.error("❌ Resource path: \(Bundle.main.resourcePath ?? "nil")", category: "MLXService")

            // Try to list Python directory
            let devPath = "/Volumes/Data/xcode/MLX Code/Python"
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: devPath) {
                await SecureLogger.shared.info("📁 Dev Python dir contents: \(contents.joined(separator: ", "))", category: "MLXService")
            }

            throw MLXServiceError.generationFailed("Daemon script path is empty")
        }

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            await SecureLogger.shared.error("❌ Daemon script not found at: \(scriptPath)", category: "MLXService")
            throw MLXServiceError.generationFailed("Daemon script not found at: \(scriptPath)")
        }

        await SecureLogger.shared.info("✅ Daemon script file exists", category: "MLXService")

        // Create process
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()  // Separate stderr to avoid mixing with JSON

        // Use actual Xcode Python binary (not the xcode-select shim at /usr/bin/python3)
        // The shim calls xcrun which is forbidden in App Sandbox
        let pythonPath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]  // Daemon doesn't need --mode flag
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set environment with PYTHONPATH so Python can find user packages
        var env = ProcessInfo.processInfo.environment

        // CRITICAL: Add PYTHONPATH so Python can find user-installed packages (mlx, huggingface-hub, etc)
        let userSitePackages = "/Users/\(NSUserName())/Library/Python/3.9/lib/python/site-packages"
        env["PYTHONPATH"] = userSitePackages

        await SecureLogger.shared.info("🔧 Daemon: Environment with PYTHONPATH: \(userSitePackages)", category: "MLXService")

        process.environment = env

        // Set working directory
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        await SecureLogger.shared.info("📋 Daemon command: /usr/bin/python3 \(scriptPath)", category: "MLXService")
        await SecureLogger.shared.info("🌍 Environment PYTHONPATH: \(process.environment?["PYTHONPATH"] ?? "none")", category: "MLXService")
        await SecureLogger.shared.info("🏠 Working directory: \(FileManager.default.homeDirectoryForCurrentUser.path)", category: "MLXService")

        // Store pipes
        self.daemonProcess = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe

        // Monitor stderr in background to log daemon warnings/errors
        Task {
            let errorHandle = errorPipe.fileHandleForReading
            while true {
                let data = errorHandle.availableData
                if data.count > 0, let errorMsg = String(data: data, encoding: .utf8) {
                    await SecureLogger.shared.warning("⚠️ Daemon stderr: \(errorMsg)", category: "MLXService")
                    print("⚠️⚠️⚠️ Daemon stderr: \(errorMsg)")
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Start daemon
        await SecureLogger.shared.info("🚀 Starting daemon process...", category: "MLXService")
        try process.run()
        await SecureLogger.shared.info("✅ Daemon process started (PID: \(process.processIdentifier))", category: "MLXService")

        // Wait for ready signal
        await SecureLogger.shared.info("⏳ Waiting for daemon 'ready' signal...", category: "MLXService")
        let response = try await readDaemonResponse()
        await SecureLogger.shared.info("📥 Received response type: \(response.type ?? "nil")", category: "MLXService")

        guard response.type == "ready" else {
            await SecureLogger.shared.error("❌ Daemon failed to send ready signal. Got: \(response.type ?? "nil")", category: "MLXService")
            throw MLXServiceError.generationFailed("Daemon failed to start")
        }

        isDaemonRunning = true
        await SecureLogger.shared.info("✅ Daemon started successfully and is ready", category: "MLXService")

        // Start health monitoring
        startHealthMonitoring()
    }

    /// Monitors daemon health and restarts if needed
    private func startHealthMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                // Check if daemon is still running
                if let process = daemonProcess {
                    if !process.isRunning {
                        await SecureLogger.shared.warning("⚠️ Daemon process died, restarting...", category: "MLXService")
                        isDaemonRunning = false
                        try? await startDaemon()
                    }
                }
            }
        }
    }

    /// Stops the daemon gracefully
    private func stopDaemon() async {
        guard let process = daemonProcess, process.isRunning else {
            return
        }

        await SecureLogger.shared.info("Stopping daemon", category: "MLXService")

        // Cancel health monitoring
        healthCheckTask?.cancel()
        healthCheckTask = nil

        // Send shutdown command
        do {
            let shutdownCommand: [String: Any] = ["type": "shutdown"]
            try await sendDaemonCommand(shutdownCommand)
        } catch {
            await SecureLogger.shared.warning("Failed to send shutdown command: \(error.localizedDescription)", category: "MLXService")
        }

        // Wait briefly for graceful shutdown
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Terminate process if still running
        if process.isRunning {
            process.terminate()
        }

        daemonProcess = nil
        inputPipe = nil
        outputPipe = nil
        isDaemonRunning = false

        await SecureLogger.shared.info("Daemon stopped", category: "MLXService")
    }

    /// Sends a command to daemon process
    private func sendDaemonCommand(_ command: [String: Any]) async throws {
        guard let inputPipe = inputPipe else {
            throw MLXServiceError.generationFailed("Daemon not running")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: command)
        var commandString = String(data: jsonData, encoding: .utf8) ?? ""
        commandString += "\n"

        guard let data = commandString.data(using: .utf8) else {
            throw MLXServiceError.generationFailed("Failed to encode command")
        }

        inputPipe.fileHandleForWriting.write(data)
    }

    /// Reads a response from daemon process
    private func readDaemonResponse() async throws -> PythonResponse {
        guard let outputPipe = outputPipe else {
            await SecureLogger.shared.error("❌ readDaemonResponse: outputPipe is nil", category: "MLXService")
            throw MLXServiceError.generationFailed("Daemon not running")
        }

        // Read line by line
        let handle = outputPipe.fileHandleForReading

        // Read until newline
        var line = Data()
        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                await SecureLogger.shared.error("❌ readDaemonResponse: EOF reached, daemon closed", category: "MLXService")
                throw MLXServiceError.generationFailed("Daemon closed unexpectedly")
            }

            if byte.first == UInt8(ascii: "\n") {
                break
            }

            line.append(byte)
        }

        // Log raw JSON received
        if let jsonString = String(data: line, encoding: .utf8) {
            await SecureLogger.shared.info("📥 Raw JSON from daemon: \(jsonString)", category: "MLXService")
        } else {
            await SecureLogger.shared.warning("⚠️ Could not decode line as UTF-8, bytes: \(line.count)", category: "MLXService")
        }

        // Log raw data BEFORE parsing
        if let rawString = String(data: line, encoding: .utf8) {
            print("🔍🔍🔍 RAW JSON FROM DAEMON: \(rawString)")
            await SecureLogger.shared.info("📥 Raw daemon response: \(rawString)", category: "MLXService")
        } else {
            print("❌❌❌ CANNOT DECODE DATA AS STRING")
            await SecureLogger.shared.error("❌ Cannot decode response as UTF-8 string", category: "MLXService")
        }

        // Parse JSON
        do {
            let response = try JSONDecoder().decode(PythonResponse.self, from: line)
            print("✅✅✅ JSON DECODED: type=\(response.type ?? "nil"), success=\(response.success ?? false)")
            await SecureLogger.shared.info("✅ Successfully decoded response: type=\(response.type ?? "nil")", category: "MLXService")
            return response
        } catch {
            print("❌❌❌ JSON DECODE ERROR: \(error)")
            await SecureLogger.shared.error("❌ JSON decode error: \(error)", category: "MLXService")
            if let jsonString = String(data: line, encoding: .utf8) {
                print("❌❌❌ FAILED JSON WAS: \(jsonString)")
                await SecureLogger.shared.error("❌ Failed JSON was: \(jsonString)", category: "MLXService")
            }
            throw error
        }
    }

    /// Gets the path to a Python script
    /// - Parameter scriptName: Name of the script without extension
    /// - Returns: Full path to the script
    private func getPythonScriptPath(scriptName: String) -> String? {
        // Try bundle resource first
        if let bundlePath = Bundle.main.path(forResource: scriptName, ofType: "py") {
            return bundlePath
        }

        // Fall back to development directory
        let projectPath = "/Volumes/Data/xcode/MLX Code/Python/\(scriptName).py"
        if FileManager.default.fileExists(atPath: projectPath) {
            return projectPath
        }

        return nil
    }

    /// Gets the path to the daemon script
    private func getDaemonScriptPath() -> String {
        return getPythonScriptPath(scriptName: "mlx_daemon") ?? ""
    }

    /// Gets the path to the Python inference script (for compatibility)
    private func getPythonScriptPath() -> String {
        return getPythonScriptPath(scriptName: "mlx_inference") ?? ""
    }

    // MARK: - Private Methods

    /// Formats chat messages into a prompt string
    /// - Parameter messages: Array of messages
    /// - Returns: Formatted prompt string
    private func formatMessagesAsPrompt(_ messages: [Message]) -> String {
        var prompt = ""

        for message in messages {
            let rolePrefix: String
            switch message.role {
            case .system:
                rolePrefix = "System: "
            case .user:
                rolePrefix = "User: "
            case .assistant:
                rolePrefix = "Assistant: "
            }

            prompt += rolePrefix + message.content + "\n\n"
        }

        // Add assistant prefix for next response
        prompt += "Assistant: "

        return prompt
    }

    /// Parses a model directory to extract model information
    /// - Parameter url: Directory URL
    /// - Returns: MLXModel if valid, nil otherwise
    private func parseModelDirectory(_ url: URL) async throws -> MLXModel? {
        let fileManager = FileManager.default

        // Check if directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        // Look for model files (e.g., config.json, model weights)
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

        // Check for config.json
        guard contents.contains(where: { $0.lastPathComponent == "config.json" }) else {
            return nil
        }

        // Calculate total size
        var totalSize: Int64 = 0
        for file in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        // Create model
        let modelName = url.lastPathComponent
        return MLXModel(
            name: modelName,
            path: url.path,
            parameters: ModelParameters(),
            isDownloaded: true,
            sizeInBytes: totalSize
        )
    }
}

// MARK: - Daemon Response

/// Response structure from daemon
private struct PythonResponse: Codable {
    let type: String?  // OPTIONAL - load responses don't include type
    let success: Bool?
    let error: String?
    let message: String?
    let token: String?
    let text: String?
    let cached: Bool?  // Whether model was loaded from cache
    let path: String?  // Model path from load response
    let name: String?  // Model name from load response
    let stage: String?  // Progress stage from download
    let skipped: Bool?  // Whether download was skipped (already exists)
    let repo_id: String?  // HuggingFace repo ID
    let size_bytes: Int?  // Model size in bytes
    let size_gb: Double?  // Model size in GB
    let quantization: String?  // Quantization level
    let converted_to_mlx: Bool?  // Whether model was converted
}

// MARK: - Error Types

/// Errors that can occur during MLX service operations
enum MLXServiceError: LocalizedError {
    case invalidModel
    case modelNotDownloaded
    case modelNotFound(String)
    case noModelLoaded
    case inferenceInProgress
    case invalidParameters
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidModel:
            return "The model configuration is invalid"
        case .modelNotDownloaded:
            return "The model has not been downloaded"
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .noModelLoaded:
            return "No model is currently loaded"
        case .inferenceInProgress:
            return "An inference operation is already in progress"
        case .invalidParameters:
            return "The generation parameters are invalid"
        case .generationFailed(let message):
            return "Text generation failed: \(message)"
        }
    }
}

// MARK: - Model Download

extension MLXService {
    /// Downloads a model from HuggingFace
    /// - Parameters:
    ///   - model: The model to download
    ///   - progressHandler: Optional callback for download progress (0.0 to 1.0)
    /// - Returns: Updated model with correct path
    /// - Throws: MLXServiceError if download fails
    func downloadModel(
        _ model: MLXModel,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> MLXModel {
        guard let huggingFaceId = model.huggingFaceId else {
            throw MLXServiceError.generationFailed("Model does not have a HuggingFace ID")
        }

        await SecureLogger.shared.info("Starting download of model: \(model.name)", category: "MLXService")

        // Determine actual download path from settings
        let fileManager = FileManager.default

        // Get models path from settings (supports tilde expansion)
        let settingsModelsPath = await AppSettings.shared.modelsPath
        let expandedModelsPath = (settingsModelsPath as NSString).expandingTildeInPath
        let modelsDirectory = URL(fileURLWithPath: expandedModelsPath)

        // Create directory if needed
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Model will be saved to this path
        let modelDirectory = modelsDirectory.appendingPathComponent(model.fileName)
        let actualPath = modelDirectory.path

        await SecureLogger.shared.info("Download target path: \(actualPath)", category: "MLXService")
        await SecureLogger.shared.info("Using models path from settings: \(settingsModelsPath)", category: "MLXService")

        // Get Python downloader script path
        await SecureLogger.shared.info("🔍 Looking for huggingface_downloader script...", category: "MLXService")

        // Try bundle first
        if let bundlePath = Bundle.main.path(forResource: "huggingface_downloader", ofType: "py") {
            await SecureLogger.shared.info("✅ Found script in bundle: \(bundlePath)", category: "MLXService")
        } else {
            await SecureLogger.shared.warning("⚠️ Script NOT found in bundle resources", category: "MLXService")
        }

        guard let scriptPath = getPythonScriptPath(scriptName: "huggingface_downloader") else {
            await SecureLogger.shared.error("❌ CRITICAL: Downloader script not found in bundle or development path", category: "MLXService")
            await SecureLogger.shared.error("Bundle.main.resourcePath: \(Bundle.main.resourcePath ?? "nil")", category: "MLXService")
            await SecureLogger.shared.error("Bundle.main.bundlePath: \(Bundle.main.bundlePath)", category: "MLXService")
            throw MLXServiceError.generationFailed("Downloader script not found in bundle or development path")
        }

        await SecureLogger.shared.info("✅ Using downloader script at: \(scriptPath)", category: "MLXService")

        // Verify script exists
        let fileExists = FileManager.default.fileExists(atPath: scriptPath)
        await SecureLogger.shared.info("Script file exists check: \(fileExists)", category: "MLXService")

        if !fileExists {
            await SecureLogger.shared.error("❌ Script path returned but file doesn't exist!", category: "MLXService")
            throw MLXServiceError.generationFailed("Script file not accessible at path: \(scriptPath)")
        }

        // Use actual Xcode Python binary (not the xcode-select shim at /usr/bin/python3)
        // The shim calls xcrun which is forbidden in App Sandbox
        let pythonPath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"
        let pythonExists = FileManager.default.fileExists(atPath: pythonPath)
        await SecureLogger.shared.info("Python exists at \(pythonPath): \(pythonExists)", category: "MLXService")

        guard pythonExists else {
            await SecureLogger.shared.error("❌ Python binary not found at: \(pythonPath)", category: "MLXService")
            throw MLXServiceError.generationFailed("Python 3.9 not found. Please install Xcode and Command Line Tools.")
        }

        // Create process to download
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)

        // Detect if model is already in MLX format (mlx-community models don't need conversion)
        let needsConversion = !huggingFaceId.lowercased().contains("mlx-community")

        var arguments = [
            scriptPath,
            "download",
            huggingFaceId,
            "--output", actualPath
        ]

        // Skip conversion for mlx-community models (already in MLX format)
        if !needsConversion {
            arguments.append("--no-convert")
            await SecureLogger.shared.info("✅ Model is from mlx-community, skipping conversion", category: "MLXService")
        } else {
            arguments.append("--quantize")
            arguments.append("4bit")
            await SecureLogger.shared.info("⚙️ Model needs conversion, will quantize to 4bit", category: "MLXService")
        }

        process.arguments = arguments

        // Set environment with PYTHONPATH so Python can find user packages
        var env = ProcessInfo.processInfo.environment

        // CRITICAL: Add PYTHONPATH so Python can find user-installed packages (mlx, huggingface-hub, etc)
        let userSitePackages = "/Users/\(NSUserName())/Library/Python/3.9/lib/python/site-packages"
        env["PYTHONPATH"] = userSitePackages

        await SecureLogger.shared.info("🔧 Download: Environment with PYTHONPATH: \(userSitePackages)", category: "MLXService")

        process.environment = env

        // Set working directory to home
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        process.currentDirectoryURL = homeDir

        await SecureLogger.shared.info("📝 Command: \(pythonPath) \(process.arguments!.joined(separator: " "))", category: "MLXService")
        await SecureLogger.shared.info("🏠 Working directory: \(homeDir.path)", category: "MLXService")
        await SecureLogger.shared.info("🌍 Environment PATH: \(process.environment?["PATH"] ?? "none")", category: "MLXService")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Start download
        await SecureLogger.shared.info("🚀 Starting download process...", category: "MLXService")
        do {
            try process.run()
            await SecureLogger.shared.info("✅ Process started successfully, PID: \(process.processIdentifier)", category: "MLXService")
        } catch {
            await SecureLogger.shared.error("❌ Failed to start process: \(error.localizedDescription)", category: "MLXService")
            throw error
        }

        // Capture all output in separate buffers (thread-safe with DispatchQueue)
        let outputQueue = DispatchQueue(label: "com.mlxcode.output", attributes: .concurrent)
        let errorQueue = DispatchQueue(label: "com.mlxcode.error", attributes: .concurrent)
        var allOutput = Data()
        var allErrors = Data()

        // Read stdout for progress updates
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                // Store all output (thread-safe)
                outputQueue.async(flags: .barrier) {
                    allOutput.append(data)
                }

                // Log real-time output
                if let output = String(data: data, encoding: .utf8) {
                    Task {
                        await SecureLogger.shared.info("📥 Python stdout: \(output)", category: "MLXService")
                    }

                    // Parse progress if JSON
                    if let jsonData = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "progress" {
                        // Could parse progress percentage if available
                    }
                }
            }
        }

        // Read stderr separately
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                // Store all errors (thread-safe)
                errorQueue.async(flags: .barrier) {
                    allErrors.append(data)
                }

                // Log real-time errors
                if let errorOutput = String(data: data, encoding: .utf8) {
                    Task {
                        await SecureLogger.shared.warning("⚠️ Python stderr: \(errorOutput)", category: "MLXService")
                    }
                }
            }
        }

        // Wait for completion
        await SecureLogger.shared.info("⏳ Waiting for download to complete...", category: "MLXService")
        process.waitUntilExit()

        // Clean up handlers
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil

        // Get exit code
        let exitCode = process.terminationStatus
        await SecureLogger.shared.info("Process exited with code: \(exitCode)", category: "MLXService")

        // Get all captured output (wait for queues to finish)
        var fullOutput = ""
        var fullErrors = ""

        outputQueue.sync {
            fullOutput = String(data: allOutput, encoding: .utf8) ?? ""
        }

        errorQueue.sync {
            fullErrors = String(data: allErrors, encoding: .utf8) ?? ""
        }

        await SecureLogger.shared.info("📋 Full stdout (\(allOutput.count) bytes):", category: "MLXService")
        await SecureLogger.shared.info(fullOutput.isEmpty ? "(empty)" : fullOutput, category: "MLXService")

        await SecureLogger.shared.info("📋 Full stderr (\(allErrors.count) bytes):", category: "MLXService")
        await SecureLogger.shared.info(fullErrors.isEmpty ? "(empty)" : fullErrors, category: "MLXService")

        guard exitCode == 0 else {
            // Parse error message if available
            var errorMessage = "Download failed with exit code \(exitCode)"

            await SecureLogger.shared.error("❌ Download failed with exit code \(exitCode)", category: "MLXService")

            // Combine stdout and stderr for error analysis
            let combinedOutput = fullOutput + "\n" + fullErrors

            // Try to extract JSON error from stdout
            if let jsonData = fullOutput.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = json["error"] as? String {
                errorMessage = error
                await SecureLogger.shared.error("JSON error: \(error)", category: "MLXService")
            } else if !fullErrors.isEmpty {
                // Prefer stderr for error messages
                errorMessage = fullErrors.trimmingCharacters(in: .whitespacesAndNewlines)
                await SecureLogger.shared.error("stderr output: \(errorMessage)", category: "MLXService")
            } else if !fullOutput.isEmpty {
                errorMessage = fullOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                await SecureLogger.shared.error("stdout output: \(errorMessage)", category: "MLXService")
            } else {
                await SecureLogger.shared.error("No output captured from Python process!", category: "MLXService")
            }

            await SecureLogger.shared.error("Combined output for debugging: \(combinedOutput)", category: "MLXService")

            throw MLXServiceError.generationFailed(errorMessage)
        }

        await SecureLogger.shared.info("✅ Model download completed: \(model.name)", category: "MLXService")

        // Return updated model with actual path
        var updatedModel = model
        updatedModel.path = actualPath
        return updatedModel
    }
}
