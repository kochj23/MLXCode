//
//  MLXModelTests.swift
//  MLX Code Tests
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import XCTest
@testable import MLX_Code

/// Unit tests for MLXModel and ModelParameters
final class MLXModelTests: XCTestCase {

    // MARK: - Model Parameters Tests

    func testModelParametersDefaultValues() {
        let params = ModelParameters()

        XCTAssertEqual(params.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(params.maxTokens, 2048)
        XCTAssertEqual(params.topP, 0.9, accuracy: 0.001)
        XCTAssertEqual(params.topK, 40)
        XCTAssertEqual(params.repetitionPenalty, 1.1, accuracy: 0.001)
        XCTAssertEqual(params.repetitionContextSize, 20)
    }

    func testModelParametersCustomValues() {
        let params = ModelParameters(
            temperature: 0.5,
            maxTokens: 4096,
            topP: 0.95,
            topK: 50,
            repetitionPenalty: 1.2,
            repetitionContextSize: 30
        )

        XCTAssertEqual(params.temperature, 0.5, accuracy: 0.001)
        XCTAssertEqual(params.maxTokens, 4096)
        XCTAssertEqual(params.topP, 0.95, accuracy: 0.001)
        XCTAssertEqual(params.topK, 50)
        XCTAssertEqual(params.repetitionPenalty, 1.2, accuracy: 0.001)
        XCTAssertEqual(params.repetitionContextSize, 30)
    }

    func testModelParametersValidation() {
        // Valid parameters
        let validParams = ModelParameters(temperature: 0.7, maxTokens: 2048)
        XCTAssertTrue(validParams.isValid())

        // Invalid temperature (too high)
        let invalidTemp1 = ModelParameters(temperature: 2.5)
        XCTAssertFalse(invalidTemp1.isValid())

        // Invalid temperature (negative)
        let invalidTemp2 = ModelParameters(temperature: -0.1)
        XCTAssertFalse(invalidTemp2.isValid())

        // Invalid max tokens
        let invalidTokens1 = ModelParameters(maxTokens: 0)
        XCTAssertFalse(invalidTokens1.isValid())

        let invalidTokens2 = ModelParameters(maxTokens: 200_000)
        XCTAssertFalse(invalidTokens2.isValid())

        // Invalid topP
        let invalidTopP1 = ModelParameters(topP: -0.1)
        XCTAssertFalse(invalidTopP1.isValid())

        let invalidTopP2 = ModelParameters(topP: 1.5)
        XCTAssertFalse(invalidTopP2.isValid())

        // Invalid topK
        let invalidTopK1 = ModelParameters(topK: 0)
        XCTAssertFalse(invalidTopK1.isValid())

        let invalidTopK2 = ModelParameters(topK: 2000)
        XCTAssertFalse(invalidTopK2.isValid())

        // Invalid repetition penalty
        let invalidPenalty1 = ModelParameters(repetitionPenalty: 0)
        XCTAssertFalse(invalidPenalty1.isValid())

        let invalidPenalty2 = ModelParameters(repetitionPenalty: 3.0)
        XCTAssertFalse(invalidPenalty2.isValid())

        // Invalid context size
        let invalidContext1 = ModelParameters(repetitionContextSize: 0)
        XCTAssertFalse(invalidContext1.isValid())

        let invalidContext2 = ModelParameters(repetitionContextSize: 2000)
        XCTAssertFalse(invalidContext2.isValid())
    }

    // MARK: - MLXModel Tests

    func testMLXModelInitialization() {
        let model = MLXModel(
            name: "Test Model",
            path: "/test/path",
            parameters: ModelParameters(),
            isDownloaded: false,
            sizeInBytes: 1_000_000_000,
            huggingFaceId: "test/model",
            description: "A test model"
        )

        XCTAssertEqual(model.name, "Test Model")
        XCTAssertEqual(model.path, "/test/path")
        XCTAssertFalse(model.isDownloaded)
        XCTAssertEqual(model.sizeInBytes, 1_000_000_000)
        XCTAssertEqual(model.huggingFaceId, "test/model")
        XCTAssertEqual(model.description, "A test model")
    }

    func testMLXModelValidation() {
        // Valid model
        let validModel = MLXModel(
            name: "Valid Model",
            path: "/valid/path",
            parameters: ModelParameters()
        )
        XCTAssertTrue(validModel.isValid())

        // Invalid - empty name
        let invalidName = MLXModel(
            name: "   ",
            path: "/valid/path"
        )
        XCTAssertFalse(invalidName.isValid())

        // Invalid - empty path
        let invalidPath = MLXModel(
            name: "Valid Model",
            path: "   "
        )
        XCTAssertFalse(invalidPath.isValid())

        // Invalid - bad parameters
        var invalidParams = MLXModel(
            name: "Valid Model",
            path: "/valid/path"
        )
        invalidParams.parameters.temperature = 5.0 // Out of range
        XCTAssertFalse(invalidParams.isValid())
    }

    func testMLXModelFormattedSize() {
        // Test GB formatting
        let gbModel = MLXModel(
            name: "Large Model",
            path: "/path",
            sizeInBytes: 5_000_000_000 // 5 GB
        )
        let gbSize = gbModel.formattedSize
        XCTAssertTrue(gbSize.contains("5") || gbSize.contains("GB"))

        // Test MB formatting
        let mbModel = MLXModel(
            name: "Small Model",
            path: "/path",
            sizeInBytes: 500_000_000 // 500 MB
        )
        let mbSize = mbModel.formattedSize
        XCTAssertTrue(mbSize.contains("500") || mbSize.contains("MB"))

        // Test unknown size
        let unknownModel = MLXModel(
            name: "Unknown Size",
            path: "/path",
            sizeInBytes: nil
        )
        XCTAssertEqual(unknownModel.formattedSize, "Unknown size")
    }

    func testMLXModelPaths() {
        let model = MLXModel(
            name: "Test",
            path: "/Users/test/.mlx/models/llama-3.2-3b"
        )

        XCTAssertEqual(model.fileName, "llama-3.2-3b")
        XCTAssertEqual(model.directoryPath, "/Users/test/.mlx/models")
    }

    func testMLXModelDefaultFactory() {
        let defaultModel = MLXModel.default()

        XCTAssertEqual(defaultModel.name, "Default Model")
        XCTAssertFalse(defaultModel.isDownloaded)
        XCTAssertTrue(defaultModel.isValid())
    }

    func testMLXModelCommonModels() {
        let models = MLXModel.commonModels()

        XCTAssertEqual(models.count, 4)

        // Check model names
        let modelNames = models.map { $0.name }
        XCTAssertTrue(modelNames.contains("Llama 3.2 3B"))
        XCTAssertTrue(modelNames.contains("Qwen 2.5 7B"))
        XCTAssertTrue(modelNames.contains("Mistral 7B"))
        XCTAssertTrue(modelNames.contains("Phi-3.5 Mini"))

        // All should have HuggingFace IDs
        for model in models {
            XCTAssertNotNil(model.huggingFaceId)
            XCTAssertFalse(model.isDownloaded)
        }
    }

    func testMLXModelCodable() throws {
        let originalModel = MLXModel(
            name: "Test Model",
            path: "/test/path",
            parameters: ModelParameters(temperature: 0.8),
            isDownloaded: true,
            sizeInBytes: 1_000_000,
            huggingFaceId: "test/model",
            description: "Test description"
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalModel)

        // Decode
        let decoder = JSONDecoder()
        let decodedModel = try decoder.decode(MLXModel.self, from: data)

        // Verify
        XCTAssertEqual(decodedModel.name, originalModel.name)
        XCTAssertEqual(decodedModel.path, originalModel.path)
        XCTAssertEqual(decodedModel.isDownloaded, originalModel.isDownloaded)
        XCTAssertEqual(decodedModel.sizeInBytes, originalModel.sizeInBytes)
        XCTAssertEqual(decodedModel.huggingFaceId, originalModel.huggingFaceId)
        XCTAssertEqual(decodedModel.description, originalModel.description)
        XCTAssertEqual(decodedModel.parameters.temperature, originalModel.parameters.temperature, accuracy: 0.001)
    }

    func testMLXModelJSONData() {
        let model = MLXModel(
            name: "Test Model",
            path: "/test/path"
        )

        // Export to JSON
        let jsonData = model.toJSONData()
        XCTAssertNotNil(jsonData)

        // Import from JSON
        let importedModel = MLXModel.fromJSONData(jsonData!)
        XCTAssertNotNil(importedModel)
        XCTAssertEqual(importedModel?.name, model.name)
        XCTAssertEqual(importedModel?.path, model.path)
    }

    func testMLXModelEquality() {
        let model1 = MLXModel(
            id: UUID(),
            name: "Model 1",
            path: "/path1"
        )

        let model2 = MLXModel(
            id: model1.id, // Same ID
            name: "Model 1",
            path: "/path1"
        )

        let model3 = MLXModel(
            id: UUID(), // Different ID
            name: "Model 1",
            path: "/path1"
        )

        XCTAssertEqual(model1, model2) // Same ID
        XCTAssertNotEqual(model1, model3) // Different ID
    }

    func testMLXModelHashable() {
        let model1 = MLXModel(name: "Model 1", path: "/path1")
        let model2 = MLXModel(name: "Model 2", path: "/path2")

        var set = Set<MLXModel>()
        set.insert(model1)
        set.insert(model2)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(model1))
        XCTAssertTrue(set.contains(model2))
    }

    func testMLXModelIdentifiable() {
        let model = MLXModel(name: "Test", path: "/path")

        XCTAssertNotNil(model.id)
        XCTAssertEqual(model.id, model.id) // ID should be stable
    }
}
