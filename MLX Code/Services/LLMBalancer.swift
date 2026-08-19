//
//  LLMBalancer.swift
//  MLX Code
//
//  Created by Jordan Koch on 2026-08-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  Multi-model load balancer for MLX Code. Wires the reusable, network-free
//  `ModelRegistry` / `LoadBalancer` pieces (ported from AIStudio) into MLX Code's
//  own model call path so that — when the settings toggles are on — chat can be
//  spread across ALL installed local models (native MLX + Ollama), all frontier
//  models (via an OpenRouter key), and the optional Nova Gateway, load-balanced
//  and health-gated, instead of a single pinned MLX model.
//
//  Nova is NEVER a hard requirement: with zero Nova present the balancer still
//  works over local MLX/Ollama models and/or OpenRouter. The Nova Gateway is just
//  one optional entry whose health probe failing simply removes it from the pool.
//

import Foundation

// MARK: - Backend type

/// LLM backend type identifier for the balancer pool. MLX Code is MLX-native, but
/// the balancer can additionally spread work to Ollama, OpenRouter frontier
/// models, and the optional Nova Gateway.
enum LLMBackendType: String, CaseIterable, Codable, Sendable {
    case ollama = "ollama"
    case mlx = "mlx"
    case openRouter = "openrouter"
    case novaGateway = "novagateway"

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .mlx: return "MLX Native"
        case .openRouter: return "OpenRouter (Frontier Models)"
        case .novaGateway: return "Nova Gateway"
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "network"
        case .mlx: return "cpu"
        case .openRouter: return "cloud"
        case .novaGateway: return "sparkle.magnifyingglass"
        }
    }

    var defaultURL: String {
        switch self {
        case .ollama: return ModelRegistry.ollamaBaseURL
        case .mlx: return ""
        case .openRouter: return OpenRouterProvider.baseURL
        case .novaGateway: return ModelRegistry.novaGatewayDefaultURL
        }
    }
}

// MARK: - Errors

/// Errors thrown by the balanced dispatch path.
enum LLMError: LocalizedError {
    case invalidURL
    case noBackendAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The backend URL is invalid"
        case .noBackendAvailable: return "No LLM backend is currently available"
        }
    }
}

/// The balancer reuses MLX Code's own `Message` type as its chat message shape.
typealias ChatMessage = Message

// MARK: - Balancer

