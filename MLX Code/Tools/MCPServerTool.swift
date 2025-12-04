//
//  MCPServerTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for Model Context Protocol (MCP) server integration
/// Enables connection to external data sources and tools via MCP servers
class MCPServerTool: BaseTool {
    private var activeServers: [String: MCPServer] = [:]

    init() {
        super.init(
            name: "mcp",
            description: """
            Connect to and interact with MCP (Model Context Protocol) servers.
            Access external data sources, APIs, and custom tools.
            """,
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "MCP operation",
                        enum: ["list_servers", "connect", "disconnect", "list_tools", "call_tool", "discover"]
                    ),
                    "server_url": ParameterProperty(
                        type: "string",
                        description: "MCP server URL (e.g., 'http://localhost:3000')"
                    ),
                    "server_name": ParameterProperty(
                        type: "string",
                        description: "Server identifier"
                    ),
                    "tool_name": ParameterProperty(
                        type: "string",
                        description: "Tool to call on MCP server"
                    ),
                    "tool_parameters": ParameterProperty(
                        type: "object",
                        description: "Parameters for tool call"
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        switch operation {
        case "list_servers":
            return try await listServers()
        case "connect":
            return try await connectServer(parameters: parameters, context: context)
        case "disconnect":
            return try await disconnectServer(parameters: parameters)
        case "list_tools":
            return try await listTools(parameters: parameters)
        case "call_tool":
            return try await callTool(parameters: parameters, context: context)
        case "discover":
            return try await discoverServers(context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func listServers() async throws -> ToolResult {
        var result = "# Connected MCP Servers\n\n"

        if activeServers.isEmpty {
            result += "*No servers connected*\n"
        } else {
            for (name, server) in activeServers {
                result += "## \(name)\n"
                result += "- **URL**: \(server.url)\n"
                result += "- **Status**: \(server.isConnected ? "✅ Connected" : "❌ Disconnected")\n"
                result += "- **Tools**: \(server.availableTools.count)\n\n"
            }
        }

        return .success(result, metadata: ["count": activeServers.count])
    }

    private func connectServer(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let serverUrl = parameters["server_url"] as? String else {
            throw ToolError.missingParameter("server_url")
        }

        let serverName = parameters["server_name"] as? String ?? URL(string: serverUrl)?.host ?? "unknown"

        // Create and connect server
        let server = MCPServer(name: serverName, url: serverUrl)

        do {
            try await server.connect()
            activeServers[serverName] = server

            var result = "# MCP Server Connected\n\n"
            result += "**Name**: \(serverName)\n"
            result += "**URL**: \(serverUrl)\n"
            result += "**Available Tools**: \(server.availableTools.count)\n\n"

            if !server.availableTools.isEmpty {
                result += "## Tools\n"
                for tool in server.availableTools {
                    result += "- `\(tool.name)`: \(tool.description)\n"
                }
            }

            return .success(result)
        } catch {
            return .failure("Failed to connect to MCP server: \(error.localizedDescription)")
        }
    }

    private func disconnectServer(parameters: [String: Any]) async throws -> ToolResult {
        guard let serverName = parameters["server_name"] as? String else {
            throw ToolError.missingParameter("server_name")
        }

        guard let server = activeServers[serverName] else {
            return .failure("Server '\(serverName)' not found")
        }

        await server.disconnect()
        activeServers.removeValue(forKey: serverName)

        return .success("✅ Disconnected from MCP server: \(serverName)")
    }

    private func listTools(parameters: [String: Any]) async throws -> ToolResult {
        guard let serverName = parameters["server_name"] as? String else {
            throw ToolError.missingParameter("server_name")
        }

        guard let server = activeServers[serverName] else {
            return .failure("Server '\(serverName)' not connected")
        }

        var result = "# Tools on \(serverName)\n\n"

        for tool in server.availableTools {
            result += "## \(tool.name)\n"
            result += "\(tool.description)\n\n"

            if !tool.parameters.isEmpty {
                result += "**Parameters:**\n"
                for param in tool.parameters {
                    result += "- `\(param.name)` (\(param.type)): \(param.description)\n"
                }
            }
            result += "\n"
        }

        return .success(result, metadata: ["tool_count": server.availableTools.count])
    }

    private func callTool(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let serverName = parameters["server_name"] as? String,
              let toolName = parameters["tool_name"] as? String else {
            throw ToolError.missingParameter("server_name or tool_name")
        }

        guard let server = activeServers[serverName] else {
            return .failure("Server '\(serverName)' not connected")
        }

        let toolParams = parameters["tool_parameters"] as? [String: Any] ?? [:]

        do {
            let response = try await server.callTool(name: toolName, parameters: toolParams)

            var result = "# MCP Tool Result\n\n"
            result += "**Server**: \(serverName)\n"
            result += "**Tool**: \(toolName)\n\n"
            result += "## Response\n"
            result += "```json\n\(response)\n```\n"

            return .success(result)
        } catch {
            return .failure("Tool call failed: \(error.localizedDescription)")
        }
    }

    private func discoverServers(context: ToolContext) async throws -> ToolResult {
        // Check common MCP server locations
        let commonPorts = [3000, 3001, 5000, 8000, 8080]
        var discovered: [String] = []

        for port in commonPorts {
            let url = "http://localhost:\(port)"
            if await checkMCPServer(url: url) {
                discovered.append(url)
            }
        }

        var result = "# MCP Server Discovery\n\n"

        if discovered.isEmpty {
            result += "*No MCP servers found on common ports*\n"
        } else {
            result += "Found \(discovered.count) server(s):\n\n"
            for url in discovered {
                result += "- \(url)\n"
            }
        }

        return .success(result, metadata: ["discovered": discovered.count])
    }

    // MARK: - Helper Methods

    private func checkMCPServer(url: String) async -> Bool {
        guard let serverUrl = URL(string: url) else { return false }

        let request = URLRequest(url: serverUrl.appendingPathComponent("/mcp/info"))

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

class MCPServer {
    let name: String
    let url: String
    var isConnected: Bool = false
    var availableTools: [MCPToolInfo] = []

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    func connect() async throws {
        guard let serverUrl = URL(string: url) else {
            throw MCPError.invalidURL
        }

        // Fetch server info
        let infoUrl = serverUrl.appendingPathComponent("/mcp/info")
        let (data, response) = try await URLSession.shared.data(from: infoUrl)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MCPError.connectionFailed
        }

        // Parse server info
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tools = json["tools"] as? [[String: Any]] {
            availableTools = tools.compactMap { MCPToolInfo(json: $0) }
        }

        isConnected = true
    }

    func disconnect() async {
        isConnected = false
    }

    func callTool(name: String, parameters: [String: Any]) async throws -> String {
        guard isConnected else {
            throw MCPError.notConnected
        }

        guard let serverUrl = URL(string: url) else {
            throw MCPError.invalidURL
        }

        let callUrl = serverUrl.appendingPathComponent("/mcp/call")
        var request = URLRequest(url: callUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "tool": name,
            "parameters": parameters
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MCPError.toolCallFailed
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct MCPToolInfo {
    let name: String
    let description: String
    let parameters: [MCPParameterInfo]

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String,
              let description = json["description"] as? String else {
            return nil
        }

        self.name = name
        self.description = description

        if let paramsArray = json["parameters"] as? [[String: Any]] {
            self.parameters = paramsArray.compactMap { MCPParameterInfo(json: $0) }
        } else {
            self.parameters = []
        }
    }
}

struct MCPParameterInfo {
    let name: String
    let type: String
    let description: String
    let required: Bool

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String,
              let type = json["type"] as? String,
              let description = json["description"] as? String else {
            return nil
        }

        self.name = name
        self.type = type
        self.description = description
        self.required = json["required"] as? Bool ?? false
    }
}

enum MCPError: Error {
    case invalidURL
    case connectionFailed
    case notConnected
    case toolCallFailed
}
