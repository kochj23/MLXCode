//
//  ChatViewModel.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Combine

/// Main view model for the chat interface
/// Manages conversation state and MLX model interactions
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current conversation
    @Published var currentConversation: Conversation?

    /// All saved conversations
    @Published var conversations: [Conversation] = []

    /// Current user input
    @Published var userInput: String = ""

    /// Whether the model is currently generating
    @Published var isGenerating: Bool = false

    /// Whether a model is loaded
    @Published var isModelLoaded: Bool = false

    /// Current status message
    @Published var statusMessage: String = "Ready"

    /// Error message to display
    @Published var errorMessage: String?

    /// Progress indicator (0.0 to 1.0)
    @Published var progress: Double = 0.0

    /// Current token count for user input
    @Published var inputTokenCount: Int = 0

    /// Maximum context window size
    @Published var maxTokens: Int = 8192

    /// Tokens per second performance metric
    @Published var tokensPerSecond: Double = 0.0

    /// Total tokens generated in current response
    @Published var currentTokenCount: Int = 0

    /// Whether to show performance metrics
    @Published var showPerformanceMetrics: Bool = true

    /// Whether we're waiting for the first token (initial thinking phase)
    @Published var isWaitingForFirstToken: Bool = false

    /// Total tokens generated in the entire conversation
    @Published var conversationTotalTokens: Int = 0

    /// Average tokens per second for the conversation
    @Published var conversationAverageTokensPerSecond: Double = 0.0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let conversationsDirectory: URL
    private var streamingMessageId: UUID?
    private var generationStartTime: Date?
    private var tokenCount: Int = 0
    private var repetitionDetector: RepetitionDetector?
    private var conversationStartTime: Date?
    private var totalGenerationTime: TimeInterval = 0.0

    // MARK: - Initialization

    init() {
        // Setup conversations directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        conversationsDirectory = appSupport.appendingPathComponent("MLX Code/Conversations", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: conversationsDirectory, withIntermediateDirectories: true)

        // Load conversations
        loadConversations()

        // Setup auto-save
        setupAutoSave()

        // Load model status
        Task { [weak self] in
            await self?.updateModelStatus()
        }

        // Observe model selection changes
        setupModelObserver()

        // Observe input changes for token counting
        setupTokenCounter()
    }

    /// Sets up an observer for model selection changes
    private func setupModelObserver() {
        AppSettings.shared.$selectedModel
            .sink { [weak self] _ in
                Task { [weak self] in
                    // Give model time to load
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    await self?.updateModelStatus()

                    // Check again after another delay to be sure
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 more second
                    await self?.updateModelStatus()
                }
            }
            .store(in: &cancellables)
    }

    /// Sets up token counter for user input
    private func setupTokenCounter() {
        $userInput
            .sink { [weak self] text in
                self?.inputTokenCount = self?.estimateTokenCount(text) ?? 0
            }
            .store(in: &cancellables)
    }

    /// Estimates token count (rough approximation: 1 token ≈ 4 characters)
    private func estimateTokenCount(_ text: String) -> Int {
        // Simple estimation: ~4 characters per token on average
        return max(1, text.count / 4)
    }

    // MARK: - Public Methods

    /// Sends a message to the model
    func sendMessage() async {
        await LogManager.shared.info("Sending message", category: "Chat")

        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await LogManager.shared.warning("Empty input ignored", category: "Chat")
            return
        }

        logInfo("📝 Input received: \(userInput.prefix(50))...", category: "ChatViewModel")

        // Sanitize input
        let sanitizedInput = SecurityUtils.sanitizeUserInput(userInput)
        logInfo("✅ Input sanitized", category: "ChatViewModel")

        // Validate input length
        guard SecurityUtils.validateLength(sanitizedInput, max: 10_000) else {
            errorMessage = "Message is too long. Maximum 10,000 characters."
            logError("❌ Input too long", category: "ChatViewModel")
            return
        }

        // Create user message
        let userMessage = Message.user(sanitizedInput)
        logInfo("✅ User message created with ID: \(userMessage.id)", category: "ChatViewModel")

        // Add to conversation or create new one
        if currentConversation == nil {
            currentConversation = Conversation.new(withFirstMessage: sanitizedInput)
            logInfo("✅ New conversation created", category: "ChatViewModel")

            // Add system prompt with tool descriptions if tools are enabled
            if toolModeEnabled {
                let systemPrompt = generateSystemPrompt()
                let systemMessage = Message.system(systemPrompt)
                // Insert at beginning
                if let conv = currentConversation {
                    var messages = conv.messages
                    messages.insert(systemMessage, at: 0)
                    currentConversation?.messages = messages
                    logInfo("✅ Added system prompt with tool descriptions", category: "ChatViewModel")
                }
            }
        } else {
            currentConversation?.addMessage(userMessage)
            logInfo("✅ Message added to existing conversation", category: "ChatViewModel")
        }

        // Clear input
        userInput = ""

        // Generate response
        logInfo("🔄 Calling generateResponse()...", category: "ChatViewModel")
        await generateResponse()
    }

    /// Creates a new conversation
    func newConversation() {
        // Save current conversation if it exists
        if let current = currentConversation, !current.isEmpty {
            saveConversation(current)
        }

        // Create new conversation
        currentConversation = Conversation(title: "New Conversation")

        // Reset conversation metrics
        conversationTotalTokens = 0
        conversationAverageTokensPerSecond = 0.0
        totalGenerationTime = 0.0
        conversationStartTime = Date()

        logInfo("Created new conversation", category: "ChatViewModel")
    }

    /// Loads a conversation
    /// - Parameter conversation: The conversation to load
    func loadConversation(_ conversation: Conversation) {
        // Save current conversation if needed
        if let current = currentConversation, !current.isEmpty, current.id != conversation.id {
            saveConversation(current)
        }

        currentConversation = conversation

        logInfo("Loaded conversation: \(conversation.title)", category: "ChatViewModel")
    }

    /// Deletes a conversation
    /// - Parameter conversation: The conversation to delete
    func deleteConversation(_ conversation: Conversation) {
        // Remove from list
        conversations.removeAll { $0.id == conversation.id }

        // Delete file
        let fileURL = conversationsDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)

        // Clear current if deleted
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }

        logInfo("Deleted conversation: \(conversation.title)", category: "ChatViewModel")
    }

    /// Loads an MLX model
    /// - Parameter model: The model to load
    func loadModel(_ model: MLXModel) async {
        statusMessage = "Loading model..."
        errorMessage = nil

        do {
            try await MLXService.shared.loadModel(model)
            isModelLoaded = true
            statusMessage = "Model loaded: \(model.name)"

            logInfo("Model loaded: \(model.name)", category: "ChatViewModel")
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            isModelLoaded = false
            statusMessage = "Model load failed"

            logError("Failed to load model: \(error.localizedDescription)", category: "ChatViewModel")
        }
    }

    /// Unloads the current model
    func unloadModel() async {
        await MLXService.shared.unloadModel()
        isModelLoaded = false
        statusMessage = "Model unloaded"

        logInfo("Model unloaded", category: "ChatViewModel")
    }

    /// Stops the current generation
    func stopGeneration() {
        guard isGenerating else { return }

        Task {
            await PythonService.shared.terminate()
            isGenerating = false
            isWaitingForFirstToken = false
            statusMessage = "Generation stopped"

            logInfo("Generation stopped by user", category: "ChatViewModel")
        }
    }

    /// Regenerates the last assistant response
    func regenerateLastResponse() async {
        guard let conversation = currentConversation else {
            await LogManager.shared.warning("No conversation to regenerate", category: "Chat")
            return
        }

        // Find the last assistant message
        guard let lastAssistantIndex = conversation.messages.lastIndex(where: { $0.role == .assistant }) else {
            await LogManager.shared.warning("No assistant message to regenerate", category: "Chat")
            return
        }

        // Remove the last assistant message
        currentConversation?.messages.remove(at: lastAssistantIndex)

        // Regenerate response
        await generateResponse()
        await LogManager.shared.info("Regenerated last response", category: "Chat")
    }

    /// Exports a conversation to JSON
    /// - Parameter conversation: The conversation to export
    /// - Returns: JSON data or nil
    func exportConversation(_ conversation: Conversation) -> Data? {
        return conversation.toJSONData()
    }

    /// Imports a conversation from JSON data
    /// - Parameter data: JSON data to import
    func importConversation(from data: Data) {
        guard let conversation = Conversation.fromJSONData(data) else {
            errorMessage = "Failed to import conversation: Invalid format"
            return
        }

        // Add to conversations list
        conversations.append(conversation)

        // Save to disk
        saveConversation(conversation)

        logInfo("Imported conversation: \(conversation.title)", category: "ChatViewModel")
    }

    // MARK: - Private Methods

    /// Generates a response from the model
    func generateResponse() async {
        logInfo("🎯 generateResponse() called", category: "ChatViewModel")

        guard let conversation = currentConversation else {
            logError("❌ No current conversation", category: "ChatViewModel")
            return
        }

        logInfo("📊 Conversation has \(conversation.messages.count) messages", category: "ChatViewModel")

        guard isModelLoaded else {
            errorMessage = "No model is loaded. Please load a model first."
            logError("❌ No model loaded", category: "ChatViewModel")
            return
        }

        logInfo("✅ Model is loaded, starting generation", category: "ChatViewModel")

        isGenerating = true
        isWaitingForFirstToken = true
        statusMessage = "Preparing response..."
        errorMessage = nil

        // Reset performance metrics
        tokenCount = 0
        currentTokenCount = 0
        tokensPerSecond = 0.0
        generationStartTime = Date()

        // Initialize repetition detector
        repetitionDetector = RepetitionDetector(
            minPatternLength: 15,
            maxPatternLength: 300,
            repetitionThreshold: 3,
            maxBufferSize: 2000
        )

        // Create placeholder assistant message
        let assistantMessage = Message.assistant("")
        streamingMessageId = assistantMessage.id
        currentConversation?.addMessage(assistantMessage)
        logInfo("✅ Placeholder assistant message created with ID: \(assistantMessage.id)", category: "ChatViewModel")

        var accumulatedResponse = ""
        var shouldStopGeneration = false

        do {
            logInfo("🔵 Calling MLXService.shared.chatCompletion()...", category: "ChatViewModel")
            logInfo("📤 Sending \(conversation.messages.count) messages to MLX service", category: "ChatViewModel")

            // Get response from MLX service with streaming
            let response = try await MLXService.shared.chatCompletion(
                messages: conversation.messages,
                parameters: AppSettings.shared.selectedModel?.parameters,
                streamHandler: { [weak self] token in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }

                        // Check if we should stop generation
                        guard !shouldStopGeneration else {
                            logWarning("⚠️ Stopping generation due to repetition/length limit", category: "ChatViewModel")
                            return
                        }

                        // First token received - update status
                        if self.isWaitingForFirstToken {
                            self.isWaitingForFirstToken = false
                            self.statusMessage = "Generating..."
                            logInfo("✨ First token received!", category: "ChatViewModel")
                        }

                        accumulatedResponse += token

                        // Update token count
                        self.tokenCount += 1
                        self.currentTokenCount = self.tokenCount

                        // Calculate tokens per second
                        if let startTime = self.generationStartTime {
                            let elapsed = Date().timeIntervalSince(startTime)
                            if elapsed > 0 {
                                self.tokensPerSecond = Double(self.tokenCount) / elapsed
                            }
                        }

                        // Check for repetition
                        if let detector = self.repetitionDetector {
                            let hasRepetition = detector.addToken(token)
                            let hasExcessiveRepetition = detector.detectExcessiveRepetition()

                            if hasRepetition || hasExcessiveRepetition {
                                logWarning("🔁 Repetition detected! Stopping generation.", category: "ChatViewModel")
                                logWarning("   Pattern detected in buffer: \(detector.currentBuffer.suffix(200))", category: "ChatViewModel")
                                shouldStopGeneration = true

                                // Truncate response to remove repetition
                                if accumulatedResponse.count > 500 {
                                    // Keep first 80% of response, discard repetitive tail
                                    let keepLength = Int(Double(accumulatedResponse.count) * 0.8)
                                    let truncateIndex = accumulatedResponse.index(accumulatedResponse.startIndex, offsetBy: keepLength)
                                    accumulatedResponse = String(accumulatedResponse[..<truncateIndex])
                                    accumulatedResponse += "\n\n[Response truncated due to repetition detection]"
                                }

                                // Force stop by throwing error
                                await PythonService.shared.terminate()
                            }
                        }

                        // Check for maximum length
                        if accumulatedResponse.count > ChatViewModel.maxResponseLength {
                            logWarning("📏 Maximum response length reached! Stopping generation.", category: "ChatViewModel")
                            shouldStopGeneration = true
                            accumulatedResponse += "\n\n[Response truncated: maximum length reached]"
                            await PythonService.shared.terminate()
                        }

                        // Check for maximum token count
                        if self.tokenCount > ChatViewModel.maxResponseTokens {
                            logWarning("🎫 Maximum token count reached! Stopping generation.", category: "ChatViewModel")
                            shouldStopGeneration = true
                            accumulatedResponse += "\n\n[Response truncated: maximum tokens reached]"
                            await PythonService.shared.terminate()
                        }

                        logInfo("🔹 Received token (length: \(token.count)), total: \(self.tokenCount), speed: \(String(format: "%.1f", self.tokensPerSecond)) t/s", category: "ChatViewModel")

                        // Update the message content
                        if let messageId = self.streamingMessageId,
                           let index = self.currentConversation?.messages.firstIndex(where: { $0.id == messageId }) {
                            self.currentConversation?.messages[index].content = accumulatedResponse
                        }
                    }
                }
            )

            logInfo("✅ MLXService.chatCompletion() completed, response length: \(response.count)", category: "ChatViewModel")

            // Update final message
            if let messageId = streamingMessageId,
               let index = currentConversation?.messages.firstIndex(where: { $0.id == messageId }) {
                currentConversation?.messages[index].content = response
            }

            isGenerating = false
            isWaitingForFirstToken = false
            statusMessage = "Ready"
            streamingMessageId = nil

            // Update conversation totals
            if let startTime = generationStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                totalGenerationTime += elapsed
                conversationTotalTokens += tokenCount

                // Calculate average tokens per second for conversation
                if totalGenerationTime > 0 {
                    conversationAverageTokensPerSecond = Double(conversationTotalTokens) / totalGenerationTime
                }
            }

            // Save conversation
            if let conversation = currentConversation {
                saveConversation(conversation)
            }

            logInfo("Response generated successfully", category: "ChatViewModel")

            // Check for tool calls and execute them if tools are enabled
            if toolModeEnabled && containsToolCalls(response) {
                logInfo("🔧 Tool calls detected in response", category: "ChatViewModel")
                await handleToolCallsInResponse(response)
            }
        } catch {
            errorMessage = "Failed to generate response: \(error.localizedDescription)"
            isGenerating = false
            isWaitingForFirstToken = false
            statusMessage = "Generation failed"
            streamingMessageId = nil

            // Remove placeholder message
            if let messageId = streamingMessageId {
                currentConversation?.removeMessage(withId: messageId)
            }

            logError("Failed to generate response: \(error.localizedDescription)", category: "ChatViewModel")
        }
    }

    /// Updates the model loaded status
    private func updateModelStatus() async {
        isModelLoaded = await MLXService.shared.isLoaded()

        if let model = await MLXService.shared.getCurrentModel() {
            statusMessage = "Model loaded: \(model.name)"
        } else {
            statusMessage = "No model loaded"
        }
    }

    /// Loads all saved conversations
    private func loadConversations() {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: conversationsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let conversation = Conversation.fromJSONData(data) {
                conversations.append(conversation)
            }
        }

        // Sort by last activity
        conversations.sort { $0.lastActivity > $1.lastActivity }

        logInfo("Loaded \(conversations.count) conversations", category: "ChatViewModel")
    }

    /// Saves a conversation to disk
    /// - Parameter conversation: The conversation to save
    private func saveConversation(_ conversation: Conversation) {
        guard conversation.isValid() else {
            logWarning("Attempted to save invalid conversation", category: "ChatViewModel")
            return
        }

        let fileURL = conversationsDirectory.appendingPathComponent("\(conversation.id.uuidString).json")

        if let data = conversation.toJSONData() {
            try? data.write(to: fileURL)

            // Update in conversations list
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = conversation
            } else {
                conversations.append(conversation)
            }

            // Re-sort
            conversations.sort { $0.lastActivity > $1.lastActivity }
        }
    }

    /// Sets up auto-save for current conversation
    private func setupAutoSave() {
        // Auto-save when conversation changes
        $currentConversation
            .debounce(for: .seconds(2.0), scheduler: DispatchQueue.main)
            .sink { [weak self] conversation in
                guard let conversation = conversation, !conversation.isEmpty else { return }
                self?.saveConversation(conversation)
            }
            .store(in: &cancellables)
    }

    // MARK: - Logging Helpers

    private func logInfo(_ message: String, category: String) {
        Task {
            await LogManager.shared.info(message, category: category)
        }
    }

    private func logWarning(_ message: String, category: String) {
        Task {
            await LogManager.shared.warning(message, category: category)
        }
    }

    private func logError(_ message: String, category: String) {
        Task {
            await LogManager.shared.error(message, category: category)
        }
    }

    // MARK: - Memory Safety

    deinit {
        cancellables.removeAll()
    }
}

// MARK: - File Operations

extension ChatViewModel {
    /// Reads a file using FileService
    /// - Parameter path: Path to the file
    /// - Returns: File contents
    func readFile(at path: String) async throws -> String {
        return try await FileService.shared.read(path: path)
    }

    /// Writes content to a file
    /// - Parameters:
    ///   - content: Content to write
    ///   - path: Destination path
    func writeFile(content: String, to path: String) async throws {
        try await FileService.shared.write(content: content, to: path)
    }

    /// Searches files with a pattern
    /// - Parameters:
    ///   - pattern: Glob pattern
    ///   - directory: Base directory
    /// - Returns: Matching file paths
    func searchFiles(pattern: String, in directory: String) async throws -> [String] {
        return try await FileService.shared.glob(pattern: pattern, in: directory)
    }
}
