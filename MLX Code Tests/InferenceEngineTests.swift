//
//  InferenceEngineTests.swift
//  MLX Code Tests
//
//  Pure unit tests for the mlx-swift-lm 3.x seam: parameter mapping, KV-cache
//  settings, ModelParameters decoding/migration, model catalog, config.json
//  context-window parsing, ToolRegistry -> ToolSpec, native tool-call rendering.
//  No model download required.
//

import XCTest
@testable import MLX_Code

/// Minimal tool used to exercise schema conversion of enum/items/default.
private struct SchemaProbeTool: Tool {
    let name = "schema_probe"
    let description = "Probe tool for schema tests"
    let parameters = ToolParameterSchema(
        properties: [
            "mode": ParameterProperty(type: "string", description: "Mode", enum: ["fast", "slow"], default: "fast"),
            "paths": ParameterProperty(
                type: "array",
                description: "Paths",
                items: ParameterProperty(type: "string", description: "A path")
            ),
            "limit": ParameterProperty(type: "integer", description: "Max results"),
        ],
        required: ["paths"]
    )

    func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        .success("ok")
    }
}

@MainActor
final class InferenceEngineTests: XCTestCase {

    // MARK: - Parameter mapping

    func testParameterMappingCoversAllFields() {
        let params = ModelParameters(
            temperature: 0.7,
            maxTokens: 1234,
            topP: 0.85,
            topK: 33,
            minP: 0.05,
            repetitionPenalty: 1.15,
            repetitionContextSize: 128
        )
        let kv = KVCacheSettings(bits: 8, maxSize: 16384, prefillStepSize: 2048)
        let mapped = GenerationParameterMapper.map(params, kvCache: kv)

        XCTAssertEqual(mapped.maxTokens, 1234)
        XCTAssertEqual(mapped.temperature, 0.7, accuracy: 1e-6)
        XCTAssertEqual(mapped.topP, 0.85, accuracy: 1e-6)
        XCTAssertEqual(mapped.topK, 33)
        XCTAssertEqual(mapped.minP, 0.05, accuracy: 1e-6)
        XCTAssertEqual(mapped.repetitionPenalty ?? 0, 1.15, accuracy: 1e-6)
        XCTAssertEqual(mapped.repetitionContextSize, 128)
        XCTAssertEqual(mapped.kvBits, 8)
        XCTAssertEqual(mapped.maxKVSize, 16384)
        XCTAssertEqual(mapped.prefill.stepSize, 2048)
    }

    func testParameterMappingDefaults() {
        let mapped = GenerationParameterMapper.map(ModelParameters())
        XCTAssertNil(mapped.kvBits, "Default KV cache is full precision")
        XCTAssertNil(mapped.maxKVSize, "Default KV cache is unbounded")
        XCTAssertEqual(mapped.prefill.stepSize, 512)
        XCTAssertEqual(mapped.topK, 40)
        XCTAssertEqual(mapped.minP, 0, accuracy: 1e-6)
        XCTAssertEqual(mapped.repetitionPenalty ?? 0, 1.1, accuracy: 1e-6)
        XCTAssertEqual(mapped.repetitionContextSize, 256)
    }

    func testKVCacheSettingsSanitized() {
        let bad = KVCacheSettings(bits: 3, maxSize: 100, prefillStepSize: -5).sanitized()
        XCTAssertEqual(bad, KVCacheSettings(bits: 0, maxSize: 0, prefillStepSize: 0))

        let huge = KVCacheSettings(bits: 4, maxSize: 10_000_000, prefillStepSize: 100_000).sanitized()
        XCTAssertEqual(huge.bits, 4)
        XCTAssertEqual(huge.maxSize, 1_048_576)
        XCTAssertEqual(huge.prefillStepSize, 8192)

        // Invalid values never reach GenerateParameters
        let mapped = GenerationParameterMapper.map(ModelParameters(), kvCache: KVCacheSettings(bits: 3, maxSize: 10, prefillStepSize: 0))
        XCTAssertNil(mapped.kvBits)
        XCTAssertNil(mapped.maxKVSize)
        XCTAssertNil(mapped.prefill.stepSize, "0 = let the model choose")
    }

    func testAppSettingsExposeSanitizedKVSettings() {
        let settings = AppSettings.shared
        let saved = (settings.kvCacheBits, settings.maxKVSize, settings.prefillStepSize)
        defer {
            settings.kvCacheBits = saved.0
            settings.maxKVSize = saved.1
            settings.prefillStepSize = saved.2
        }
        settings.kvCacheBits = 4
        settings.maxKVSize = 32768
        settings.prefillStepSize = 1024
        XCTAssertEqual(settings.kvCacheSettings, KVCacheSettings(bits: 4, maxSize: 32768, prefillStepSize: 1024))
        settings.kvCacheBits = 5
        XCTAssertEqual(settings.kvCacheSettings.bits, 0)
    }

    // MARK: - ModelParameters

