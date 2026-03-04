//
//  ChatViewModel+Tools.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Extension adding tool execution capabilities to ChatViewModel
extension ChatViewModel {
    /// Tool registry for accessing tools
    var toolRegistry: ToolRegistry {
        return ToolRegistry.shared
    }

    /// Memory system for context
    var memorySystem: MemorySystem {
        return MemorySystem.shared
    }

    /// Enable tool mode for the LLM
    var toolModeEnabled: Bool {
        get {
            return AppSettings.shared.enableTools
        }
        set {
            AppSettings.shared.enableTools = newValue
        }
    }

    // MARK: - Tool Call Detection

    /// Check if response contains tool calls (new JSON or legacy format)
    func containsToolCalls(_ text: String) -> Bool {
        return text.contains("<tool>") || text.contains("<tool_call>")
    }

    /// Extract tool calls from text (supports both new JSON and legacy formats)
    func extractToolCalls(_ text: String) -> [String] {
        var toolCalls: [String] = []

        // New format: <tool>JSON</tool>
        let newPattern = "<tool>\\s*(.+?)\\s*</tool>"
        if let regex = try? NSRegularExpression(pattern: newPattern, options: [.dotMatchesLineSeparators]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let toolCall = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    toolCalls.append(toolCall)
                }
            }
        }

        // Also check legacy format: <tool_call>...</tool_call>
        if toolCalls.isEmpty {
            let legacyPattern = "<tool_call>\\s*(.+?)\\s*</tool_call>"
            if let regex = try? NSRegularExpression(pattern: legacyPattern, options: [.dotMatchesLineSeparators]) {
                let nsString = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let toolCall = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        toolCalls.append(toolCall)
                    }
                }
            }
        }

        return toolCalls
    }

    // MARK: - Tool Execution

    /// Execute tool calls from LLM response (supports JSON and legacy formats)
    func executeToolCalls(_ toolCalls: [String]) async -> [ToolResult] {
        var results: [ToolResult] = []

        for toolCall in toolCalls {
            logInfo("Executing tool call: \(toolCall)", category: "ChatViewModel+Tools")

            do {
                let context = createToolContext()

                // Try JSON format first, then fall back to legacy
                if let (name, params) = toolRegistry.parseToolCallJSON(toolCall) {
                    let result = try await toolRegistry.executeTool(name: name, parameters: params, context: context)
                    results.append(result)
                } else {
                    // Direct legacy parse
                    let result = try await toolRegistry.parseAndExecuteToolCall(toolCall, context: context)
                    results.append(result)
                }

                logInfo("Tool execution succeeded: \(toolCall)", category: "ChatViewModel+Tools")
            } catch {
                let errorResult = ToolResult.failure("Tool execution failed: \(error.localizedDescription)")
                results.append(errorResult)

                logError("Tool execution failed: \(error.localizedDescription)", category: "ChatViewModel+Tools")
            }
        }

        return results
    }

    /// Create tool context for execution
    func createToolContext() -> ToolContext {
        let workingDirectory = AppSettings.shared.workingDirectory
        let projectPath = AppSettings.shared.projectPath

        return ToolContext(
            workingDirectory: workingDirectory,
            conversationHistory: currentConversation?.messages ?? [],
            projectPath: projectPath,
            settings: AppSettings.shared,
            memory: memorySystem
        )
    }

    // MARK: - System Prompt Generation

    /// Generate system prompt with tool descriptions
    func generateSystemPrompt() -> String {
        if toolModeEnabled {
            return SystemPrompts.generateSystemPrompt(includeTools: true)
        } else {
            return SystemPrompts.baseSystemPrompt
        }
    }

    /// Prepend system prompt to conversation
    func prepareMessagesWithSystemPrompt() -> [Message] {
        guard let conversation = currentConversation else {
            return []
        }

        // Check if first message is already system prompt
        if let firstMessage = conversation.messages.first,
           firstMessage.role == .system {
            // Already has system prompt
            return conversation.messages
        }

        // Prepend system prompt
        let systemPrompt = generateSystemPrompt()
        let systemMessage = Message.system(systemPrompt)

        return [systemMessage] + conversation.messages
    }

    // MARK: - Tool-Aware Response Generation

    /// Send message with tool awareness
    func sendMessageWithTools() async {
        logInfo("Sending message with tools enabled", category: "ChatViewModel+Tools")

        // Regular send message flow
        await sendMessage()

        // After generation, check for tool calls
        if let lastMessage = currentConversation?.messages.last,
           lastMessage.role == .assistant {
            await handleToolCallsInResponse(lastMessage.content)
        }
    }

    /// Handle tool calls found in assistant response (with approval flow and retry on parse failure)
    func handleToolCallsInResponse(_ response: String, retryCount: Int = 0) async {
        let toolCallStrings = extractToolCalls(response)

        // If the model generated a tool tag but we couldn't parse anything valid, prompt it to retry
        if toolCallStrings.isEmpty && response.contains("<tool>") && retryCount < 2 {
            let retryMessage = Message.system("""
            Your previous response contained a malformed tool call that could not be parsed. \
            Use EXACTLY this format with valid JSON (double quotes, no trailing commas):
            <tool>
            {"name": "tool_name", "args": {"key": "value"}}
            </tool>
            Please try again.
            """)
            currentConversation?.addMessage(retryMessage)
            await generateResponse()
            return
        }

        guard !toolCallStrings.isEmpty else { return }

        logInfo("Found \(toolCallStrings.count) tool call(s) in response", category: "ChatViewModel+Tools")

        // Parse tool calls into PendingToolCall structs
        var pending: [PendingToolCall] = []
        for rawCall in toolCallStrings {
            if let (name, params) = toolRegistry.parseToolCallJSON(rawCall) {
                var call = PendingToolCall(toolName: name, parameters: params, rawJSON: rawCall)
                // Check approval policy
                call.approved = toolApprovalPolicy.shouldAutoApprove(toolName: name, parameters: params)
                pending.append(call)
            } else {
                // Legacy format — try to parse it
                var call = PendingToolCall(toolName: rawCall, parameters: [:], rawJSON: rawCall)
                call.approved = toolApprovalPolicy == .autoApproveAll
                pending.append(call)
            }
        }

        // If any calls need approval, show the approval UI and wait
        let needsApproval = pending.contains { !$0.approved }
        if needsApproval {
            logInfo("Tool calls need user approval", category: "ChatViewModel+Tools")
            pendingToolCalls = pending
            // UI will display ToolApprovalView; user calls approvePendingTools() or denyPendingTools()
            return
        }

        // All auto-approved, execute immediately
        await executePendingToolCalls(pending)
    }

    /// Called by UI when user approves pending tool calls
    func approvePendingTools() async {
        var approved = pendingToolCalls
        for i in approved.indices {
            approved[i].approved = true
        }
        pendingToolCalls = []
        await executePendingToolCalls(approved)
    }

    /// Called by UI when user denies pending tool calls
    func denyPendingTools() {
        let deniedNames = pendingToolCalls.map(\.toolName).joined(separator: ", ")
        var deniedMessage = Message.system("Tool calls denied by user: \(deniedNames)")
        deniedMessage.metadata = ["collapsible": "true", "collapsed": "true"]
        currentConversation?.addMessage(deniedMessage)
        pendingToolCalls = []
    }

    /// Execute approved tool calls and continue the agentic loop
    private func executePendingToolCalls(_ calls: [PendingToolCall]) async {
        let approvedCalls = calls.filter(\.approved)
        guard !approvedCalls.isEmpty else { return }

        let results = await executeToolCalls(approvedCalls.map(\.rawJSON))

        // Format results compactly for the model
        var resultText = ""
        for (index, result) in results.enumerated() {
            resultText += "<tool_result>\n"
            resultText += result.toJSON()
            resultText += "\n</tool_result>\n"
            if index < results.count - 1 { resultText += "\n" }
        }

        // Add results as system message
        var resultMessage = Message.system(resultText)
        resultMessage.metadata = ["collapsible": "true", "collapsed": "true"]
        currentConversation?.addMessage(resultMessage)

        // Continue the agentic loop — generate follow-up response
        if !results.isEmpty && results.allSatisfy({ $0.success }) {
            logInfo("All tools succeeded, continuing agentic loop", category: "ChatViewModel+Tools")
            await generateResponse()
        } else if !results.isEmpty {
            logInfo("Some tools failed, generating follow-up with error context", category: "ChatViewModel+Tools")
            await generateResponse()
        }
    }

    // MARK: - Tool UI Actions

    /// Manually trigger a tool execution from UI
    func executeToolManually(toolName: String, parameters: [String: Any]) async -> ToolResult {
        logInfo("Manual tool execution: \(toolName)", category: "ChatViewModel+Tools")

        let context = createToolContext()

        do {
            let result = try await toolRegistry.executeTool(name: toolName, parameters: parameters, context: context)

            // Add tool result to conversation
            let resultMessage = Message.system("Tool result:\n\(result.toJSON())")
            currentConversation?.addMessage(resultMessage)

            return result
        } catch {
            let errorResult = ToolResult.failure(error.localizedDescription)
            return errorResult
        }
    }

    /// List all available tools
    func getAvailableTools() -> [Tool] {
        return toolRegistry.getAllTools()
    }

    /// Get tool execution history
    func getToolExecutionHistory() -> [ToolExecutionSummary] {
        return toolRegistry.getRecentExecutions(count: 20)
    }

    // MARK: - Context Management

    /// Build context for LLM including memory
    func buildContextString() -> String {
        return memorySystem.buildContext(conversationHistory: currentConversation?.messages ?? [])
    }

    /// Store important information in memory
    func storeInMemory(key: String, value: String, type: MemoryType = .shortTerm) {
        memorySystem.store(key: key, value: value, type: type)
        logInfo("Stored in memory: \(key)", category: "ChatViewModel+Tools")
    }

    /// Retrieve from memory
    func retrieveFromMemory(key: String) -> String? {
        return memorySystem.retrieve(key: key)
    }

    /// Clear short-term memory
    func clearShortTermMemory() {
        memorySystem.clearShortTerm()
        logInfo("Cleared short-term memory", category: "ChatViewModel+Tools")
    }

    // MARK: - Project Context

    /// Set project context
    func setProjectContext(name: String, path: String, language: String? = nil) {
        let context = ProjectContext(
            name: name,
            path: path,
            primaryLanguage: language,
            dependencies: [],
            metadata: [:]
        )

        memorySystem.setProjectContext(context)
        logInfo("Set project context: \(name) at \(path)", category: "ChatViewModel+Tools")
    }

    /// Auto-detect project context from working directory
    func autoDetectProjectContext() {
        let workingDir = AppSettings.shared.workingDirectory
        let fileManager = FileManager.default

        // Look for .xcodeproj or .xcworkspace
        guard let contents = try? fileManager.contentsOfDirectory(atPath: workingDir) else {
            return
        }

        if let projectFile = contents.first(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            let projectName = (projectFile as NSString).deletingPathExtension
            let projectPath = (workingDir as NSString).appendingPathComponent(projectFile)

            setProjectContext(name: projectName, path: projectPath, language: "Swift")

            logInfo("Auto-detected Xcode project: \(projectName)", category: "ChatViewModel+Tools")
        }
    }
}

// MARK: - AppSettings Extension for Tool Settings

extension AppSettings {
    /// Enable tool execution
    var enableTools: Bool {
        get {
            // Check if value has been set before
            if UserDefaults.standard.object(forKey: "enableTools") == nil {
                return true  // Default to enabled
            }
            return UserDefaults.standard.bool(forKey: "enableTools")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "enableTools")
        }
    }

    /// Working directory for tool execution
    var workingDirectory: String {
        get {
            return UserDefaults.standard.string(forKey: "workingDirectory") ?? FileManager.default.currentDirectoryPath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "workingDirectory")
        }
    }

    /// Project path (optional)
    var projectPath: String? {
        get {
            return UserDefaults.standard.string(forKey: "projectPath")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "projectPath")
        }
    }
}
