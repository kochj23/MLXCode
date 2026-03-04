//
//  MLXService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Updated 2026-03-04 — Replaced Python daemon with native MLX Swift
//  Updated 2026-03-04 — Native model downloads via Hub API (no Python)
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Hub
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

        // Only allow SafeTensors format — reject PyTorch pickle (.bin/.pt) models
        guard isSafeTensorsModel(at: directory) else {
            await SecureLogger.shared.error(
                "Rejected unsafe model format at: \(expandedPath)",
                category: "MLXService"
            )
            throw MLXServiceError.unsafeModelFormat(expandedPath)
        }

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

        // Try the model's native chat template first. Some models (e.g. Mistral 7B) use
        // Jinja features not yet supported by swift-jinja — fall back to flat prompt format.
        let lmInput: LMInput
        do {
            let userInput = UserInput(prompt: .messages(messageDicts))
            lmInput = try await container.prepare(input: userInput)
        } catch {
            await SecureLogger.shared.warning(
                "Chat template failed (\(error.localizedDescription)), falling back to flat prompt",
                category: "MLXService"
            )
            let flatPrompt = formatMessagesAsPrompt(messages)
            let fallbackInput = UserInput(prompt: .text(flatPrompt))
            lmInput = try await container.prepare(input: fallbackInput)
        }

        let stream = try await container.generate(input: lmInput, parameters: params)

        var fullResponse = ""
        if let handler = streamHandler {
            let box = StreamHandlerBox(handler)
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                    await MainActor.run { box.handler(chunk) }
                    // Break as soon as a complete tool call is in the response.
                    // This lets chatCompletion() return immediately rather than
                    // running to maxTokens, which prevents inferenceInProgress
                    // errors on the follow-up generation after tool execution.
                    if fullResponse.contains("</tool>") || fullResponse.contains("</tool_call>") {
                        break
                    }
                }
            }
        } else {
            for await generation in stream {
                if let chunk = generation.chunk {
                    fullResponse += chunk
                    if fullResponse.contains("</tool>") || fullResponse.contains("</tool_call>") {
                        break
                    }
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

    /// Validates that a model directory contains only SafeTensors weights.
    /// Returns true if safe, false if PyTorch pickle files (.bin, .pt) are present
    /// without any corresponding .safetensors files.
    private func isSafeTensorsModel(at url: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        ) else { return false }

        let hasSafeTensors = contents.contains { $0.pathExtension == "safetensors" }
        let hasPickle = contents.contains { $0.pathExtension == "bin" || $0.pathExtension == "pt" }

        // Reject if pickle weights present without any safetensors counterpart
        if hasPickle && !hasSafeTensors { return false }
        // Require at least one safetensors file
        return hasSafeTensors
    }

    /// Formats chat messages as a flat prompt string — used as fallback when
    /// the model's Jinja chat template is not supported by swift-jinja.
    private func formatMessagesAsPrompt(_ messages: [Message]) -> String {
        var prompt = ""
        for message in messages {
            let prefix: String
            switch message.role {
            case .system:    prefix = "System: "
            case .user:      prefix = "User: "
            case .assistant: prefix = "Assistant: "
            }
            prompt += prefix + message.content + "\n\n"
        }
        prompt += "Assistant: "
        return prompt
    }

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

        // Only surface SafeTensors models in the UI
        guard isSafeTensorsModel(at: url) else {
            await SecureLogger.shared.warning(
                "Skipping non-SafeTensors model: \(url.lastPathComponent)",
                category: "MLXService"
            )
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
    case unsafeModelFormat(String)

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
        case .unsafeModelFormat(let path):
            return "Unsafe model format rejected: \(path)\n\nMLX Code only loads SafeTensors (.safetensors) models. PyTorch pickle files (.bin, .pt) are not permitted."
        }
    }
}

// MARK: - Model Download

extension MLXService {
    /// Downloads a model from HuggingFace using the native Hub Swift API.
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
            3. Or add a HuggingFace ID to your custom model

            Recommended: Use 'Llama 3.2 3B' (fast, 4-bit quantized)
            """)
        }

        await SecureLogger.shared.info("Starting download: \(huggingFaceId)", category: "MLXService")

        let settingsModelsPath = await AppSettings.shared.modelsPath
        let modelsDirectory = URL(fileURLWithPath: (settingsModelsPath as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let hub = HubApi(downloadBase: modelsDirectory)
        let repo = Hub.Repo(id: huggingFaceId)

        let modelDirectory = try await hub.snapshot(
            from: repo,
            matching: ["*.safetensors", "*.json"]
        ) { progress in
            progressHandler?(progress.fractionCompleted)
        }

        await SecureLogger.shared.info("Download complete: \(model.name) at \(modelDirectory.path)", category: "MLXService")

        var updatedModel = model
        updatedModel.path = modelDirectory.path
        updatedModel.isDownloaded = true
        return updatedModel
    }
}