    func testDefaultRepetitionPenaltyLowered() {
        XCTAssertEqual(ModelParameters().repetitionPenalty, 1.1, accuracy: 1e-9)
        XCTAssertTrue(ModelParameters().isValid())
    }

    func testMinPValidation() {
        XCTAssertTrue(ModelParameters(minP: 0).isValid())
        XCTAssertTrue(ModelParameters(minP: 1).isValid())
        XCTAssertFalse(ModelParameters(minP: -0.1).isValid())
        XCTAssertFalse(ModelParameters(minP: 1.1).isValid())
    }

    func testLegacyParametersDecodeWithMigration() throws {
        // Persisted before minP existed, with the old 1.8 default penalty.
        let legacy = #"{"temperature":0.3,"maxTokens":999,"topP":0.8,"topK":20,"repetitionPenalty":1.8,"repetitionContextSize":64}"#
        let decoded = try JSONDecoder().decode(ModelParameters.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.minP, 0)
        XCTAssertEqual(decoded.repetitionPenalty, 1.1, accuracy: 1e-9, "Legacy 1.8 default migrates to 1.1")
        XCTAssertEqual(decoded.maxTokens, 999)
        XCTAssertEqual(decoded.repetitionContextSize, 64)

        // A deliberately chosen penalty is preserved.
        let custom = #"{"temperature":0.3,"maxTokens":999,"topP":0.8,"topK":20,"repetitionPenalty":1.3,"repetitionContextSize":64,"minP":0.1}"#
        let decodedCustom = try JSONDecoder().decode(ModelParameters.self, from: Data(custom.utf8))
        XCTAssertEqual(decodedCustom.repetitionPenalty, 1.3, accuracy: 1e-9)
        XCTAssertEqual(decodedCustom.minP, 0.1, accuracy: 1e-9)

        // Round-trip
        let data = try JSONEncoder().encode(decodedCustom)
        XCTAssertEqual(try JSONDecoder().decode(ModelParameters.self, from: data), decodedCustom)
    }

    // MARK: - Model catalog

