//
//  MLXService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Updated 2026-03-04 — Replaced Python daemon with native MLX Swift
//  Copyright © 2025. All rights reserved.
//

import Foundation
import MLXLLM
import MLXLMCommon

// Wraps a non-Sendable stream callback so it can cross actor/task boundaries safely.
private final class StreamHandlerBox: @unchecked Sendable {
    let handler: (String) -> Void
    init(_ handler: @escaping (String) -> Void) { self.handler = handler }
}

/// Service for interacting with MLX language models.
/// Uses the native mlx-swift-lm framework — no Python dependency for inference.
actor MLXService {
    /// Shared singleton instance
    static let shared = MLXService()

    /// Currently loaded model metadata
    private var loadedModel: MLXModel?

    /// Whether a model is currently loaded
    private var isModelLoaded = false

    /// Whether inference is currently running
    private var isInferenceRunning = false

    /// Native MLX model container (owns model weights + tokenizer)
    private var modelContainer: ModelContainer?

    /// Context window size read from the model's config.json
    private(set) var loadedModelContextWindow: Int?

    /// Whether the loaded model's tokenizer supports chat templates
    private(set) var hasChatTemplateSupport: Bool = false

    private init() {}

    // MARK: - Model Management

    /// Loads an MLX model from a local directory.
    func loadModel(_ model: MLXModel) async throws {
        await LogManager.shared.info("Loading model: \(model.name)", category: "MLX")

        guard model.isValid() else {
            throw MLXServiceError.invalidModel
        }

        guard model.isDownloaded else {
            throw MLXServiceError.modelNotDownloaded
        }

        let expandedPath = (model.path as NSString).expandingTildeInPath

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw MLXServiceError.modelNotFound(expandedPath)
        }

        let configPath = (expandedPath as NSString).appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw MLXServiceError.modelNotFound("\(expandedPath) (config.json missing)")
        }

        let directory = URL(fileURLWithPath: expandedPath)
        let configuration = ModelConfiguration(directory: directory)

        modelContainer = try await LLMModelFactory.shared.loadContainer(
            hub: defaultHubApi,
            configuration: configuration
        )

        loadedModel = model
        isModelLoaded = true

        // Read context window from config.json
        if let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let ctxLen = json["max_position_embeddings"] as? Int {
            loadedModelContextWindow = ctxLen
        }

        // mlx-swift-lm handles chat templates natively via the tokenizer
        hasChatTemplateSupport = true

        await LogManager.shared.info(
            "Model loaded: \(model.name) (context: \(loadedModelContextWindow ?? 8192) tokens)",
            category: "MLX"
        )
    }

    /// Unloads the current model and releases GPU memory.
    func unloadModel() async {
        guard isModelLoaded else { return }
        modelContainer = nil
        loadedModel = nil
        isModelLoaded = false
        loadedModelContextWindow = nil
        hasChatTemplateSupport = false
        await LogManager.shared.info("Model unloaded", category: "MLX")
    }

    /// Returns the currently loaded model, or nil if none is loaded.
    func getCurrentModel() -> MLXModel? {
        return loadedModel
    }

    /// Returns true if a model is currently loaded.
    func isLoaded() -> Bool {
        return isModelLoaded
    }

    // MARK: - Inference

    /// Generates text from a raw prompt.
    func generate(
        prompt: String,
        parameters: ModelParameters? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        guard isModelLoaded, let model = loadedModel, let container = modelContainer else {
            throw MLXServiceError.noModelLoaded
        }
        guard !isInferenceRunning else {
            throw MLXServiceError.inferenceInProgress
        }

        isInferenceRunning = true
        defer { isInferenceRunning = false }

        let sanitizedPrompt = SecurityUtils.sanitizeUserInput(prompt)
        let genParams = parameters ?? model.parameters
        guard genParams.isValid() else { throw MLXServiceError.invalidParameters }

        let params = GenerateParameters(
            maxTokens: genParams.maxTokens,
            temperature: Float(genParams.temperature),
            topP: Float(genParams.topP),
            repetitionPenalty: Float(genParams.repetitionPenalty)
        )

        let userInput = UserInput(prompt: .text(sanitizedPrompt))
        let lmInput = try await container.prepare(input: userInput)
        let stream = try await container.generate(input: lmInput, parameters: params)

        var fullResponse = ""
        if let handler = streamHandler {
            let box = StreamHandlerBox(handler)
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                    await MainActor.run { box.handler(chunk) }
                }
            }
        } else {
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                }
            }
        }

        return fullResponse
    }

    /// Generates a response from structured chat messages using the tokenizer's chat template.
    func chatCompletion(
        messages: [Message],
        parameters: ModelParameters? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        guard isModelLoaded, let model = loadedModel, let container = modelContainer else {
            throw MLXServiceError.noModelLoaded
        }
        guard !isInferenceRunning else {
            throw MLXServiceError.inferenceInProgress
        }

        isInferenceRunning = true
        defer { isInferenceRunning = false }

        let genParams = parameters ?? model.parameters
        guard genParams.isValid() else { throw MLXServiceError.invalidParameters }

        let params = GenerateParameters(
            maxTokens: genParams.maxTokens,
            temperature: Float(genParams.temperature),
            topP: Float(genParams.topP),
            repetitionPenalty: Float(genParams.repetitionPenalty)
        )

        // Convert app Message to [[String: any Sendable]] for MLXLMCommon
        // Note: MLXLMCommon.Message is typealias [String: any Sendable] — avoids naming conflict
        let messageDicts: [[String: any Sendable]] = messages.map { msg in
            [
                "role": msg.role.rawValue,
                "content": SecurityUtils.sanitizeUserInput(msg.content)
            ]
        }

        let userInput = UserInput(prompt: .messages(messageDicts))
        let lmInput = try await container.prepare(input: userInput)
        let stream = try await container.generate(input: lmInput, parameters: params)

        var fullResponse = ""
        if let handler = streamHandler {
            let box = StreamHandlerBox(handler)
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                    await MainActor.run { box.handler(chunk) }
                }
            }
        } else {
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                }
            }
        }

        return fullResponse
    }

    // MARK: - Model Discovery

    /// Discovers available MLX models installed on the system.
    func discoverModels() async throws -> [MLXModel] {
        var discoveredModels: [MLXModel] = []

        let settingsModelsPath = await AppSettings.shared.modelsPath
        let expandedModelsPath = (settingsModelsPath as NSString).expandingTildeInPath

        let searchPaths = [
            expandedModelsPath,
            "~/.mlx/models",
            "~/Documents/MLXCode/models",
            "~/Library/Application Support/MLXCode/models",
            "\(NSTemporaryDirectory())MLXCode/models"
        ]

        for path in searchPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)

            guard FileManager.default.fileExists(atPath: expandedPath) else { continue }

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
                await SecureLogger.shared.warning(
                    "Failed to scan \(path): \(error.localizedDescription)",
                    category: "MLXService"
                )
            }
        }

        return discoveredModels
    }

    // MARK: - Private Helpers

    private func parseModelDirectory(_ url: URL) async throws -> MLXModel? {
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

        guard contents.contains(where: { $0.lastPathComponent == "config.json" }) else {
            return nil
        }

        var totalSize: Int64 = 0
        for file in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        return MLXModel(
            name: url.lastPathComponent,
            path: url.path,
            parameters: ModelParameters(),
            isDownloaded: true,
            sizeInBytes: totalSize
        )
    }

    private func getUserSitePackagesPath() -> String {
        let homeDir = NSHomeDirectory()
        for version in ["3.13", "3.12", "3.11", "3.10", "3.9"] {
            let path = "\(homeDir)/Library/Python/\(version)/lib/python/site-packages"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "\(homeDir)/Library/Python/3.9/lib/python/site-packages"
    }

    private func getXcodePythonPath() -> String? {
        let basePath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions"
        for version in ["3.13", "3.12", "3.11", "3.10", "3.9"] {
            let path = "\(basePath)/\(version)/bin/python\(version)"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func getPythonScriptPath(scriptName: String) -> String? {
        if let bundlePath = Bundle.main.path(forResource: scriptName, ofType: "py") {
            return bundlePath
        }
        let appBundleDir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let relativePath = (appBundleDir as NSString).appendingPathComponent("Python/\(scriptName).py")
        if FileManager.default.fileExists(atPath: relativePath) {
            return relativePath
        }
        return nil
    }
}

// MARK: - Error Types

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
    /// Downloads a model from HuggingFace using the Python downloader script.
    func downloadModel(
        _ model: MLXModel,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> MLXModel {
        guard let huggingFaceId = model.huggingFaceId else {
            throw MLXServiceError.generationFailed("""
            Model '\(model.name)' does not have a HuggingFace ID configured.

            To fix:
            1. Go to Settings → Models
            2. Select a model from the list (Llama 3.2, Qwen 2.5, Mistral, or Phi-3.5)
            3. Or add HuggingFace ID to your custom model

            Recommended: Use 'Llama 3.2 3B' (fast, 4-bit quantized)
            """)
        }

        await SecureLogger.shared.info("Starting download of model: \(model.name)", category: "MLXService")

        let fileManager = FileManager.default
        let settingsModelsPath = await AppSettings.shared.modelsPath
        let expandedModelsPath = (settingsModelsPath as NSString).expandingTildeInPath
        let modelsDirectory = URL(fileURLWithPath: expandedModelsPath)

        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let modelDirectory = modelsDirectory.appendingPathComponent(model.fileName)
        let actualPath = modelDirectory.path

        guard let scriptPath = getPythonScriptPath(scriptName: "huggingface_downloader") else {
            throw MLXServiceError.generationFailed("Downloader script not found in bundle or development path")
        }

        guard fileManager.fileExists(atPath: scriptPath) else {
            throw MLXServiceError.generationFailed("Script file not accessible at path: \(scriptPath)")
        }

        guard let pythonPath = getXcodePythonPath() else {
            throw MLXServiceError.generationFailed("Python not found. Please install Xcode and Command Line Tools.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)

        let needsConversion = !huggingFaceId.lowercased().contains("mlx-community")
        var arguments = [scriptPath, "download", huggingFaceId, "--output", actualPath]
        if !needsConversion {
            arguments.append("--no-convert")
        } else {
            arguments.append(contentsOf: ["--quantize", "4bit"])
        }
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = getUserSitePackagesPath()
        process.environment = env
        process.currentDirectoryURL = fileManager.homeDirectoryForCurrentUser

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputQueue = DispatchQueue(label: "com.mlxcode.output")
        let errorQueue = DispatchQueue(label: "com.mlxcode.error")
        var allOutput = Data()
        var allErrors = Data()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputQueue.async { allOutput.append(data) }
            if let output = String(data: data, encoding: .utf8) {
                Task { await SecureLogger.shared.debug("Python stdout: \(output)", category: "MLXService") }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errorQueue.async { allErrors.append(data) }
            if let errorOutput = String(data: data, encoding: .utf8) {
                Task { await SecureLogger.shared.warning("Python stderr: \(errorOutput)", category: "MLXService") }
            }
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        let exitCode = process.terminationStatus

        var fullOutput = ""
        var fullErrors = ""
        outputQueue.sync { fullOutput = String(data: allOutput, encoding: .utf8) ?? "" }
        errorQueue.sync { fullErrors = String(data: allErrors, encoding: .utf8) ?? "" }

        guard exitCode == 0 else {
            var errorMessage = "Download failed with exit code \(exitCode)"
            if let jsonData = fullOutput.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = json["error"] as? String {
                errorMessage = error
            } else if !fullErrors.isEmpty {
                errorMessage = fullErrors.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if !fullOutput.isEmpty {
                errorMessage = fullOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw MLXServiceError.generationFailed(errorMessage)
        }

        await SecureLogger.shared.info("Model download completed: \(model.name)", category: "MLXService")

        var updatedModel = model
        updatedModel.path = actualPath
        return updatedModel
    }
}
