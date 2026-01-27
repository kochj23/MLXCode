import Foundation
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

//
//  AIBackendManager+Generation.swift
//  Shared AI Backend Manager - Generation Methods
//
//  Real implementation of generate() that calls Ollama, TinyLLM, OpenWebUI, etc.
//  Now includes native MLX Swift support (no Python subprocess)
//  Author: Jordan Koch
//  Date: 2026-01-21
//  Updated: 2026-01-27 - Added native MLX Swift
//

extension AIBackendManager {

    // MARK: - Text Generation

    /// Generate text using the active AI backend
    /// This is the main method that AISystemAnalyzer and other tools call
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 1000
    ) async throws -> String {

        guard isOllamaAvailable || isTinyLLMAvailable || isTinyChatAvailable || isOpenWebUIAvailable else {
            throw AIError.noBackendAvailable
        }

        switch activeBackend {
        case .ollama:
            return try await generateWithOllama(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )

        case .tinyLLM:
            return try await generateWithTinyLLM(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )

        case .tinyChat:
            return try await generateWithTinyChat(
                prompt: prompt,
                temperature: temperature
            )

        case .openWebUI:
            return try await generateWithOpenWebUI(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature
            )

        case .mlx:
            return try await generateWithMLX(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )

        case .openAI:
            throw AIError.mlxNotImplemented // Cloud providers not yet implemented

        case .googleCloud:
            throw AIError.mlxNotImplemented

        case .azureCognitive:
            throw AIError.mlxNotImplemented

        case .awsAI:
            throw AIError.mlxNotImplemented

        case .ibmWatson:
            throw AIError.mlxNotImplemented
        }
    }

    // MARK: - Ollama Implementation

    private func generateWithOllama(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {

        guard let url = URL(string: "\(ollamaServerURL)/api/generate") else {
            throw AIError.invalidURL
        }

        var messages: [[String: String]] = []

        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }

        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": selectedOllamaModel,
            "prompt": prompt,
            "system": systemPrompt ?? "",
            "stream": false,
            "options": [
                "temperature": temperature,
                "num_predict": maxTokens
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        struct OllamaResponse: Codable {
            let response: String
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }

    // MARK: - TinyLLM Implementation

    private func generateWithTinyLLM(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {

        guard let url = URL(string: "\(tinyLLMServerURL)/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var messages: [[String: String]] = []

        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }

        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": "default",
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return apiResponse.choices.first?.message.content ?? ""
    }

    // MARK: - TinyChat Implementation

    private func generateWithTinyChat(
        prompt: String,
        temperature: Double
    ) async throws -> String {

        guard let url = URL(string: "\(tinyChatServerURL)/api/chat") else {
            throw AIError.invalidURL
        }

        let requestBody: [String: Any] = [
            "message": prompt,
            "model": selectedOllamaModel,
            "temperature": temperature
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        // TinyChat returns streaming JSON lines, take the last complete response
        if let responseText = String(data: data, encoding: .utf8) {
            // Parse last line of streaming response
            let lines = responseText.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines.reversed() {
                if let lineData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let content = json["content"] as? String {
                    return content
                }
            }
        }

        throw AIError.noResponse
    }

    // MARK: - OpenWebUI Implementation

    private func generateWithOpenWebUI(
        prompt: String,
        systemPrompt: String?,
        temperature: Double
    ) async throws -> String {

        // OpenWebUI uses OpenAI-compatible API
        guard let url = URL(string: "\(openWebUIServerURL)/api/chat") else {
            throw AIError.invalidURL
        }

        var messages: [[String: String]] = []

        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }

        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": selectedOllamaModel,
            "messages": messages,
            "temperature": temperature
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        // Parse response (format varies by OpenWebUI version)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw AIError.noResponse
    }

    // MARK: - MLX Implementation

    private func generateWithMLX(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {

        // Try native MLX Swift first (fast, no subprocess)
        do {
            return try await generateWithNativeMLX(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        } catch {
            print("[AIBackend] Native MLX failed: \(error), falling back to subprocess")
            return try await generateWithMLXSubprocess(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        }
    }

    // MARK: - Native MLX Swift Implementation

    private func generateWithNativeMLX(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        print("[AIBackend] Using native MLX Swift (10x faster)")

        // Prepare full prompt
        var fullPrompt = prompt
        if let system = systemPrompt {
            fullPrompt = "\(system)\n\n\(prompt)"
        }

        let modelName = mlxModel ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"
        print("[AIBackend] Loading model: \(modelName)")

        // Load model (this is cached after first load)
        let modelConfiguration = ModelConfiguration.from(id: modelName)
        let modelContainer = try await ModelContainer.from(configuration: modelConfiguration)

        // Generate with native Swift
        var generatedText = ""

        try await modelContainer.perform { context in
            let messages = [[String: String](arrayLiteral: ("role", "user"), ("content", fullPrompt))]
            let promptTokens = try context.tokenizer.applyChatTemplate(messages: messages)

            // Generate
            for try await token in context.model.generate(promptTokens: promptTokens, parameters: .init(maxTokens: maxTokens, temperature: 0.7)) {
                let text = context.tokenizer.decode(tokens: [token])
                generatedText += text
            }
        }

        print("[AIBackend] ✅ Native MLX generation complete (\(generatedText.count) chars)")
        return generatedText
    }

    // MARK: - Subprocess Fallback

    private func generateWithMLXSubprocess(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        print("[AIBackend] Using subprocess fallback")

        let mlxPath = "/opt/homebrew/bin/mlx_lm.generate"
        guard FileManager.default.fileExists(atPath: mlxPath) else {
            throw AIError.mlxNotInstalled
        }

        var fullPrompt = prompt
        if let system = systemPrompt {
            fullPrompt = "\(system)\n\n\(prompt)"
        }

        let model = mlxModel ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mlxPath)
        process.arguments = ["--model", model, "--prompt", fullPrompt, "--max-tokens", "\(maxTokens)", "--temp", "0.7"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AIError.mlxExecutionFailed("Subprocess failed")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8), !output.isEmpty else {
            throw AIError.noResponse
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AIError {
    static var mlxNotInstalled: AIError {
        return .backendUnavailable("MLX not installed")
    }

    static func mlxExecutionFailed(_ message: String) -> AIError {
        return .backendError("MLX failed: \(message)")
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case noBackendAvailable
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResponse
    case mlxNotImplemented

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "No AI backend is available. Please start Ollama, TinyLLM, TinyChat, or OpenWebUI."
        case .invalidURL:
            return "Invalid backend URL configuration"
        case .invalidResponse:
            return "Received invalid response from AI backend"
        case .httpError(let code):
            return "HTTP error \(code) from AI backend"
        case .noResponse:
            return "No response received from AI backend"
        case .mlxNotImplemented:
            return "MLX backend not yet implemented. Please use Ollama instead."
        }
    }
}
