//
//  MLXService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Updated 2026-03-04 — Replaced Python daemon with native MLX Swift
//  Updated 2026-03-04 — Native model downloads via Hub API (no Python)
//  Updated 2026-11-06 — mlx-swift-lm 3.x (HubClient + Tokenizers via MLXHuggingFace),
//                       real cancellation, native tool calling, KV-cache settings
//  Copyright © 2025. All rights reserved.
//

import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

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

    /// File patterns fetched when downloading a model snapshot from Hugging Face.
    /// Besides weights/configs this must include chat templates (`chat_template.jinja`),
    /// BPE merges (`merges.txt`), and SentencePiece models (`tokenizer.model`), or
    /// tokenizers silently fall back to wrong templates / fail to load.
    static let downloadPatterns = ["*.safetensors", "*.json", "*.jinja", "*.txt", "*.model"]

    /// Currently loaded model metadata
    private var loadedModel: MLXModel?

    /// Whether a model is currently loaded
    private var isModelLoaded = false

    /// Whether inference is currently running
    private var isInferenceRunning = false

    /// Generator for the loaded model (wraps the mlx-swift-lm ModelContainer in production)
    private var generator: (any InferenceGenerator)?

    /// Provides the current KV-cache settings (reads AppSettings in production)
    private let kvCacheSettingsProvider: @Sendable () async -> KVCacheSettings

    /// Context window size read from the model's config.json
    private(set) var loadedModelContextWindow: Int?

    /// Whether the loaded model's tokenizer supports chat templates
    private(set) var hasChatTemplateSupport: Bool = false

    private init() {
        self.kvCacheSettingsProvider = { await MainActor.run { AppSettings.shared.kvCacheSettings } }
    }

    /// Test/DI initializer: injects a generator and a "loaded" model without touching disk or GPU.
    init(
        generator: any InferenceGenerator,
        model: MLXModel,
        contextWindow: Int? = nil,
        kvCacheSettings: KVCacheSettings = .default
    ) {
        self.generator = generator
        self.loadedModel = model
        self.isModelLoaded = true
        self.loadedModelContextWindow = contextWindow
        self.hasChatTemplateSupport = true
        self.kvCacheSettingsProvider = { kvCacheSettings }
    }

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

        // mlx-swift-lm 3.x: local directory + swift-transformers tokenizer loader
        let container = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: #huggingFaceTokenizerLoader()
        )

        generator = MLXContainerGenerator(container: container)
        loadedModel = model
        isModelLoaded = true

        // Read context window from config.json (top level or nested text_config)
        loadedModelContextWindow = ModelConfigInspector.contextWindow(inModelDirectory: directory)

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
        generator = nil
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

    /// Returns true while a generation is in flight.
    func isGenerating() -> Bool {
        return isInferenceRunning
    }

    // MARK: - Inference

    /// Generates text from a raw prompt.
    /// Cancelling the calling task stops generation and throws `CancellationError`.
    func generate(
        prompt: String,
        parameters: ModelParameters? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        let sanitizedPrompt = SecurityUtils.sanitizeUserInput(prompt)
        return try await run(
            prompt: .text(sanitizedPrompt),
            fallbackPrompt: nil,
            tools: nil,
            parameters: parameters,
            streamHandler: streamHandler
        )
    }

    /// Generates a response from structured chat messages using the tokenizer's chat template.
    ///
    /// - Parameter tools: Native tool specs (see `ToolSpecBuilder`). Native tool calls are
    ///   rendered as `<tool>{...}</tool>` text in the returned response so the existing
    ///   tool-approval flow handles them; the plain-text `</tool>` protocol still works
    ///   as a fallback for models without native tool-call support.
    /// Cancelling the calling task stops generation and throws `CancellationError`.
    func chatCompletion(
        messages: [Message],
        parameters: ModelParameters? = nil,
        tools: [ToolSpec]? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        let messageDicts: [[String: String]] = messages.map { msg in
            [
                "role": msg.role.rawValue,
                "content": SecurityUtils.sanitizeUserInput(msg.content)
            ]
        }
        return try await run(
            prompt: .messages(messageDicts),
            fallbackPrompt: formatMessagesAsPrompt(messages),
            tools: (tools?.isEmpty ?? true) ? nil : tools,
            parameters: parameters,
            streamHandler: streamHandler
        )
    }

    /// Shared generation loop: busy flag, parameter mapping, cancellation, tool-call mapping.
    private func run(
        prompt: InferencePrompt,
        fallbackPrompt: String?,
        tools: [ToolSpec]?,
        parameters: ModelParameters?,
        streamHandler: ((String) -> Void)?
    ) async throws -> String {
        guard isModelLoaded, let model = loadedModel, let generator else {
            throw MLXServiceError.noModelLoaded
        }
        guard !isInferenceRunning else {
            throw MLXServiceError.inferenceInProgress
        }

        // Always cleared, including on cancellation and errors.
        isInferenceRunning = true
        defer { isInferenceRunning = false }

        try Task.checkCancellation()

        let genParams = parameters ?? model.parameters
        guard genParams.isValid() else { throw MLXServiceError.invalidParameters }

        let kvCache = await kvCacheSettingsProvider()
        let request = InferenceRequest(
            prompt: prompt,
            fallbackPrompt: fallbackPrompt,
            tools: tools,
            parameters: GenerationParameterMapper.map(genParams, kvCache: kvCache)
        )

        let stream = try await generator.generate(request)
        let box = streamHandler.map(StreamHandlerBox.init)

        var fullResponse = ""
        var textOnly = ""
        streamLoop: for await event in stream {
            if Task.isCancelled { break }
            switch event {
            case .chunk(let chunk):
                fullResponse += chunk
                textOnly += chunk
                if let box { await MainActor.run { box.handler(chunk) } }
                // Text-protocol fallback: stop as soon as a complete text tool call is
                // present so the follow-up generation can start immediately.
                if textOnly.contains("</tool>") || textOnly.contains("</tool_call>") {
                    break streamLoop
                }
            case .toolCall(let call):
                // Native tool call: keep consuming so several calls in one turn are captured.
                let rendered = NativeToolCallFormatter.render(call)
                fullResponse += rendered
                if let box { await MainActor.run { box.handler(rendered) } }
            }
        }

        // Leaving the loop early (break / cancellation) terminates the stream, which
        // cancels the underlying mlx-swift-lm generation task.
        try Task.checkCancellation()
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
            sizeInBytes: totalSize,
            contextWindowSize: ModelConfigInspector.contextWindow(inModelDirectory: url)
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
            2. Select a model from the list (Qwen3.5, Qwen3.6, Qwen3-Coder, Gemma 4 or Devstral)
            3. Or add a HuggingFace ID to your custom model

            Recommended: 'Qwen3.5 9B' (fast, 4-bit quantized)
            """)
        }

        await SecureLogger.shared.info("Starting download: \(huggingFaceId)", category: "MLXService")

        let settingsModelsPath = await AppSettings.shared.modelsPath
        let modelsDirectory = URL(fileURLWithPath: (settingsModelsPath as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        guard let repoID = Repo.ID(rawValue: huggingFaceId) else {
            throw MLXServiceError.generationFailed("Invalid HuggingFace ID '\(huggingFaceId)'. Expected 'namespace/name'.")
        }

        // Same on-disk layout as the 2.x HubApi(downloadBase:) so existing downloads are reused:
        // <modelsPath>/models/<namespace>/<name>. Caching is disabled so weights are written
        // once, straight into the user's models folder (not ~/.cache/huggingface).
        let destination = Self.downloadDestination(for: huggingFaceId, in: modelsDirectory)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let hub = HubClient(cache: nil)
        let progressBox = progressHandler.map { ProgressHandlerBox($0) }
        let modelDirectory = try await hub.downloadSnapshot(
            of: repoID,
            to: destination,
            matching: Self.downloadPatterns,
            progressHandler: { progress in
                progressBox?.handler(progress.fractionCompleted)
            }
        )

        await SecureLogger.shared.info("Download complete: \(model.name) at \(modelDirectory.path)", category: "MLXService")

        var updatedModel = model
        updatedModel.path = modelDirectory.path
        updatedModel.isDownloaded = true
        if let contextWindow = ModelConfigInspector.contextWindow(inModelDirectory: modelDirectory) {
            updatedModel.contextWindowSize = contextWindow
        }
        return updatedModel
    }

    /// `<modelsDirectory>/models/<namespace>/<name>` — matches the 2.x Hub layout.
    static func downloadDestination(for huggingFaceId: String, in modelsDirectory: URL) -> URL {
        modelsDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(huggingFaceId, isDirectory: true)
    }
}

/// Wraps a non-Sendable progress callback for use from the main actor.
private final class ProgressHandlerBox: @unchecked Sendable {
    let handler: (Double) -> Void
    init(_ handler: @escaping (Double) -> Void) { self.handler = handler }
}
