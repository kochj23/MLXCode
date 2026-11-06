//
//  InferenceEngine.swift
//  MLX Code
//
//  Created on 2026-11-06.
//  Small, testable seam between MLXService and mlx-swift-lm 3.x.
//
//  - `InferenceGenerator` abstracts "turn a request into a stream of events" so the
//    service's state machine (busy flag, cancellation, tool-call mapping) can be
//    unit-tested with a mock and no model download.
//  - `GenerationParameterMapper` maps app-level ModelParameters + KV-cache settings
//    into mlx-swift-lm's `GenerateParameters`.
//  - `ToolSpecBuilder` turns the app's ToolRegistry tools into native `ToolSpec`s.
//  - `NativeToolCallFormatter` renders native `Generation.toolCall` events into the
//    existing `<tool>{...}</tool>` text protocol so the approval/execution flow is reused.
//  - `ModelConfigInspector` reads the context window from config.json (top level or
//    nested `text_config`).
//

import Foundation
import MLXLMCommon

// MARK: - Events and Requests

/// A tool call emitted natively by the model (parsed by mlx-swift-lm).
struct NativeToolCall: @unchecked Sendable {
    /// Function name
    let name: String
    /// Decoded JSON arguments (String, Int, Double, Bool, NSNull, arrays, dictionaries)
    let arguments: [String: Any]

    init(name: String, arguments: [String: Any]) {
        self.name = name
        self.arguments = arguments
    }

    /// Bridges an mlx-swift-lm tool call.
    init(_ call: ToolCall) {
        self.name = call.function.name
        self.arguments = call.function.arguments.mapValues { $0.anyValue }
    }
}

/// Model-agnostic generation event.
enum InferenceEvent: @unchecked Sendable {
    /// Streamed text chunk
    case chunk(String)
    /// Natively parsed tool call
    case toolCall(NativeToolCall)
}

/// What to feed the model.
enum InferencePrompt: Sendable, Equatable {
    /// Raw text prompt
    case text(String)
    /// Structured chat messages (`role` / `content`) rendered with the model's chat template
    case messages([[String: String]])
}

/// A single generation request.
struct InferenceRequest: Sendable {
    var prompt: InferencePrompt
    /// Flat prompt used when the model's Jinja chat template cannot be applied
    var fallbackPrompt: String?
    /// Native tool specifications (nil = no native tool calling)
    var tools: [ToolSpec]?
    /// Fully mapped generation parameters
    var parameters: GenerateParameters
}

/// Anything that can turn a request into a stream of events.
/// Production: `MLXContainerGenerator`. Tests: a mock.
protocol InferenceGenerator: Sendable {
    func generate(_ request: InferenceRequest) async throws -> AsyncStream<InferenceEvent>
}

// MARK: - Production Generator

/// Wraps an mlx-swift-lm `ModelContainer`.
struct MLXContainerGenerator: InferenceGenerator {
    let container: ModelContainer

    func generate(_ request: InferenceRequest) async throws -> AsyncStream<InferenceEvent> {
        let lmInput: LMInput
        switch request.prompt {
        case .text(let text):
            lmInput = try await container.prepare(input: UserInput(prompt: .text(text), tools: request.tools))
        case .messages(let messages):
            let dicts: [[String: any Sendable]] = messages.map { $0 as [String: any Sendable] }
            do {
                lmInput = try await container.prepare(input: UserInput(prompt: .messages(dicts), tools: request.tools))
            } catch {
                // Some chat templates use Jinja features swift-jinja doesn't support yet.
                guard let fallback = request.fallbackPrompt else { throw error }
                await SecureLogger.shared.warning(
                    "Chat template failed (\(error.localizedDescription)), falling back to flat prompt",
                    category: "MLXService"
                )
                lmInput = try await container.prepare(input: UserInput(prompt: .text(fallback)))
            }
        }

        let upstream = try await container.generate(
            input: lmInput,
            parameters: request.parameters,
            tools: request.tools
        )

        return AsyncStream { continuation in
            let pump = Task {
                for await generation in upstream {
                    if Task.isCancelled { break }
                    switch generation {
                    case .chunk(let text):
                        continuation.yield(.chunk(text))
                    case .toolCall(let call):
                        continuation.yield(.toolCall(NativeToolCall(call)))
                    case .rejectedToolCall(let rejected):
                        await SecureLogger.shared.warning(
                            "Rejected tool call (\(rejected.reason)): \(rejected.rawTextPreview.prefix(120))",
                            category: "MLXService"
                        )
                    case .info:
                        break
                    }
                }
                continuation.finish()
            }
            // Consumer cancelled/finished -> stop pumping. Ending iteration of
            // `upstream` cancels mlx-swift-lm's own generation task.
            continuation.onTermination = { _ in pump.cancel() }
        }
    }
}

// MARK: - KV Cache Settings

/// User-facing KV-cache controls (Settings → Model).
struct KVCacheSettings: Codable, Equatable, Sendable {
    /// Supported KV quantization choices. 0 = full precision (no quantization).
    static let allowedBits = [0, 8, 4]

