//
//  MLXServiceTests.swift
//  MLX Code Tests
//
//  Unit tests for MLXService's generation state machine: streaming, cancellation
//  (Stop), busy-flag reset, KV/parameter plumbing, native tool-call mapping and
//  download file patterns. Uses a mock InferenceGenerator — no model download.
//
//  Optional integration test: set MLXCODE_INTEGRATION=1 and MLXCODE_MODEL_PATH=<local
//  mlx model dir> (via `TEST_RUNNER_MLXCODE_INTEGRATION=1` etc. with xcodebuild).
//

import XCTest
@testable import MLX_Code

// MARK: - Mock Generator

/// Scripted generator: yields `events`, then (optionally) keeps streaming until cancelled.
final class MockInferenceGenerator: InferenceGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private let events: [InferenceEvent]
    private let streamUntilCancelled: Bool
    private var _requests: [InferenceRequest] = []
    private var _terminations = 0

    init(events: [InferenceEvent], streamUntilCancelled: Bool = false) {
        self.events = events
        self.streamUntilCancelled = streamUntilCancelled
    }

    var requests: [InferenceRequest] { lock.withLock { _requests } }
    var terminations: Int { lock.withLock { _terminations } }

    func generate(_ request: InferenceRequest) async throws -> AsyncStream<InferenceEvent> {
        lock.withLock { _requests.append(request) }
        let events = self.events
        let endless = streamUntilCancelled
        return AsyncStream { continuation in
            let producer = Task {
                for event in events { continuation.yield(event) }
                var counter = 0
                while endless && !Task.isCancelled {
                    // Unique chunks so ChatViewModel's RepetitionDetector never trips.
                    counter += 1
                    continuation.yield(.chunk("w\(counter)-\(UUID().uuidString.prefix(6)) "))
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
                continuation.finish()
            }
            continuation.onTermination = { [weak self] _ in
                producer.cancel()
                self?.lock.withLock { self?._terminations += 1 }
            }
        }
    }
}

/// Thread-safe collector for streamed chunks.
final class ChunkSink: @unchecked Sendable {
    private let lock = NSLock()
    private var _chunks: [String] = []
    var chunks: [String] { lock.withLock { _chunks } }
    func append(_ chunk: String) { lock.withLock { _chunks.append(chunk) } }
}

@MainActor
final class MLXServiceTests: XCTestCase {

    private let testModel = MLXModel(name: "Mock", path: "/dev/null/mock", isDownloaded: true)

    private func makeService(
        _ generator: MockInferenceGenerator,
        kv: KVCacheSettings = .default
    ) -> MLXService {
        MLXService(generator: generator, model: testModel, contextWindow: 4096, kvCacheSettings: kv)
    }

