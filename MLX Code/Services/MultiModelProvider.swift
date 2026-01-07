//
//  MultiModelProvider.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//  Inspired by TinyLLM project by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation

/// Unified interface for multiple LLM providers
/// Based on multi-server architecture from TinyLLM by Jason Cox (Ollama, vLLM, llama.cpp)
actor MultiModelProvider {
    static let shared = MultiModelProvider()

    private init() {}

    /// Available model providers
    enum Provider: String, CaseIterable {
        case mlx = "MLX (Local)"
        case ollama = "Ollama"
        case vllm = "vLLM"
        case llamaCpp = "llama.cpp"
        case openai = "OpenAI API"

        var requiresAPI: Bool {
            return self == .openai
        }

        var defaultEndpoint: String {
            switch self {
            case .mlx:
                return "http://localhost:8080"
            case .ollama:
                return "http://localhost:11434"
            case .vllm:
                return "http://localhost:8000"
            case .llamaCpp:
                return "http://localhost:8080"
            case .openai:
                return "https://api.openai.com/v1"
            }
        }
    }

    /// Model configuration
    struct ModelConfig: Codable, Identifiable {
        let id: UUID
        let name: String
        let provider: String  // Provider.rawValue
        let endpoint: String
        let modelID: String  // e.g., "gpt-4", "llama-3-8b", "mistral"
        let apiKey: String?
        let isDefault: Bool

        init(name: String, provider: Provider, endpoint: String? = nil, modelID: String, apiKey: String? = nil, isDefault: Bool = false) {
            self.id = UUID()
            self.name = name
            self.provider = provider.rawValue
            self.endpoint = endpoint ?? provider.defaultEndpoint
            self.modelID = modelID
            self.apiKey = apiKey
            self.isDefault = isDefault
        }
    }

    /// Send completion request to any provider
    /// - Parameters:
    ///   - messages: Conversation messages
    ///   - config: Model configuration
    ///   - stream: Whether to stream response
    ///   - tools: Available tools
    /// - Returns: Model response
    func complete(
        messages: [[String: String]],
        config: ModelConfig,
        stream: Bool = false,
        tools: [[String: Any]]? = nil
    ) async throws -> ModelResponse {
        guard let provider = Provider(rawValue: config.provider) else {
            throw ModelError.invalidProvider(config.provider)
        }

        logInfo("[MultiModel] Sending request to \(provider.rawValue): \(config.modelID)", category: "MultiModelProvider")

        switch provider {
        case .mlx:
            return try await sendMLXRequest(messages: messages, config: config, stream: stream, tools: tools)
        case .ollama:
            return try await sendOllamaRequest(messages: messages, config: config, stream: stream)
        case .vllm:
            return try await sendVLLMRequest(messages: messages, config: config, stream: stream)
        case .llamaCpp:
            return try await sendLlamaCppRequest(messages: messages, config: config, stream: stream)
        case .openai:
            return try await sendOpenAIRequest(messages: messages, config: config, stream: stream, tools: tools)
        }
    }

    // MARK: - Provider Implementations

    private func sendMLXRequest(messages: [[String: String]], config: ModelConfig, stream: Bool, tools: [[String: Any]]?) async throws -> ModelResponse {
        // Use existing MLX implementation
        // This would call the current PythonService/MLX backend
        let endpoint = URL(string: "\(config.endpoint)/v1/chat/completions")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": config.modelID,
            "messages": messages,
            "stream": stream
        ]

        if let tools = tools {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseOpenAICompatibleResponse(data: data)
    }

    private func sendOllamaRequest(messages: [[String: String]], config: ModelConfig, stream: Bool) async throws -> ModelResponse {
        // Ollama API format
        let endpoint = URL(string: "\(config.endpoint)/api/chat")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.modelID,
            "messages": messages,
            "stream": stream
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseOllamaResponse(data: data)
    }

    private func sendVLLMRequest(messages: [[String: String]], config: ModelConfig, stream: Bool) async throws -> ModelResponse {
        // vLLM uses OpenAI-compatible API
        let endpoint = URL(string: "\(config.endpoint)/v1/chat/completions")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.modelID,
            "messages": messages,
            "stream": stream
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseOpenAICompatibleResponse(data: data)
    }

    private func sendLlamaCppRequest(messages: [[String: String]], config: ModelConfig, stream: Bool) async throws -> ModelResponse {
        // llama.cpp server uses OpenAI-compatible API
        let endpoint = URL(string: "\(config.endpoint)/v1/chat/completions")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "messages": messages,
            "stream": stream
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseOpenAICompatibleResponse(data: data)
    }

    private func sendOpenAIRequest(messages: [[String: String]], config: ModelConfig, stream: Bool, tools: [[String: Any]]?) async throws -> ModelResponse {
        let endpoint = URL(string: "\(config.endpoint)/chat/completions")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": config.modelID,
            "messages": messages,
            "stream": stream
        ]

        if let tools = tools {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseOpenAICompatibleResponse(data: data)
    }

    // MARK: - Response Parsing

    private func parseOpenAICompatibleResponse(data: Data) throws -> ModelResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ModelError.invalidResponse("Failed to parse response")
        }

        let usage = json["usage"] as? [String: Any]
        let promptTokens = usage?["prompt_tokens"] as? Int ?? 0
        let completionTokens = usage?["completion_tokens"] as? Int ?? 0

        // Check for tool calls
        var toolCalls: [[String: Any]]? = nil
        if let calls = message["tool_calls"] as? [[String: Any]] {
            toolCalls = calls
        }

        return ModelResponse(
            content: content,
            toolCalls: toolCalls,
            promptTokens: promptTokens,
            completionTokens: completionTokens
        )
    }

    private func parseOllamaResponse(data: Data) throws -> ModelResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ModelError.invalidResponse("Failed to parse Ollama response")
        }

        return ModelResponse(
            content: content,
            toolCalls: nil,
            promptTokens: 0,
            completionTokens: 0
        )
    }
}

// MARK: - Models

struct IntentSuggestion {
    let toolName: String
    let confidence: Double
    let reason: String
}

struct ModelResponse {
    let content: String
    let toolCalls: [[String: Any]]?
    let promptTokens: Int
    let completionTokens: Int

    var totalTokens: Int {
        return promptTokens + completionTokens
    }
}

enum ModelError: LocalizedError {
    case invalidProvider(String)
    case invalidResponse(String)
    case apiKeyMissing
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProvider(let name):
            return "Invalid model provider: \(name)"
        case .invalidResponse(let message):
            return "Invalid response from model: \(message)"
        case .apiKeyMissing:
            return "API key required but not configured"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
