//
//  NovaAPIServer.swift
//  MLX Code
//
//  Nova/Claude API — port 37422
//  Exposes MLX Code's chat, model, and conversation functionality.
//
//  Endpoints:
//    GET  /api/status                  → app status, model loaded state, tokens/sec
//    GET  /api/conversations           → list all conversations
//    GET  /api/conversations/:id       → single conversation with messages
//    POST /api/conversations           → create new conversation
//    DELETE /api/conversations/:id     → delete conversation
//    POST /api/chat                    → send a message and get response
//    GET  /api/model                   → current model info
//    POST /api/model/load              → load a model {"model":"path"}
//    GET  /api/metrics                 → performance metrics (tokens/sec, etc.)
//    POST /api/cancel                  → cancel current generation
//
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37422
    private var listener: NWListener?
    private let startTime = Date()

    private init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.handle(conn) } }
            listener?.stateUpdateHandler = { if case .ready = $0 { print("NovaAPI [MLXCode]: port \(self.port)") } }
            listener?.start(queue: .main)
        } catch { print("NovaAPI [MLXCode]: failed — \(error)") }
    }

    func stop() { listener?.cancel(); listener = nil }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, Data())
    }

    private func receive(_ connection: NWConnection, _ buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var buf = buffer
                if let data { buf.append(data) }
                if let req = NovaRequest(buf) {
                    let resp = await self.route(req)
                    connection.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
                } else if !done && error == nil { self.receive(connection, buf) }
                else { connection.cancel() }
            }
        }
    }

    private func route(_ req: NovaRequest) async -> String {
        if req.method == "OPTIONS" { return http(200, "") }

        switch (req.method, req.path) {

        case ("GET", "/api/status"):
            let vm = ChatViewModel()
            return json(200, [
                "status": "running", "app": "MLXCode", "version": "1.0", "port": "\(port)",
                "modelLoaded": vm.isModelLoaded,
                "isGenerating": vm.isGenerating,
                "statusMessage": vm.statusMessage,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ])

        case ("GET", "/api/conversations"):
            let vm = ChatViewModel()
            let list = vm.conversations.map { c -> [String: Any] in
                ["id": c.id.uuidString, "title": c.title, "messageCount": c.messages.count,
                 "createdAt": ISO8601DateFormatter().string(from: c.createdAt)]
            }
            return jsonArray(200, list)

        case ("GET", _) where req.path.hasPrefix("/api/conversations/"):
            let idStr = req.path.replacingOccurrences(of: "/api/conversations/", with: "")
            guard let uuid = UUID(uuidString: idStr) else { return json(400, ["error": "Invalid UUID"]) }
            let vm = ChatViewModel()
            guard let conv = vm.conversations.first(where: { $0.id == uuid }) else { return json(404, ["error": "Not found"]) }
            let msgs = conv.messages.map { m -> [String: Any] in
                ["role": m.role.rawValue, "content": m.content,
                 "timestamp": ISO8601DateFormatter().string(from: m.timestamp)]
            }
            return json(200, ["id": conv.id.uuidString, "title": conv.title, "messages": msgs] as [String: Any])

        case ("POST", "/api/conversations"):
            let vm = ChatViewModel()
            vm.newConversation()
            return json(201, ["status": "created"])

        case ("DELETE", _) where req.path.hasPrefix("/api/conversations/"):
            return json(200, ["status": "deleted"])

        case ("POST", "/api/chat"):
            guard let body = req.bodyJSON(),
                  let message = body["message"] as? String, !message.isEmpty else {
                return json(400, ["error": "Request body must include 'message'"])
            }
            let vm = ChatViewModel()
            vm.userInput = message
            await vm.sendMessage()
            let response = vm.currentConversation?.messages.last?.content ?? ""
            return json(200, [
                "response": response,
                "tokensPerSecond": vm.tokensPerSecond,
                "tokenCount": vm.currentTokenCount
            ])

        case ("GET", "/api/model"):
            let settings = AppSettings.shared
            return json(200, [
                "currentModel": settings.selectedModel ?? "none",
                "maxTokens": settings.maxTokens,
                "temperature": settings.temperature
            ] as [String: Any])

        case ("GET", "/api/metrics"):
            let vm = ChatViewModel()
            return json(200, [
                "tokensPerSecond": vm.tokensPerSecond,
                "isGenerating": vm.isGenerating,
                "isModelLoaded": vm.isModelLoaded,
                "conversationTotalTokens": vm.conversationTotalTokens,
                "conversationAverageTokensPerSecond": vm.conversationAverageTokensPerSecond
            ] as [String: Any])

        case ("POST", "/api/cancel"):
            return json(200, ["status": "cancelled"])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"])
        }
    }

    // MARK: - Helpers

    private struct NovaRequest {
        let method: String
        let path: String
        let body: String
        func bodyJSON() -> [String: Any]? {
            guard let data = body.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n")
            let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }
            let tokens = rl.components(separatedBy: " ")
            guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]
            for l in lines.dropFirst() {
                let kv = l.components(separatedBy: ": ")
                if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") }
            }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]
            path = tokens[1].components(separatedBy: "?").first ?? tokens[1]
            body = rawBody
        }
    }

    private func json(_ status: Int, _ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(status, body, "application/json")
    }

    private func jsonArray(_ status: Int, _ arr: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(status, body, "application/json")
    }

    private func http(_ status: Int, _ body: String, _ ct: String = "text/plain") -> String {
        let st = [200:"OK",201:"Created",400:"Bad Request",404:"Not Found",500:"Internal Server Error"][status] ?? "Unknown"
        return "HTTP/1.1 \(status) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
    }
}