    /// Polls until `condition` is true or the timeout elapses.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return await condition()
    }

    // MARK: - Download patterns

    func testDownloadPatternsCoverTokenizerAndTemplateFiles() {
        let patterns = MLXService.downloadPatterns
        for required in ["*.safetensors", "*.json", "*.jinja", "*.txt", "*.model"] {
            XCTAssertTrue(patterns.contains(required), "Missing download pattern \(required)")
        }

        func matches(_ file: String) -> Bool {
            patterns.contains { fnmatch($0, file, 0) == 0 }
        }
        for file in ["chat_template.jinja", "merges.txt", "tokenizer.model", "tokenizer.json",
                     "tokenizer_config.json", "config.json", "model-00001-of-00004.safetensors"] {
            XCTAssertTrue(matches(file), "\(file) would be skipped by the downloader")
        }
        // Never fetch pickle weights
        XCTAssertFalse(matches("pytorch_model.bin"))
        XCTAssertFalse(matches("model.pt"))
    }

    func testDownloadDestinationKeepsLegacyHubLayout() {
        let base = URL(fileURLWithPath: "/Volumes/Data/models")
        let dest = MLXService.downloadDestination(for: "mlx-community/Qwen3.5-9B-4bit", in: base)
        XCTAssertEqual(dest.path, "/Volumes/Data/models/models/mlx-community/Qwen3.5-9B-4bit")
    }

    // MARK: - Streaming + request mapping

    func testChatCompletionStreamsChunksAndBuildsRequest() async throws {
        let mock = MockInferenceGenerator(events: [.chunk("Hello"), .chunk(", "), .chunk("world")])
        let service = makeService(mock)
        let sink = ChunkSink()

        let result = try await service.chatCompletion(
            messages: [.system("sys"), .user("hi")],
            parameters: ModelParameters(temperature: 0.4, topK: 12),
            streamHandler: { sink.append($0) }
        )

        XCTAssertEqual(result, "Hello, world")
        XCTAssertEqual(sink.chunks, ["Hello", ", ", "world"])

        let request = try XCTUnwrap(mock.requests.first)
        XCTAssertEqual(request.prompt, .messages([
            ["role": "system", "content": "sys"],
            ["role": "user", "content": "hi"],
        ]))
        XCTAssertNotNil(request.fallbackPrompt, "Chat requests carry a flat-prompt fallback")
        XCTAssertNil(request.tools, "No tools passed -> no native tool specs")
        XCTAssertEqual(request.parameters.temperature, 0.4, accuracy: 0.0001)
        XCTAssertEqual(request.parameters.topK, 12)
        let busy = await service.isGenerating()
        XCTAssertFalse(busy)
    }

    func testGenerateUsesTextPrompt() async throws {
        let mock = MockInferenceGenerator(events: [.chunk("ok")])
        let service = makeService(mock)
        let result = try await service.generate(prompt: "summarize")
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.requests.first?.prompt, .text("summarize"))
    }

    func testKVCacheSettingsReachGenerateParameters() async throws {
        let mock = MockInferenceGenerator(events: [.chunk("x")])
        let service = makeService(mock, kv: KVCacheSettings(bits: 4, maxSize: 8192, prefillStepSize: 1024))
        _ = try await service.chatCompletion(messages: [.user("hi")])

        let params = try XCTUnwrap(mock.requests.first?.parameters)
        XCTAssertEqual(params.kvBits, 4)
        XCTAssertEqual(params.maxKVSize, 8192)
        XCTAssertEqual(params.prefill.stepSize, 1024)
    }

    func testInvalidParametersRejectedAndStateReset() async {
        let service = makeService(MockInferenceGenerator(events: [.chunk("x")]))
        do {
            _ = try await service.chatCompletion(messages: [.user("hi")], parameters: ModelParameters(temperature: 9))
            XCTFail("Expected invalidParameters")
        } catch MLXServiceError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        let busy = await service.isGenerating()
        XCTAssertFalse(busy, "Busy flag must be cleared after a failed request")
    }

    // MARK: - Stop / cancellation

    func testCancelStopsGenerationAndResetsState() async throws {
        let mock = MockInferenceGenerator(events: [.chunk("start ")], streamUntilCancelled: true)
        let service = makeService(mock)
        let sink = ChunkSink()

        let task = Task {
            try await service.chatCompletion(messages: [.user("hi")], streamHandler: { sink.append($0) })
        }

        let started = await waitUntil { sink.chunks.count >= 3 }
        XCTAssertTrue(started, "Mock should have streamed a few chunks")
        let busyWhileRunning = await service.isGenerating()
        XCTAssertTrue(busyWhileRunning)

        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled generation should throw CancellationError")
        } catch is CancellationError {
            // expected
        }

        let busyAfterCancel = await service.isGenerating()
        XCTAssertFalse(busyAfterCancel, "isInferenceRunning must reset after cancellation")
        let terminated = await waitUntil { mock.terminations >= 1 }
        XCTAssertTrue(terminated, "The underlying token stream must be terminated, not left running")

        // Chunks stop arriving after cancellation.
        let countAfterCancel = sink.chunks.count
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(sink.chunks.count, countAfterCancel)
    }

    func testNextRequestSucceedsAfterCancel() async throws {
        let endless = MockInferenceGenerator(events: [], streamUntilCancelled: true)
        let service = makeService(endless)
        let task = Task { try await service.chatCompletion(messages: [.user("one")]) }
        _ = await waitUntil { await service.isGenerating() }
        task.cancel()
        _ = try? await task.value

        // Previously the service stayed busy and threw inferenceInProgress here.
        let second = Task { try await service.chatCompletion(messages: [.user("two")]) }
        _ = await waitUntil { endless.requests.count == 2 }
        second.cancel()
        do {
            _ = try await second.value
        } catch is CancellationError {
            // expected: we cancelled the endless stream; the point is it was accepted
        } catch {
            XCTFail("Second request should be accepted after Stop, got \(error)")
        }
        XCTAssertEqual(endless.requests.count, 2)
    }

    func testConcurrentRequestIsRejectedWhileBusy() async throws {
        let endless = MockInferenceGenerator(events: [], streamUntilCancelled: true)
        let service = makeService(endless)
        let first = Task { try await service.chatCompletion(messages: [.user("one")]) }
        _ = await waitUntil { await service.isGenerating() }

        do {
            _ = try await service.chatCompletion(messages: [.user("two")])
            XCTFail("Expected inferenceInProgress")
        } catch MLXServiceError.inferenceInProgress {
            // expected
        }
        first.cancel()
        _ = try? await first.value
    }

    func testChatViewModelStopCancelsServiceAndResetsUI() async throws {
        let endless = MockInferenceGenerator(events: [.chunk("partial ")], streamUntilCancelled: true)
        let service = makeService(endless)
        let vm = ChatViewModel(conversationsDirectory: nil, inference: service)
        vm.allowLoadBalancing = false
        vm.isModelLoaded = true
        vm.currentConversation = Conversation.new(withFirstMessage: "hello")

        let run = Task { await vm.generateResponse() }
        let streaming = await waitUntil { vm.currentTokenCount >= 3 }
        XCTAssertTrue(streaming)
        XCTAssertTrue(vm.isGenerating)
        XCTAssertNotNil(vm.generationTask)

        vm.stopGeneration()
        XCTAssertFalse(vm.isGenerating)
        XCTAssertEqual(vm.statusMessage, "Generation stopped")
        await run.value

        XCTAssertNil(vm.generationTask)
        XCTAssertNil(vm.errorMessage, "Stop is not an error")
        let busy = await service.isGenerating()
        XCTAssertFalse(busy, "MLXService must be free after Stop")
        let lastAssistant = vm.currentConversation?.messages.last { $0.role == .assistant }
        XCTAssertTrue(lastAssistant?.content.hasPrefix("partial") ?? false, "Partial response is kept")

        // The agentic loop must not start another turn after Stop...
        await vm.generateResponse()
        XCTAssertEqual(endless.requests.count, 1)
        // ...but a new user request works immediately.
        vm.stopRequested = false
        let second = Task { await vm.generateResponse() }
        _ = await waitUntil { endless.requests.count == 2 }
        vm.stopGeneration()
        await second.value
        XCTAssertEqual(endless.requests.count, 2)
    }

    // MARK: - Tool calls

    func testNativeToolCallsMapToToolProtocolIncludingTwoCalls() async throws {
        let mock = MockInferenceGenerator(events: [
            .chunk("Let me look."),
            .toolCall(NativeToolCall(name: "read_file", arguments: ["path": "/tmp/a.swift"])),
            .toolCall(NativeToolCall(name: "grep", arguments: ["pattern": "TODO", "max_results": 5, "recursive": true])),
        ])
        let service = makeService(mock)
        let sink = ChunkSink()
        let response = try await service.chatCompletion(
            messages: [.user("find todos")],
            tools: [["type": "function", "function": ["name": "read_file"]]],
            streamHandler: { sink.append($0) }
        )

        XCTAssertNotNil(mock.requests.first?.tools, "Tool specs must be forwarded to the generator")
        XCTAssertTrue(response.hasPrefix("Let me look."))
        XCTAssertEqual(sink.chunks.count, 3, "Rendered tool calls are streamed to the UI too")

        let vm = ChatViewModel(conversationsDirectory: nil, inference: service)
        XCTAssertTrue(vm.containsToolCalls(response))
        let calls = vm.extractToolCalls(response)
        XCTAssertEqual(calls.count, 2, "Both native tool calls must survive mapping")

        let registry = ToolRegistry.shared
        let first = try XCTUnwrap(registry.parseToolCallJSON(calls[0]))
        XCTAssertEqual(first.name, "read_file")
        XCTAssertEqual(first.parameters["path"] as? String, "/tmp/a.swift")

        let second = try XCTUnwrap(registry.parseToolCallJSON(calls[1]))
        XCTAssertEqual(second.name, "grep")
        XCTAssertEqual(second.parameters["pattern"] as? String, "TODO")
        XCTAssertEqual(second.parameters["max_results"] as? String, "5")
        XCTAssertEqual(second.parameters["recursive"] as? String, "true")
    }

    func testTextToolProtocolFallbackStillStopsAtClosingTag() async throws {
        let mock = MockInferenceGenerator(events: [
            .chunk("<tool>\n"),
            .chunk(#"{"name": "glob", "args": {"pattern": "*.swift"}}"#),
            .chunk("\n</tool>"),
            .chunk("SHOULD NOT APPEAR"),
        ])
        let service = makeService(mock)
        let response = try await service.chatCompletion(messages: [.user("list")])
        XCTAssertFalse(response.contains("SHOULD NOT APPEAR"))

        let vm = ChatViewModel(conversationsDirectory: nil, inference: service)
        let calls = vm.extractToolCalls(response)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(ToolRegistry.shared.parseToolCallJSON(calls[0])?.name, "glob")
    }

    func testEmptyToolListIsNotForwarded() async throws {
        let mock = MockInferenceGenerator(events: [.chunk("x")])
        let service = makeService(mock)
        _ = try await service.chatCompletion(messages: [.user("hi")], tools: [])
        XCTAssertNil(mock.requests.first?.tools)
    }

    // MARK: - Optional integration test (real model, opt-in)

    func testIntegrationLoadAndStreamRealModel() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MLXCODE_INTEGRATION"] == "1" else {
            throw XCTSkip("Set MLXCODE_INTEGRATION=1 and MLXCODE_MODEL_PATH to run")
        }
        guard let path = env["MLXCODE_MODEL_PATH"] else {
            throw XCTSkip("MLXCODE_MODEL_PATH not set")
        }
        let service = MLXService.shared
        let model = MLXModel(name: "integration", path: path, isDownloaded: true)
        try await service.loadModel(model)
        let window = await service.loadedModelContextWindow
        XCTAssertNotNil(window, "Context window should be read from config.json")
        let text = try await service.chatCompletion(
            messages: [.user("Reply with the single word: ok")],
            parameters: ModelParameters(temperature: 0, maxTokens: 16)
        )
        XCTAssertFalse(text.isEmpty)
        await service.unloadModel()
    }
}
