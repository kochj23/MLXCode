import Foundation

//
//  AIBackendManager+Generation.swift
//  Shared AI Backend Manager - Generation Methods
//
//  Real implementation of generate() that calls Ollama, TinyLLM, OpenWebUI, etc.
//  Author: Jordan Koch
//  Date: 2026-01-21
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

        // Check if mlx_lm is installed
        let mlxPath = "/opt/homebrew/bin/mlx_lm.generate"
        guard FileManager.default.fileExists(atPath: mlxPath) else {
            let alternatePaths = ["/usr/local/bin/mlx_lm.generate", "\(NSHomeDirectory())/.local/bin/mlx_lm.generate"]
            var found = false
            for path in alternatePaths {
                if FileManager.default.fileExists(atPath: path) { found = true; break }
            }
            if !found {
                print("[AIBackend] MLX not installed. Install with: pip install mlx-lm")
                throw AIError.mlxNotInstalled
            }
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
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AIError.mlxExecutionFailed(errorMessage)
        }

        guard let output = String(data: outputData, encoding: .utf8), !output.isEmpty else {
            throw AIError.noResponse
        }

        let lines = output.components(separatedBy: .newlines)
        var responseLines: [String] = []
        var inResponse = false

        for line in lines {
            if line.hasPrefix("=====") || line.hasPrefix("Prompt:") || line.contains("tokens/s") { continue }
            if line.contains("Response:") || inResponse {
                inResponse = true
                if !line.contains("Response:") { responseLines.append(line) }
            }
        }

        let response = responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return response.isEmpty ? output.trimmingCharacters(in: .whitespacesAndNewlines) : response
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