    func testCatalogIdsAreMLXCommunityQuantizedRepos() {
        let models = MLXModel.commonModels(basePath: "/tmp/catalog-test") + [MLXModel.default(basePath: "/tmp/catalog-test")]
        let quantized = try! NSRegularExpression(pattern: #"-(3|4|5|6|8)bit$"#)
        for model in models {
            let id = model.huggingFaceId ?? ""
            XCTAssertTrue(id.hasPrefix("mlx-community/"), "\(id) is not an mlx-community repo")
            let range = NSRange(id.startIndex..., in: id)
            XCTAssertNotNil(quantized.firstMatch(in: id, range: range), "\(id) is not a quantized repo")
            XCTAssertGreaterThan(model.contextWindowSize ?? 0, 0, "\(model.name) needs a context window")
            XCTAssertTrue(model.isValid())
        }
        let ids = models.dropLast().compactMap(\.huggingFaceId)
        XCTAssertEqual(Set(ids).count, ids.count, "Catalog IDs must be unique")
    }

    func testCatalogIncludesCurrentGeneration() {
        let ids = Set(MLXModel.commonModels(basePath: "/tmp/catalog-test").compactMap(\.huggingFaceId))
        for expected in [
            "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            "mlx-community/Qwen3.5-9B-4bit",
            "mlx-community/Qwen3.6-27B-4bit",
            "mlx-community/Qwen3.6-35B-A3B-4bit",
            "mlx-community/gemma-4-e4b-it-4bit",
            "mlx-community/Devstral-Small-2-24B-Instruct-2512-4bit",
            "mlx-community/Qwen3.5-2B-4bit",
        ] {
            XCTAssertTrue(ids.contains(expected), "Catalog is missing \(expected)")
        }
    }

    // MARK: - config.json context window

    func testContextWindowTopLevel() {
        let json = #"{"model_type":"qwen3_moe","max_position_embeddings":262144}"#
        XCTAssertEqual(ModelConfigInspector.contextWindow(fromConfig: Data(json.utf8)), 262144)
    }

    func testContextWindowNestedTextConfig() {
        // Shape of Qwen3.5 / Gemma 4 / Mistral 3 configs on mlx-community
        let json = #"{"model_type":"gemma4","vision_config":{"max_position_embeddings":4096},"text_config":{"max_position_embeddings":131072,"sliding_window":512}}"#
        XCTAssertEqual(ModelConfigInspector.contextWindow(fromConfig: Data(json.utf8)), 131072)
    }

    func testContextWindowTopLevelWinsOverNested() {
        let json = #"{"max_position_embeddings":8192,"text_config":{"max_position_embeddings":131072}}"#
        XCTAssertEqual(ModelConfigInspector.contextWindow(fromConfig: Data(json.utf8)), 8192)
    }

    func testContextWindowAlternateKeys() {
        XCTAssertEqual(ModelConfigInspector.contextWindow(fromConfig: Data(#"{"seq_length":32768}"#.utf8)), 32768)
        XCTAssertEqual(ModelConfigInspector.contextWindow(fromConfig: Data(#"{"text_config":{"max_sequence_length":65536}}"#.utf8)), 65536)
    }

    func testContextWindowMissingOrInvalid() {
        XCTAssertNil(ModelConfigInspector.contextWindow(fromConfig: Data(#"{"model_type":"llama"}"#.utf8)))
        XCTAssertNil(ModelConfigInspector.contextWindow(fromConfig: Data(#"{"max_position_embeddings":0}"#.utf8)))
        XCTAssertNil(ModelConfigInspector.contextWindow(fromConfig: Data("not json".utf8)))
    }

    // MARK: - ToolRegistry -> ToolSpec

    func testToolRegistryProducesValidToolSpecs() throws {
        let tools = ToolRegistry.shared.getAllTools()
        XCTAssertFalse(tools.isEmpty)
        let specs = ToolSpecBuilder.specs(for: tools)
        XCTAssertEqual(specs.count, tools.count)

        var names: [String] = []
        for spec in specs {
            XCTAssertEqual(spec["type"] as? String, "function")
            let function = try XCTUnwrap(spec["function"] as? [String: any Sendable])
            let name = try XCTUnwrap(function["name"] as? String)
            names.append(name)
            XCTAssertFalse((function["description"] as? String ?? "").isEmpty, "\(name) needs a description")

            let parameters = try XCTUnwrap(function["parameters"] as? [String: any Sendable])
            XCTAssertEqual(parameters["type"] as? String, "object")
            let properties = try XCTUnwrap(parameters["properties"] as? [String: any Sendable])
            let required = try XCTUnwrap(parameters["required"] as? [String])
            for key in required {
                XCTAssertNotNil(properties[key], "\(name): required '\(key)' missing from properties")
            }
            for (_, value) in properties {
                let property = try XCTUnwrap(value as? [String: any Sendable])
                XCTAssertNotNil(property["type"] as? String)
            }
            // Must be serializable to JSON (chat templates render it)
            XCTAssertTrue(JSONSerialization.isValidJSONObject(spec), "\(name) spec is not JSON-serializable")
        }
        XCTAssertEqual(names, names.sorted(), "Specs are sorted for a stable prompt")
        XCTAssertEqual(Set(names), Set(tools.map(\.name)))
    }

    func testToolSpecSchemaDetails() throws {
        let spec = ToolSpecBuilder.spec(for: SchemaProbeTool())
        let function = try XCTUnwrap(spec["function"] as? [String: any Sendable])
        XCTAssertEqual(function["name"] as? String, "schema_probe")
        let parameters = try XCTUnwrap(function["parameters"] as? [String: any Sendable])
        XCTAssertEqual(parameters["required"] as? [String], ["paths"])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: any Sendable])

        let mode = try XCTUnwrap(properties["mode"] as? [String: any Sendable])
        XCTAssertEqual(mode["enum"] as? [String], ["fast", "slow"])
        XCTAssertEqual(mode["default"] as? String, "fast")

        let paths = try XCTUnwrap(properties["paths"] as? [String: any Sendable])
        XCTAssertEqual(paths["type"] as? String, "array")
        let items = try XCTUnwrap(paths["items"] as? [String: any Sendable])
        XCTAssertEqual(items["type"] as? String, "string")

        let limit = try XCTUnwrap(properties["limit"] as? [String: any Sendable])
        XCTAssertEqual(limit["type"] as? String, "integer")
        XCTAssertNil(limit["enum"])
    }

    // MARK: - Native tool call rendering

    func testNativeToolCallRendersParsableToolBlock() throws {
        let call = NativeToolCall(name: "bash", arguments: ["command": "ls -la", "timeout": 30, "dry_run": false])
        let text = NativeToolCallFormatter.render(call)
        XCTAssertTrue(text.contains("<tool>"))
        XCTAssertTrue(text.contains("</tool>"))

        let vm = ChatViewModel(conversationsDirectory: nil)
        let raw = try XCTUnwrap(vm.extractToolCalls(text).first)
        let parsed = try XCTUnwrap(ToolRegistry.shared.parseToolCallJSON(raw))
        XCTAssertEqual(parsed.name, "bash")
        XCTAssertEqual(parsed.parameters["command"] as? String, "ls -la")
        XCTAssertEqual(parsed.parameters["timeout"] as? String, "30")
        XCTAssertEqual(parsed.parameters["dry_run"] as? String, "false")
    }

    func testTwoNativeToolCallsInOneResponseBothExtracted() {
        let response = "Checking." +
            NativeToolCallFormatter.render(NativeToolCall(name: "glob", arguments: ["pattern": "*.swift"])) +
            NativeToolCallFormatter.render(NativeToolCall(name: "grep", arguments: ["pattern": "FIXME"]))
        let vm = ChatViewModel(conversationsDirectory: nil)
        let calls = vm.extractToolCalls(response)
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls.compactMap { ToolRegistry.shared.parseToolCallJSON($0)?.name }, ["glob", "grep"])
    }
}
