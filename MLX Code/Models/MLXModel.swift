//
//  MLXModel.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents an MLX language model configuration
/// Conforms to Codable for persistence and Identifiable for SwiftUI lists
struct MLXModel: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for the model
    let id: UUID

    /// Display name of the model
    var name: String

    /// File system path to the model
    var path: String

    /// Model parameters configuration
    var parameters: ModelParameters

    /// Whether the model is downloaded and available
    var isDownloaded: Bool

    /// Model size in bytes (if available)
    var sizeInBytes: Int64?

    /// HuggingFace model identifier (if applicable)
    var huggingFaceId: String?

    /// Model description
    var description: String?

    /// Initializes a new MLX model configuration
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Display name
    ///   - path: File system path
    ///   - parameters: Model parameters
    ///   - isDownloaded: Download status
    ///   - sizeInBytes: Model size
    ///   - huggingFaceId: HuggingFace identifier
    ///   - description: Model description
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        parameters: ModelParameters = ModelParameters(),
        isDownloaded: Bool = false,
        sizeInBytes: Int64? = nil,
        huggingFaceId: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.parameters = parameters
        self.isDownloaded = isDownloaded
        self.sizeInBytes = sizeInBytes
        self.huggingFaceId = huggingFaceId
        self.description = description
    }
}

/// Model inference parameters
struct ModelParameters: Codable, Equatable, Hashable {
    /// Temperature for sampling (0.0 to 2.0)
    var temperature: Double

    /// Maximum tokens to generate
    var maxTokens: Int

    /// Top-p sampling parameter
    var topP: Double

    /// Top-k sampling parameter
    var topK: Int

    /// Repetition penalty
    var repetitionPenalty: Double

    /// Number of tokens to consider for repetition penalty
    var repetitionContextSize: Int

    /// Initializes model parameters with defaults
    /// - Parameters:
    ///   - temperature: Sampling temperature (default: 0.7)
    ///   - maxTokens: Maximum tokens to generate (default: 2048)
    ///   - topP: Top-p sampling (default: 0.9)
    ///   - topK: Top-k sampling (default: 40)
    ///   - repetitionPenalty: Repetition penalty (default: 1.2, higher = less repetition)
    ///   - repetitionContextSize: Context size for repetition (default: 64, look back farther)
    init(
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        topP: Double = 0.9,
        topK: Int = 40,
        repetitionPenalty: Double = 1.2,
        repetitionContextSize: Int = 64
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
    }
}

// MARK: - Validation

extension ModelParameters {
    /// Validates the model parameters
    /// - Returns: True if all parameters are within valid ranges
    func isValid() -> Bool {
        // Temperature should be between 0.0 and 2.0
        guard temperature >= 0.0 && temperature <= 2.0 else {
            return false
        }

        // Max tokens should be positive and reasonable
        guard maxTokens > 0 && maxTokens <= 100_000 else {
            return false
        }

        // Top-p should be between 0.0 and 1.0
        guard topP >= 0.0 && topP <= 1.0 else {
            return false
        }

        // Top-k should be positive
        guard topK > 0 && topK <= 1000 else {
            return false
        }

        // Repetition penalty should be positive
        guard repetitionPenalty > 0.0 && repetitionPenalty <= 2.0 else {
            return false
        }

        // Repetition context size should be positive
        guard repetitionContextSize > 0 && repetitionContextSize <= 1000 else {
            return false
        }

        return true
    }
}

// MARK: - MLXModel Extensions

extension MLXModel {
    /// Validates the model configuration
    /// - Returns: True if the model configuration is valid
    func isValid() -> Bool {
        // Name should not be empty
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Path should not be empty
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Parameters should be valid
        guard parameters.isValid() else {
            return false
        }

        return true
    }

    /// Returns a human-readable size string
    var formattedSize: String {
        guard let bytes = sizeInBytes else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Returns the directory path for the model
    var directoryPath: String {
        (path as NSString).deletingLastPathComponent
    }

    /// Returns the model file name
    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

// MARK: - Factory Methods

extension MLXModel {
    /// Creates a default model configuration
    /// - Parameter basePath: Base directory for models (uses smart default if not provided)
    /// - Returns: A new MLXModel with default settings
    static func `default`(basePath: String? = nil) -> MLXModel {
        let modelBasePath = basePath ?? AppSettings.detectWritableModelsPath()
        return MLXModel(
            name: "Llama 3.2 3B (Default)",
            path: "\(modelBasePath)/llama-3.2-3b",
            parameters: ModelParameters(),
            isDownloaded: false,
            huggingFaceId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            description: "Meta's Llama 3.2 3B - Fast and efficient default model"
        )
    }

    /// Creates model configurations for common MLX models
    /// - Parameter basePath: Base directory for models (uses smart default if not provided)
    /// - Returns: Array of pre-configured MLXModel instances
    static func commonModels(basePath: String? = nil) -> [MLXModel] {
        let modelBasePath = basePath ?? AppSettings.detectWritableModelsPath()

        return [
            MLXModel(
                name: "Llama 3.2 3B",
                path: "\(modelBasePath)/llama-3.2-3b",
                parameters: ModelParameters(temperature: 0.7, maxTokens: 4096),
                isDownloaded: false,
                huggingFaceId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                description: "Meta's Llama 3.2 3B parameter model, optimized for MLX"
            ),
            MLXModel(
                name: "Qwen 2.5 7B",
                path: "\(modelBasePath)/qwen-2.5-7b",
                parameters: ModelParameters(temperature: 0.7, maxTokens: 8192),
                isDownloaded: false,
                huggingFaceId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                description: "Alibaba's Qwen 2.5 7B parameter model"
            ),
            MLXModel(
                name: "Mistral 7B",
                path: "\(modelBasePath)/mistral-7b",
                parameters: ModelParameters(temperature: 0.7, maxTokens: 8192),
                isDownloaded: false,
                huggingFaceId: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
                description: "Mistral AI's 7B parameter instruction-tuned model"
            ),
            MLXModel(
                name: "Phi-3.5 Mini",
                path: "\(modelBasePath)/phi-3.5-mini",
                parameters: ModelParameters(temperature: 0.7, maxTokens: 4096),
                isDownloaded: false,
                huggingFaceId: "mlx-community/Phi-3.5-mini-instruct-4bit",
                description: "Microsoft's Phi-3.5 Mini model, small but capable"
            )
        ]
    }
}

// MARK: - Codable Helpers

extension MLXModel {
    /// Exports the model configuration to JSON data
    /// - Returns: JSON data representation or nil if encoding fails
    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    /// Imports a model configuration from JSON data
    /// - Parameter data: JSON data to decode
    /// - Returns: An MLXModel instance or nil if decoding fails
    static func fromJSONData(_ data: Data) -> MLXModel? {
        let decoder = JSONDecoder()
        return try? decoder.decode(MLXModel.self, from: data)
    }
}