    /// KV cache quantization bits: 0 (none), 8 or 4
    var bits: Int
    /// Maximum KV cache size in tokens (rotating cache). 0 = unlimited.
    var maxSize: Int
    /// Prompt prefill step size (tokens per forward pass). 0 = model default.
    var prefillStepSize: Int

    /// Defaults: full-precision cache, unlimited size, 512-token prefill steps
    /// (mlx-swift-lm's own default).
    static let `default` = KVCacheSettings(bits: 0, maxSize: 0, prefillStepSize: 512)

    /// Returns a copy with out-of-range values replaced by defaults.
    func sanitized() -> KVCacheSettings {
        KVCacheSettings(
            bits: Self.allowedBits.contains(bits) ? bits : 0,
            maxSize: maxSize >= 256 ? min(maxSize, 1_048_576) : 0,
            prefillStepSize: prefillStepSize > 0 ? min(prefillStepSize, 8192) : 0
        )
    }
}

// MARK: - Parameter Mapping

enum GenerationParameterMapper {
    /// Maps app parameters + KV settings into mlx-swift-lm `GenerateParameters`.
    static func map(_ parameters: ModelParameters, kvCache: KVCacheSettings = .default) -> GenerateParameters {
        let kv = kvCache.sanitized()
        return GenerateParameters(
            maxTokens: parameters.maxTokens,
            maxKVSize: kv.maxSize > 0 ? kv.maxSize : nil,
            kvBits: kv.bits > 0 ? kv.bits : nil,
            temperature: Float(parameters.temperature),
            topP: Float(parameters.topP),
            topK: parameters.topK,
            minP: Float(parameters.minP),
            repetitionPenalty: Float(parameters.repetitionPenalty),
            repetitionContextSize: parameters.repetitionContextSize,
            prefill: PrefillParameters(stepSize: kv.prefillStepSize > 0 ? kv.prefillStepSize : nil)
        )
    }
}

// MARK: - Tool Specs

enum ToolSpecBuilder {
    /// OpenAI-style function schema for one tool, as consumed by chat templates.
    static func spec(for tool: Tool) -> ToolSpec {
        let schema = tool.parameters
        var properties: [String: any Sendable] = [:]
        for (name, property) in schema.properties {
            properties[name] = propertySchema(property)
        }
        let parameters: [String: any Sendable] = [
            "type": schema.type,
            "properties": properties,
            "required": schema.required,
        ]
        return [
            "type": "function",
            "function": [
                "name": tool.name,
                "description": tool.description,
                "parameters": parameters,
            ] as [String: any Sendable],
        ]
    }

    /// Specs for all tools, sorted by name for a stable prompt (better prompt-cache hits).
    static func specs(for tools: [Tool]) -> [ToolSpec] {
        tools.sorted { $0.name < $1.name }.map(spec(for:))
    }

    private static func propertySchema(_ property: ParameterProperty) -> [String: any Sendable] {
        var dict: [String: any Sendable] = [
            "type": property.type,
            "description": property.description,
        ]
        if let values = property.enum { dict["enum"] = values }
        if let items = property.items { dict["items"] = propertySchema(items) }
        if let defaultValue = property.default { dict["default"] = defaultValue }
        return dict
    }
}

// MARK: - Native Tool Call → Text Protocol

enum NativeToolCallFormatter {
    /// Renders a native tool call in the app's `<tool>{"name":..,"args":{..}}</tool>` format
    /// so the existing approval / execution / agentic-loop flow handles it unchanged.
    static func render(_ call: NativeToolCall) -> String {
        let payload: [String: Any] = ["name": call.name, "args": call.arguments]
        let json: String
        if JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            json = string
        } else {
            json = #"{"name":"\#(call.name)","args":{}}"#
        }
        return "\n<tool>\n\(json)\n</tool>\n"
    }
}

// MARK: - config.json Inspection

enum ModelConfigInspector {
    /// Keys that carry the trained context length, in priority order.
    static let contextKeys = ["max_position_embeddings", "max_sequence_length", "seq_length", "n_positions"]

    /// Reads the context window from a config.json payload.
    /// Checks the top level first, then nested `text_config` (Gemma 3/4, Qwen3.5/3.6,
    /// Mistral 3 and other multimodal-capable configs nest the language model there).
    static func contextWindow(fromConfig data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let value = firstPositiveInt(in: json) { return value }
        for nestedKey in ["text_config", "language_config", "llm_config"] {
            if let nested = json[nestedKey] as? [String: Any], let value = firstPositiveInt(in: nested) {
                return value
            }
        }
        return nil
    }

    /// Convenience: reads `<directory>/config.json`.
    static func contextWindow(inModelDirectory directory: URL) -> Int? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("config.json")) else {
            return nil
        }
        return contextWindow(fromConfig: data)
    }

    private static func firstPositiveInt(in dict: [String: Any]) -> Int? {
        for key in contextKeys {
            if let value = dict[key] as? Int, value > 0 { return value }
        }
        return nil
    }
}