/// Load-balanced multi-model dispatch. Mirrors AIStudio's `LLMBackendManager`
/// balancer surface (`discoverEnabledPool` / `healthMap` / `generateBalanced` /
/// `dispatchBalanced`) but routed through MLX Code's in-process `MLXService` for
/// local MLX inference and OpenAI-compatible HTTP for the other backends.
actor LLMBalancer {
    static let shared = LLMBalancer()

    /// Pure round-robin / least-busy selector over the healthy pool.
    private let balancer = LoadBalancer()

    /// Selection policy — least-busy by default (spreads concurrent load).
    var policy: BalancerPolicy = .leastBusy

    /// The most recently discovered pool (for diagnostics / UI).
    private(set) var discoveredModels: [DiscoveredModel] = []

    /// Cached OpenRouter model ids (fetched once, falls back to the popular set).
    private var cachedFrontierIDs: [String]?

    private let session: URLSession = .shared

    private init() {}

    // MARK: Toggle snapshot

    /// A minimal, `Sendable` snapshot of the three balancer toggles + gateway URL,
    /// read from the `@MainActor` `AppSettings`.
    private struct ToggleSnapshot: Sendable {
        let useAllLocalModels: Bool
        let enableAllFrontierModels: Bool
        let useNovaGateway: Bool
        let novaGatewayURL: String
    }

    private func snapshot() async -> ToggleSnapshot {
        await MainActor.run {
            let s = AppSettings.shared
            return ToggleSnapshot(
                useAllLocalModels: s.useAllLocalModels,
                enableAllFrontierModels: s.enableAllFrontierModels,
                useNovaGateway: s.useNovaGateway,
                novaGatewayURL: s.novaGatewayURL
            )
        }
    }

    /// True when any balancing toggle is on. When false, callers must preserve the
    /// existing single-model behavior.
    func isBalancingEnabled() async -> Bool {
        let s = await snapshot()
        return s.useAllLocalModels || s.enableAllFrontierModels || s.useNovaGateway
    }

    /// Set the selection policy.
    func setPolicy(_ newPolicy: BalancerPolicy) {
        policy = newPolicy
    }

    // MARK: Discovery

    /// The OpenRouter API key from the Keychain (empty if none stored).
    private func openRouterKey() -> String {
        KeychainStore(service: OpenRouterProvider.keychainService).get() ?? ""
    }

    /// Discover the enabled balancer pool honoring the three toggles. Resilient:
    /// any unreachable source simply contributes zero models.
    func discoverEnabledPool() async -> [DiscoveredModel] {
        let s = await snapshot()

        var ollama: [DiscoveredModel] = []
        var mlx: [DiscoveredModel] = []
        var frontier: [DiscoveredModel] = []

        if s.useAllLocalModels {
            ollama = await ModelRegistry.discoverOllama(baseURL: ModelRegistry.ollamaBaseURL, session: session)
            // MLX Code discovers SafeTensors models from its own configured paths.
            let localNames = ((try? await MLXService.shared.discoverModels()) ?? []).map { $0.name }
            mlx = ModelRegistry.mlxModels(fromLocalNames: localNames)
        }
        if s.enableAllFrontierModels {
            frontier = ModelRegistry.frontierModels(from: await frontierModelIDs())
        }
        let nova = s.useNovaGateway ? ModelRegistry.novaGatewayModel(url: s.novaGatewayURL) : nil

        let pool = ModelRegistry.assemblePool(
            ollama: ollama,
            mlx: mlx,
            frontier: frontier,
            novaGateway: nova,
            useAllLocalModels: s.useAllLocalModels,
            enableAllFrontierModels: s.enableAllFrontierModels,
            useNovaGateway: s.useNovaGateway
        )
        discoveredModels = pool
        return pool
    }

    /// Fetch the live OpenRouter model list (cached), falling back to the popular
    /// set on any failure or when no API key is present.
    private func frontierModelIDs() async -> [String] {
        if let cached = cachedFrontierIDs { return cached }
        let key = openRouterKey()
        guard !key.isEmpty, let url = URL(string: OpenRouterProvider.modelsURL) else {
            return OpenRouterProvider.fallbackModels
        }
        var request = URLRequest(url: url)
        for (k, v) in OpenRouterProvider.authHeaders(apiKey: key) {
            request.setValue(v, forHTTPHeaderField: k)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                cachedFrontierIDs = OpenRouterProvider.fallbackModels
                return OpenRouterProvider.fallbackModels
            }
            let ids = OpenRouterProvider.parseModels(data)
            let result = ids.isEmpty ? OpenRouterProvider.fallbackModels : ids
            cachedFrontierIDs = result
            return result
        } catch {
            return OpenRouterProvider.fallbackModels
        }
    }

    // MARK: Health

    /// Build a `[modelId: Bool]` health map for `pool` by probing each distinct
    /// backend once. This is the health-gating that lets an unavailable backend
    /// (e.g. the Nova Gateway) drop out while everything else keeps working.
    private func healthMap(for pool: [DiscoveredModel], novaURL: String) async -> [String: Bool] {
        var backendHealth: [LLMBackendType: Bool] = [:]
        for backend in Set(pool.map { $0.backend }) {
            backendHealth[backend] = await checkAvailability(backend, novaURL: novaURL)
        }
        var map: [String: Bool] = [:]
        for model in pool {
            map[model.id] = backendHealth[model.backend] ?? false
        }
        return map
    }

    /// Live availability probe for a single backend. Never throws.
    private func checkAvailability(_ backend: LLMBackendType, novaURL: String) async -> Bool {
        switch backend {
        case .mlx:
            // In-process; available only when a model is actually loaded.
            return await MLXService.shared.isLoaded()
        case .ollama:
            return await httpOK("\(ModelRegistry.ollamaBaseURL)/api/tags")
        case .openRouter:
            return !openRouterKey().isEmpty
        case .novaGateway:
            return await httpOK("\(novaURL)/v1/models")
        }
    }

    /// GET the URL and report whether it returned HTTP 200. Any failure → false.
    private func httpOK(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: Balanced dispatch

    /// Balanced chat completion over the healthy enabled pool. Returns `nil` when
    /// the pool is empty (caller should fall back to the single-model path).
    /// Throws only when every healthy candidate failed mid-flight.
    ///
    /// For the in-process MLX backend the real `streamHandler` is passed straight
    /// through (true token streaming). For HTTP backends the completed response is
    /// delivered to `streamHandler` in one call.
    func chatCompletionBalanced(
        messages: [Message],
        parameters: ModelParameters?,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> String? {
        let s = await snapshot()
        let pool = await discoverEnabledPool()
        guard !pool.isEmpty else { return nil }

        let health = await healthMap(for: pool, novaURL: s.novaGatewayURL)
        var remaining = pool
        var lastError: Error?

        while let choice = balancer.next(pool: remaining, health: health, policy: policy) {
            balancer.checkOut(choice.id)
            do {
                let result = try await dispatchBalanced(
                    model: choice,
                    messages: messages,
                    parameters: parameters,
                    streamHandler: streamHandler
                )
                balancer.checkIn(choice.id)
                return result
            } catch {
                balancer.checkIn(choice.id)
                lastError = error
                remaining.removeAll { $0.id == choice.id }
                continue
            }
        }

        if let lastError = lastError { throw lastError }
        return nil
    }

    /// Route a single balancer-selected model to its backend implementation.
    private func dispatchBalanced(
        model: DiscoveredModel,
        messages: [Message],
        parameters: ModelParameters?,
        streamHandler: ((String) -> Void)?
    ) async throws -> String {
        switch model.backend {
        case .mlx:
            // In-process native inference through the existing MLX path.
            return try await MLXService.shared.chatCompletion(
                messages: messages,
                parameters: parameters,
                streamHandler: streamHandler
            )
        case .ollama:
            let content = try await postOpenAICompatible(
                endpoint: "\(ModelRegistry.ollamaBaseURL)/v1/chat/completions",
                model: model.modelName,
                headers: [:],
                messages: messages,
                parameters: parameters
            )
            streamHandler?(content)
            return content
        case .openRouter:
            let key = openRouterKey()
            guard !key.isEmpty else { throw LLMError.noBackendAvailable }
            let content = try await postOpenAICompatible(
                endpoint: model.endpoint,
                model: model.modelName,
                headers: OpenRouterProvider.authHeaders(apiKey: key),
                messages: messages,
                parameters: parameters
            )
            streamHandler?(content)
            return content
        case .novaGateway:
            let content = try await postOpenAICompatible(
                endpoint: model.endpoint,
                model: model.modelName,
                headers: [:],
                messages: messages,
                parameters: parameters
            )
            streamHandler?(content)
            return content
        }
    }

    /// POST an OpenAI-compatible chat-completions request and return the assistant
    /// message content. Non-streaming.
    private func postOpenAICompatible(
        endpoint: String,
        model: String,
        headers: [String: String],
        messages: [Message],
        parameters: ModelParameters?
    ) async throws -> String {
        let params = parameters ?? ModelParameters()
        let payloadMessages: [[String: String]] = messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        }
        let request = try OpenAICompatibleRequest.build(
            endpoint: endpoint,
            model: model,
            messages: payloadMessages,
            temperature: Float(params.temperature),
            maxTokens: params.maxTokens,
            stream: false,
            headers: headers
        )
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw LLMError.noBackendAvailable
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.noBackendAvailable
        }
        return content
    }
}
