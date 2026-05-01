//
//  MLXModelTests.swift
//  MLX Code Tests
//
//  Unit tests for MLXModel and ModelParameters: validation, Codable,
//  factory methods, and edge cases.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class MLXModelTests: XCTestCase {

    // MARK: - ModelParameters Validation

    func testDefaultParametersAreValid() {
        let params = ModelParameters()
        XCTAssertTrue(params.isValid(), "Default parameters should be valid")
    }

    func testTemperatureZeroIsValid() {
        let params = ModelParameters(temperature: 0.0)
        XCTAssertTrue(params.isValid(), "Temperature 0.0 should be valid")
    }

    func testTemperatureTwoIsValid() {
        let params = ModelParameters(temperature: 2.0)
        XCTAssertTrue(params.isValid(), "Temperature 2.0 should be valid")
    }

    func testTemperatureAboveTwoIsInvalid() {
        let params = ModelParameters(temperature: 2.1)
        XCTAssertFalse(params.isValid(), "Temperature > 2.0 should be invalid")
    }

    func testNegativeTemperatureIsInvalid() {
        let params = ModelParameters(temperature: -0.1)
        XCTAssertFalse(params.isValid(), "Negative temperature should be invalid")
    }

    func testMaxTokensZeroIsInvalid() {
        let params = ModelParameters(maxTokens: 0)
        XCTAssertFalse(params.isValid(), "maxTokens 0 should be invalid")
    }

    func testMaxTokensAboveLimitIsInvalid() {
        let params = ModelParameters(maxTokens: 100_001)
        XCTAssertFalse(params.isValid(), "maxTokens > 100,000 should be invalid")
    }

    func testTopPBoundaries() {
        XCTAssertTrue(ModelParameters(topP: 0.0).isValid(), "topP 0.0 should be valid")
        XCTAssertTrue(ModelParameters(topP: 1.0).isValid(), "topP 1.0 should be valid")
        XCTAssertFalse(ModelParameters(topP: 1.1).isValid(), "topP > 1.0 should be invalid")
        XCTAssertFalse(ModelParameters(topP: -0.1).isValid(), "topP < 0.0 should be invalid")
    }

    func testTopKBoundaries() {
        XCTAssertTrue(ModelParameters(topK: 1).isValid(), "topK 1 should be valid")
        XCTAssertTrue(ModelParameters(topK: 1000).isValid(), "topK 1000 should be valid")
        XCTAssertFalse(ModelParameters(topK: 0).isValid(), "topK 0 should be invalid")
        XCTAssertFalse(ModelParameters(topK: 1001).isValid(), "topK > 1000 should be invalid")
    }

    func testRepetitionPenaltyBoundaries() {
        XCTAssertTrue(ModelParameters(repetitionPenalty: 0.1).isValid())
        XCTAssertTrue(ModelParameters(repetitionPenalty: 2.0).isValid())
        XCTAssertFalse(ModelParameters(repetitionPenalty: 0.0).isValid(), "repetitionPenalty 0.0 should be invalid")
        XCTAssertFalse(ModelParameters(repetitionPenalty: 2.1).isValid(), "repetitionPenalty > 2.0 should be invalid")
    }

    func testRepetitionContextSizeBoundaries() {
        XCTAssertTrue(ModelParameters(repetitionContextSize: 1).isValid())
        XCTAssertTrue(ModelParameters(repetitionContextSize: 1000).isValid())
        XCTAssertFalse(ModelParameters(repetitionContextSize: 0).isValid())
        XCTAssertFalse(ModelParameters(repetitionContextSize: 1001).isValid())
    }

    // MARK: - MLXModel Validation

    func testValidModel() {
        let model = MLXModel(name: "Test", path: "/path/to/model")
        XCTAssertTrue(model.isValid())
    }

    func testEmptyNameIsInvalid() {
        let model = MLXModel(name: "", path: "/path/to/model")
        XCTAssertFalse(model.isValid(), "Empty name should be invalid")
    }

    func testWhitespaceNameIsInvalid() {
        let model = MLXModel(name: "   ", path: "/path/to/model")
        XCTAssertFalse(model.isValid(), "Whitespace-only name should be invalid")
    }

    func testEmptyPathIsInvalid() {
        let model = MLXModel(name: "Test", path: "")
        XCTAssertFalse(model.isValid(), "Empty path should be invalid")
    }

    func testModelWithInvalidParametersIsInvalid() {
        let badParams = ModelParameters(temperature: 5.0)
        let model = MLXModel(name: "Test", path: "/path", parameters: badParams)
        XCTAssertFalse(model.isValid(), "Model with invalid parameters should be invalid")
    }

    // MARK: - Formatted Size

    func testFormattedSizeGB() {
        let model = MLXModel(name: "Test", path: "/p", sizeInBytes: 4_000_000_000)
        let formatted = model.formattedSize
        XCTAssertTrue(formatted.contains("GB"), "4GB model should display in GB")
    }

    func testFormattedSizeUnknown() {
        let model = MLXModel(name: "Test", path: "/p")
        XCTAssertEqual(model.formattedSize, "Unknown size")
    }

    // MARK: - Path Helpers

    func testDirectoryPath() {
        let model = MLXModel(name: "Test", path: "/models/qwen/config.json")
        XCTAssertEqual(model.directoryPath, "/models/qwen")
    }

    func testFileName() {
        let model = MLXModel(name: "Test", path: "/models/qwen/config.json")
        XCTAssertEqual(model.fileName, "config.json")
    }

    // MARK: - Codable Round-Trip

    func testJSONRoundTrip() throws {
        let original = MLXModel(
            name: "Qwen 2.5 7B",
            path: "/models/qwen",
            parameters: ModelParameters(),
            isDownloaded: true,
            sizeInBytes: 4_000_000_000,
            huggingFaceId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
            description: "Test model",
            contextWindowSize: 32768
        )

        guard let data = original.toJSONData() else {
            XCTFail("JSON export should not return nil")
            return
        }

        guard let decoded = MLXModel.fromJSONData(data) else {
            XCTFail("JSON import should not return nil")
            return
        }

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.isDownloaded, true)
        XCTAssertEqual(decoded.huggingFaceId, "mlx-community/Qwen2.5-7B-Instruct-4bit")
        XCTAssertEqual(decoded.contextWindowSize, 32768)
        XCTAssertEqual(decoded.parameters.temperature, original.parameters.temperature, accuracy: 0.001)
    }

    func testInvalidJSONReturnsNil() {
        let badData = "not json".data(using: .utf8)!
        XCTAssertNil(MLXModel.fromJSONData(badData))
    }

    // MARK: - Common Models Factory

    func testCommonModelsReturnsMultiple() {
        let models = MLXModel.commonModels(basePath: "/tmp/test-models")
        XCTAssertGreaterThan(models.count, 3, "Should return multiple pre-configured models")
    }

    func testCommonModelsAllHaveNames() {
        let models = MLXModel.commonModels(basePath: "/tmp/test-models")
        for model in models {
            XCTAssertFalse(model.name.isEmpty, "All common models should have names")
        }
    }

    func testCommonModelsAllHaveHuggingFaceIds() {
        let models = MLXModel.commonModels(basePath: "/tmp/test-models")
        for model in models {
            XCTAssertNotNil(model.huggingFaceId, "All common models should have HuggingFace IDs")
            XCTAssertFalse(model.huggingFaceId!.isEmpty)
        }
    }

    func testDefaultModelIsQwen() {
        let model = MLXModel.default(basePath: "/tmp/test-models")
        XCTAssertTrue(model.name.contains("Qwen"), "Default model should be Qwen")
        XCTAssertEqual(model.contextWindowSize, 32768)
    }

    // MARK: - Equatable / Hashable

    func testEqualModels() {
        let id = UUID()
        let m1 = MLXModel(id: id, name: "A", path: "/p")
        let m2 = MLXModel(id: id, name: "A", path: "/p")
        XCTAssertEqual(m1, m2)
    }

    func testDifferentIdsNotEqual() {
        let m1 = MLXModel(name: "A", path: "/p")
        let m2 = MLXModel(name: "A", path: "/p")
        XCTAssertNotEqual(m1, m2, "Different UUIDs should not be equal")
    }

    func testHashableInSet() {
        let m1 = MLXModel(name: "A", path: "/p")
        let m2 = MLXModel(name: "B", path: "/q")
        let set: Set<MLXModel> = [m1, m2]
        XCTAssertEqual(set.count, 2)
    }
}
