//
//  ChatViewModel.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Combine
import AppKit

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

    /// Video/image generation progress
    @Published var generationProgress: Double = 0.0

    /// Video/image generation status message
    @Published var generationStatus: String = ""

    /// Whether video/image is generating
    @Published var isGeneratingMedia: Bool = false

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

        // DEBUG: Log to file
        let debugMsg = "=== sendMessage() called ===\nInput: \(userInput)\n"
        try? debugMsg.write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)

        // Check for direct tool invocations (bypass model tool calling for reliability)
        let handled = await handleDirectToolInvocation(userInput)
        let handleMsg = "Handled by direct tool: \(handled)\n"
        if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
            try? (existingLog + handleMsg).write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
        }

        if handled {
            userInput = ""
            return
        }

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

    /// Handles direct tool invocations by detecting keywords (bypasses model tool calling)
    /// Returns true if handled, false if should proceed with normal chat
    private func handleDirectToolInvocation(_ input: String) async -> Bool {
        let lowercased = input.lowercased()

        // Video generation detection
        if lowercased.contains("generate video") || lowercased.contains("create video") ||
           lowercased.contains("make a video") || lowercased.contains("create animation") {

            print("🎬🎬🎬 KEYWORD DETECTED: Video generation request!")
            try? "🎬 VIDEO KEYWORD DETECTED!\n".write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)

            // Extract prompt
            var prompt = input
            if let colonRange = input.range(of: ":", options: .caseInsensitive) {
                prompt = String(input[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            // Add user message
            let userMessage = Message.user(input)
            if currentConversation == nil {
                var newConv = Conversation.new(withFirstMessage: input)
                newConv.messages = [userMessage]
                currentConversation = newConv
            } else {
                var conv = currentConversation!
                conv.addMessage(userMessage)
                currentConversation = conv
            }

            objectWillChange.send()

            // Show progress UI
            await MainActor.run {
                self.isGeneratingMedia = true
                self.generationProgress = 0.0
                self.generationStatus = "Preparing video generation..."
            }

            // Execute video generation directly
            Task.detached {
                let outputPath = "/tmp/video_\(Date().timeIntervalSince1970).mp4"
                let numFrames = 30  // Default
                let fps = 24

                // Get quality setting
                let quality = await AppSettings.shared.imageQuality
                let steps = quality.steps

                // Create temp directory
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("video_frames_\(Date().timeIntervalSince1970)")
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                // Generate frames
                for frame in 0..<numFrames {
                    // Update progress
                    let progress = Double(frame) / Double(numFrames)
                    await MainActor.run {
                        self.generationProgress = progress
                        self.generationStatus = "Generating frame \(frame + 1)/\(numFrames)..."
                    }
                    let framePrompt = "\(prompt), frame \(frame)"
                    let framePath = tempDir.appendingPathComponent(String(format: "frame_%04d.png", frame)).path

                    let command = """
                    cd ~/mlx-examples/stable_diffusion && \
                    /Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 \
                    txt2image.py "\(framePrompt)" --model sdxl --steps \(steps) --seed \(frame * 42) --n_images 1 --output "\(framePath)"
                    """

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = ["-c", command]
                    try? process.run()

                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        process.terminationHandler = { _ in continuation.resume() }
                    }
                }

                // Update progress
                await MainActor.run {
                    self.generationProgress = 0.95
                    self.generationStatus = "Combining \(numFrames) frames into video..."
                }

                // Combine with FFmpeg
                let ffmpegCommand = """
                /opt/homebrew/bin/ffmpeg -y -framerate \(fps) -pattern_type glob -i '\(tempDir.path)/frame_*.png' \
                -c:v libx264 -pix_fmt yuv420p -preset fast "\(outputPath)"
                """

                let ffmpegProcess = Process()
                ffmpegProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
                ffmpegProcess.arguments = ["-c", ffmpegCommand]
                try? ffmpegProcess.run()

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    ffmpegProcess.terminationHandler = { _ in continuation.resume() }
                }

                // Clean up frames
                try? FileManager.default.removeItem(at: tempDir)

                // Update UI
                await MainActor.run {
                    self.generationProgress = 1.0
                    self.generationStatus = "Complete!"

                    var conv = self.currentConversation!

                    if FileManager.default.fileExists(atPath: outputPath) {
                        let resultMessage = Message.assistant("I've generated the video (\(numFrames) frames at \(fps)fps, \(quality.displayName)). Saved to: \(outputPath)")
                        conv.addMessage(resultMessage)
                        NSWorkspace.shared.open(URL(fileURLWithPath: outputPath))
                    } else {
                        let errorMessage = Message.assistant("Failed to generate video.")
                        conv.addMessage(errorMessage)
                    }

                    self.currentConversation = conv
                    self.objectWillChange.send()

                    if let conv = self.currentConversation {
                        self.saveConversation(conv)
                    }

                    // Clear progress after delay
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        self.isGeneratingMedia = false
                        self.generationProgress = 0.0
                        self.generationStatus = ""
                    }
                }
            }

            return true
        }

        // Image generation detection
        if lowercased.contains("generate image") || lowercased.contains("create image") ||
           lowercased.contains("make an image") || lowercased.contains("generate an image") {

            print("🎨🎨🎨 KEYWORD DETECTED: Image generation request!")
            print("🎨🎨🎨 Input: '\(input)'")
            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "🎨 KEYWORD DETECTED!\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }
            logInfo("🎨 Direct image generation request detected", category: "ChatViewModel")

            // Extract prompt (text after "generate image:" or similar)
            var prompt = input
            if let colonRange = input.range(of: ":", options: .caseInsensitive) {
                prompt = String(input[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "📝 Extracted prompt: '\(prompt)'\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }

            // Add user message
            let userMessage = Message.user(input)

            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "💬 Created user message\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }

            if currentConversation == nil {
                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "📂 Creating new conversation\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }
                var newConv = Conversation.new(withFirstMessage: input)
                // Remove the auto-added message since we're adding our own
                newConv.messages = [userMessage]
                currentConversation = newConv
            } else {
                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "📂 Adding to existing conversation\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }
                var conv = currentConversation!
                conv.addMessage(userMessage)
                currentConversation = conv
            }

            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "🔄 Forcing UI update\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }

            // Force immediate UI update
            objectWillChange.send()

            // Show progress UI
            await MainActor.run {
                self.isGeneratingMedia = true
                self.generationProgress = 0.0
                self.generationStatus = "Generating image..."
            }

            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "🔧 About to execute tool\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }

            // Execute image generation tool directly
            let toolParams: [String: Any] = ["prompt": prompt]
            let context = createToolContext()

            print("🔧🔧🔧 About to execute generate_image_local tool")
            print("🔧🔧🔧 Parameters: \(toolParams)")

            if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                try? (existingLog + "🚀 Running Python script directly...\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
            }

            // BYPASS TOOL REGISTRY - Run Python script directly to avoid deadlock
            Task.detached {
                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "🔵 INSIDE Task.detached block\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                let outputPath = "/tmp/generated_\(Date().timeIntervalSince1970).png"

                // Get quality setting
                let quality = await AppSettings.shared.imageQuality
                let steps = quality.steps

                // Get selected model info
                let selectedModelId = await AppSettings.shared.selectedImageModel
                let selectedModel = await AppSettings.shared.availableImageModels.first(where: { $0.id == selectedModelId })

                // Determine model argument for txt2image.py
                let modelArg: String
                if let model = selectedModel, model.id == "flux" {
                    // FLUX uses separate script
                    modelArg = "flux"
                } else if let model = selectedModel, model.id == "sd-1.5" || model.huggingFaceId.contains("1-5") {
                    modelArg = "sd"
                } else {
                    // Default to SDXL
                    modelArg = "sdxl"
                }

                let command = "cd ~/mlx-examples/stable_diffusion && /Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 txt2image.py \"\(prompt)\" --model \(modelArg) --steps \(steps) --output \(outputPath)"

                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "📝 Command: \(command)\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]

                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "🚀 About to process.run()\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                try? process.run()

                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "✅ Process started, PID: \(process.processIdentifier)\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "⏳ Polling for image file...\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                // Poll for image completion (more reliable than terminationHandler)
                var imageExists = false
                for attempt in 0..<60 { // Wait up to 30 seconds
                    if FileManager.default.fileExists(atPath: outputPath) {
                        imageExists = true
                        break
                    }

                    // Update progress
                    let progress = 0.1 + (Double(attempt) / 60.0 * 0.9)
                    await MainActor.run {
                        self.generationProgress = progress
                        self.generationStatus = "Generating image... \(Int(progress * 100))%"
                    }

                    try? await Task.sleep(for: .milliseconds(500))
                }

                if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                    try? (existingLog + "📊 Image exists: \(imageExists)\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                }

                let success = imageExists

                // Get quality for message
                let qualitySetting = await AppSettings.shared.imageQuality

                await MainActor.run {
                    self.generationProgress = 1.0
                    self.generationStatus = "Complete!"
                }

                // Update UI on MainActor
                await MainActor.run {
                    if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                        try? (existingLog + "🎯 On MainActor now\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                    }

                    var conv = self.currentConversation!

                    if success && FileManager.default.fileExists(atPath: outputPath) {
                        let resultMessage = Message.assistant("I've generated the image (\(qualitySetting.displayName)). Saved to: \(outputPath)")
                        conv.addMessage(resultMessage)

                        if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                            try? (existingLog + "🖼️ Opening in Preview...\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                        }

                        // Open in Preview
                        NSWorkspace.shared.open(URL(fileURLWithPath: outputPath))
                    } else {
                        let errorMessage = Message.assistant("Failed to generate image. Check console for errors.")
                        conv.addMessage(errorMessage)
                    }

                    self.currentConversation = conv
                    self.objectWillChange.send()

                    if let conv = self.currentConversation {
                        self.saveConversation(conv)
                    }

                    // Clear progress after delay
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        self.isGeneratingMedia = false
                        self.generationProgress = 0.0
                        self.generationStatus = ""
                    }

                    if let existingLog = try? String(contentsOfFile: "/tmp/mlx_debug.log") {
                        try? (existingLog + "✅ ALL DONE!\n").write(toFile: "/tmp/mlx_debug.log", atomically: false, encoding: .utf8)
                    }
                }
            }

            return true
        }

        // Speech detection
        if lowercased.hasPrefix("speak:") || lowercased.hasPrefix("say:") || lowercased.contains("read this aloud") {
            logInfo("🎙️ Direct speech request detected", category: "ChatViewModel")

            // Extract text to speak
            var text = input
            if lowercased.hasPrefix("speak:") {
                text = String(input.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if lowercased.hasPrefix("say:") {
                text = String(input.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            }

            // Add user message
            let userMessage = Message.user(input)
            if currentConversation == nil {
                currentConversation = Conversation.new(withFirstMessage: input)
            } else {
                currentConversation?.addMessage(userMessage)
            }

            // Execute TTS tool directly
            let toolParams: [String: Any] = ["text": text]
            let context = createToolContext()

            do {
                // Execute tool in detached task to avoid MainActor deadlock
                let result = try await Task.detached {
                    return try await ToolRegistry.shared.executeTool(name: "native_tts", parameters: toolParams, context: context)
                }.value

                let resultMessage = Message.assistant(result.success ? "I've spoken the text." : "Failed to speak: \(result.output)")
                currentConversation?.addMessage(resultMessage)

                // Force view update
                objectWillChange.send()

                if let conv = currentConversation {
                    saveConversation(conv)
                }
                return true
            } catch {
                let errorMessage = Message.assistant("Error with speech: \(error.localizedDescription)")
                currentConversation?.addMessage(errorMessage)
                if let conv = currentConversation {
                    saveConversation(conv)
                }
                return true
            }
        }

        // Not a direct tool invocation
        return false
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

                        // Check for tool calls - stop generation if complete tool call detected
                        if accumulatedResponse.contains("</tool_call>") {
                            logInfo("🔧 Tool call detected in response! Stopping generation to execute tools.", category: "ChatViewModel")
                            shouldStopGeneration = true
                            await PythonService.shared.terminate()
                            return
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
