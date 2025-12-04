# MLX Code - API Documentation

**Version:** 1.0.11
**Date:** November 18, 2025
**Platform:** macOS 13.0+
**Language:** Swift 5.9+

---

## Table of Contents

1. [Overview](#overview)
2. [Models](#models)
3. [Services](#services)
4. [View Models](#view-models)
5. [Utilities](#utilities)
6. [Settings](#settings)
7. [Security](#security)
8. [Error Handling](#error-handling)

---

## Overview

MLX Code is a macOS application for interacting with MLX language models. It provides a chat interface, file operations, Git integration, and Xcode project assistance.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         Views                            │
│            (SwiftUI - ChatView, SettingsView)           │
└─────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────┐
│                      View Models                         │
│             (ChatViewModel, TemplateViewModel)          │
└─────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────┐
│                       Services                           │
│   (MLXService, FileService, GitService, PythonService)  │
└─────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────┐
│                        Models                            │
│       (Message, Conversation, MLXModel, AppSettings)    │
└─────────────────────────────────────────────────────────┘
```

### Key Components

- **Models:** Data structures and business logic
- **Services:** Actor-based services for MLX, file, Git operations
- **View Models:** MVVM view models managing state and logic
- **Views:** SwiftUI views for user interface
- **Utilities:** Helper functions and security utilities

---

## Models

### Message

Represents a single chat message.

```swift
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `role` | `MessageRole` | Message sender role |
| `content` | `String` | Message text content |
| `timestamp` | `Date` | Creation timestamp |

#### Factory Methods

```swift
static func user(_ content: String) -> Message
static func assistant(_ content: String) -> Message
static func system(_ content: String) -> Message
```

**Example:**
```swift
let userMessage = Message.user("Hello, how are you?")
let assistantMessage = Message.assistant("I'm doing well, thanks!")
```

---

### MessageRole

Enum representing message sender role.

```swift
enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}
```

**Values:**
- `system`: System prompt or instruction
- `user`: User message
- `assistant`: AI assistant response

---

### Conversation

Represents a chat conversation with multiple messages.

```swift
struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var lastActivity: Date
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `title` | `String` | Conversation title |
| `messages` | `[Message]` | Array of messages |
| `createdAt` | `Date` | Creation timestamp |
| `lastActivity` | `Date` | Last activity timestamp |

#### Computed Properties

```swift
var isEmpty: Bool                    // True if no messages
var messageCount: Int                // Number of messages
var lastMessagePreview: String       // Preview of last message (truncated)
```

#### Methods

```swift
mutating func addMessage(_ message: Message)
mutating func removeMessage(withId id: UUID)
mutating func clearMessages()
func isValid() -> Bool
func toJSONData() -> Data?
static func fromJSONData(_ data: Data) -> Conversation?
```

#### Factory Methods

```swift
static func new(withFirstMessage content: String) -> Conversation
```

**Example:**
```swift
// Create new conversation
var conversation = Conversation.new(withFirstMessage: "Hello!")

// Add response
let response = Message.assistant("Hi there!")
conversation.addMessage(response)

// Export to JSON
if let jsonData = conversation.toJSONData() {
    try jsonData.write(to: fileURL)
}

// Import from JSON
if let data = try? Data(contentsOf: fileURL),
   let imported = Conversation.fromJSONData(data) {
    print("Imported: \(imported.title)")
}
```

---

### MLXModel

Represents an MLX language model configuration.

```swift
struct MLXModel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var parameters: ModelParameters
    var isDownloaded: Bool
    var sizeInBytes: Int64?
    var huggingFaceId: String?
    var description: String?
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `name` | `String` | Model display name |
| `path` | `String` | File system path |
| `parameters` | `ModelParameters` | Generation parameters |
| `isDownloaded` | `Bool` | Download status |
| `sizeInBytes` | `Int64?` | Model size in bytes |
| `huggingFaceId` | `String?` | HuggingFace model ID |
| `description` | `String?` | Model description |

#### Computed Properties

```swift
var formattedSize: String           // "5.2 GB" or "Unknown size"
var fileName: String                // Last path component
var directoryPath: String           // Directory path
```

#### Methods

```swift
func isValid() -> Bool
func toJSONData() -> Data?
static func fromJSONData(_ data: Data) -> MLXModel?
```

#### Factory Methods

```swift
static func `default`() -> MLXModel
static func commonModels() -> [MLXModel]
```

**Common Models:**
1. Llama 3.2 3B
2. Qwen 2.5 7B
3. Mistral 7B
4. Phi-3.5 Mini

**Example:**
```swift
// Create custom model
let model = MLXModel(
    name: "Custom Model",
    path: "/path/to/model",
    parameters: ModelParameters(temperature: 0.8),
    isDownloaded: true,
    sizeInBytes: 5_000_000_000
)

// Use common models
let models = MLXModel.commonModels()
print("Available: \(models.map { $0.name })")
```

---

### ModelParameters

Model generation parameters.

```swift
struct ModelParameters: Codable {
    var temperature: Double = 0.7
    var maxTokens: Int = 2048
    var topP: Double = 0.9
    var topK: Int = 40
    var repetitionPenalty: Double = 1.1
    var repetitionContextSize: Int = 20
}
```

#### Parameter Ranges

| Parameter | Default | Min | Max | Description |
|-----------|---------|-----|-----|-------------|
| `temperature` | 0.7 | 0.0 | 2.0 | Sampling temperature |
| `maxTokens` | 2048 | 1 | 100,000 | Maximum tokens to generate |
| `topP` | 0.9 | 0.0 | 1.0 | Nucleus sampling threshold |
| `topK` | 40 | 1 | 1000 | Top-K sampling parameter |
| `repetitionPenalty` | 1.1 | 0.1 | 2.0 | Repetition penalty |
| `repetitionContextSize` | 20 | 1 | 1000 | Context size for repetition |

#### Methods

```swift
func isValid() -> Bool              // Validates all parameters in range
```

**Example:**
```swift
let params = ModelParameters(
    temperature: 0.8,
    maxTokens: 4096,
    topP: 0.95
)

if params.isValid() {
    // Use parameters for generation
}
```

---

## Services

### MLXService

Actor-based service for MLX model operations.

```swift
actor MLXService {
    static let shared = MLXService()
}
```

#### Model Management

```swift
func loadModel(_ model: MLXModel) async throws
func unloadModel() async
func getCurrentModel() -> MLXModel?
func isLoaded() -> Bool
```

**Example:**
```swift
let model = MLXModel.commonModels()[0]

// Load model
try await MLXService.shared.loadModel(model)

// Check if loaded
let isLoaded = await MLXService.shared.isLoaded()
print("Model loaded: \(isLoaded)")

// Unload model
await MLXService.shared.unloadModel()
```

#### Text Generation

```swift
func generate(
    prompt: String,
    parameters: ModelParameters? = nil,
    streamHandler: ((String) -> Void)? = nil
) async throws -> String
```

**Example:**
```swift
// Simple generation
let response = try await MLXService.shared.generate(
    prompt: "What is Swift?"
)
print(response)

// With streaming
let response = try await MLXService.shared.generate(
    prompt: "Explain concurrency",
    streamHandler: { token in
        print(token, terminator: "")
    }
)
```

#### Chat Completion

```swift
func chatCompletion(
    messages: [Message],
    parameters: ModelParameters? = nil,
    streamHandler: ((String) -> Void)? = nil
) async throws -> String
```

**Example:**
```swift
let messages = [
    Message.system("You are a helpful assistant"),
    Message.user("What is MLX?")
]

let response = try await MLXService.shared.chatCompletion(
    messages: messages,
    parameters: ModelParameters(temperature: 0.7)
)
```

#### Model Discovery

```swift
func discoverModels() async throws -> [MLXModel]
```

**Example:**
```swift
let discoveredModels = try await MLXService.shared.discoverModels()
print("Found \(discoveredModels.count) models")
```

#### Model Download

```swift
func downloadModel(
    _ model: MLXModel,
    progressHandler: ((Double) -> Void)? = nil
) async throws -> MLXModel
```

**Example:**
```swift
let model = MLXModel.commonModels()[0]

let downloadedModel = try await MLXService.shared.downloadModel(model) { progress in
    print("Download progress: \(Int(progress * 100))%")
}

print("Model downloaded to: \(downloadedModel.path)")
```

#### Errors

```swift
enum MLXServiceError: LocalizedError {
    case invalidModel
    case modelNotDownloaded
    case modelNotFound(String)
    case noModelLoaded
    case inferenceInProgress
    case invalidParameters
    case generationFailed(String)
}
```

---

### FileService

Actor-based service for file operations.

```swift
actor FileService {
    static let shared = FileService()
}
```

#### Read Operations

```swift
func read(path: String, encoding: String.Encoding = .utf8) async throws -> String
func readData(path: String) async throws -> Data
```

**Example:**
```swift
// Read text file
let content = try await FileService.shared.read(path: "~/Documents/file.txt")
print(content)

// Read binary data
let data = try await FileService.shared.readData(path: "~/image.png")
```

#### Write Operations

```swift
func write(
    content: String,
    to path: String,
    encoding: String.Encoding = .utf8,
    createDirectories: Bool = true
) async throws

func writeData(
    _ data: Data,
    to path: String,
    createDirectories: Bool = true
) async throws
```

**Example:**
```swift
// Write text
try await FileService.shared.write(
    content: "Hello, world!",
    to: "~/output.txt"
)

// Write data
try await FileService.shared.writeData(
    imageData,
    to: "~/output.png"
)
```

#### Edit Operations

```swift
func edit(
    path: String,
    oldString: String,
    newString: String,
    replaceAll: Bool = false
) async throws
```

**Example:**
```swift
// Replace first occurrence
try await FileService.shared.edit(
    path: "~/file.txt",
    oldString: "foo",
    newString: "bar"
)

// Replace all occurrences
try await FileService.shared.edit(
    path: "~/file.txt",
    oldString: "old",
    newString: "new",
    replaceAll: true
)
```

#### Glob Operations

```swift
func glob(pattern: String, in directory: String = ".") async throws -> [String]
```

**Example:**
```swift
// Find all Swift files
let swiftFiles = try await FileService.shared.glob(
    pattern: "**/*.swift",
    in: "~/Projects"
)
print("Found \(swiftFiles.count) Swift files")

// Find specific pattern
let testFiles = try await FileService.shared.glob(
    pattern: "*Tests.swift",
    in: "~/Project/Tests"
)
```

#### Grep Operations

```swift
func grep(
    pattern: String,
    in paths: [String],
    caseSensitive: Bool = true,
    contextLines: Int = 0
) async throws -> [GrepResult]
```

**Example:**
```swift
let files = ["file1.swift", "file2.swift"]
let results = try await FileService.shared.grep(
    pattern: "func.*Error",
    in: files,
    caseSensitive: false,
    contextLines: 2
)

for result in results {
    print("\(result.path):\(result.lineNumber): \(result.line)")
}
```

#### File System Operations

```swift
func createDirectory(at path: String, createIntermediates: Bool = true) async throws
func delete(at path: String) async throws
func exists(at path: String) -> Bool
```

**Example:**
```swift
// Create directory
try await FileService.shared.createDirectory(
    at: "~/Projects/NewProject"
)

// Check if exists
let exists = FileService.shared.exists(at: "~/file.txt")

// Delete
try await FileService.shared.delete(at: "~/old_file.txt")
```

#### Errors

```swift
enum FileServiceError: LocalizedError {
    case invalidPath(String)
    case fileNotFound(String)
    case directoryNotFound(String)
    case isDirectory(String)
    case readFailed(Error)
    case writeFailed(Error)
    case createDirectoryFailed(Error)
    case deleteFailed(Error)
    case stringNotFound(String)
}
```

---

### GitService

Actor-based service for Git operations.

```swift
actor GitService {
    static let shared = GitService()
}
```

#### Status Operations

```swift
func getStatus(in repositoryPath: String) async throws -> GitStatus
func getStagedChanges(in repositoryPath: String) async throws -> String
func getUnstagedChanges(in repositoryPath: String) async throws -> String
```

**Example:**
```swift
let repoPath = "~/Projects/MyApp"

// Get status
let status = try await GitService.shared.getStatus(in: repoPath)
print("Branch: \(status.branch)")
print("Modified: \(status.modifiedFiles)")

// Get diffs
let staged = try await GitService.shared.getStagedChanges(in: repoPath)
let unstaged = try await GitService.shared.getUnstagedChanges(in: repoPath)
```

#### Log Operations

```swift
func getLog(in repositoryPath: String, count: Int = 10) async throws -> [GitCommit]
func getCurrentBranch(in repositoryPath: String) async throws -> String
```

**Example:**
```swift
// Get recent commits
let commits = try await GitService.shared.getLog(
    in: repoPath,
    count: 5
)

for commit in commits {
    print("\(commit.shortHash): \(commit.subject)")
}

// Get current branch
let branch = try await GitService.shared.getCurrentBranch(in: repoPath)
print("On branch: \(branch)")
```

#### Commit Operations

```swift
func commit(message: String, in repositoryPath: String) async throws
func stageFiles(_ files: [String], in repositoryPath: String) async throws
```

**Example:**
```swift
// Stage files
try await GitService.shared.stageFiles(
    ["README.md", "Sources/Main.swift"],
    in: repoPath
)

// Create commit
try await GitService.shared.commit(
    message: "feat: Add new feature",
    in: repoPath
)
```

#### Branch Operations

```swift
func createBranch(
    name: String,
    in repositoryPath: String,
    checkout: Bool = true
) async throws
```

**Example:**
```swift
// Create and checkout
try await GitService.shared.createBranch(
    name: "feature/new-ui",
    in: repoPath,
    checkout: true
)

// Create without checkout
try await GitService.shared.createBranch(
    name: "fix/bug-123",
    in: repoPath,
    checkout: false
)
```

#### AI Commit Message

```swift
func generateCommitMessage(in repositoryPath: String) async throws -> String
```

**Example:**
```swift
let message = try await GitService.shared.generateCommitMessage(in: repoPath)
print("Generated message: \(message)")

// Use for commit
try await GitService.shared.commit(message: message, in: repoPath)
```

#### Data Structures

```swift
struct GitStatus: Codable {
    var branch: String
    var modifiedFiles: [String]
    var addedFiles: [String]
    var deletedFiles: [String]
    var untrackedFiles: [String]
    var hasChanges: Bool
    var hasUntrackedFiles: Bool
}

struct GitCommit: Codable, Identifiable {
    let hash: String
    let author: String
    let authorEmail: String
    let date: Date
    let subject: String
    var id: String { hash }
    var shortHash: String
}
```

#### Errors

```swift
enum GitError: LocalizedError {
    case invalidPath(String)
    case notARepository
    case invalidInput(String)
    case commandFailed(String)
    case executionFailed(String)
    case timeout
    case outputTooLarge
    case noStagedChanges
}
```

---

## View Models

### ChatViewModel

Main view model for chat interface.

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var currentConversation: Conversation?
    @Published var conversations: [Conversation] = []
    @Published var userInput: String = ""
    @Published var isGenerating: Bool = false
    @Published var isModelLoaded: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var errorMessage: String?
    @Published var progress: Double = 0.0
}
```

#### Methods

```swift
func sendMessage() async
func newConversation()
func loadConversation(_ conversation: Conversation)
func deleteConversation(_ conversation: Conversation)
func loadModel(_ model: MLXModel) async
func unloadModel() async
func stopGeneration()
func exportConversation(_ conversation: Conversation) -> Data?
func importConversation(from data: Data)
```

**Example:**
```swift
@StateObject private var viewModel = ChatViewModel()

// Send message
Task {
    viewModel.userInput = "Hello!"
    await viewModel.sendMessage()
}

// Load model
Task {
    let model = MLXModel.commonModels()[0]
    await viewModel.loadModel(model)
}

// Export conversation
if let data = viewModel.exportConversation(conversation) {
    try data.write(to: fileURL)
}
```

---

## Utilities

### SecurityUtils

Security validation and sanitization utilities.

#### File Path Validation

```swift
static func validateFilePath(_ path: String) -> Bool
static func sanitizeFilePath(_ path: String) -> String
```

**Example:**
```swift
let path = userInput
if SecurityUtils.validateFilePath(path) {
    let sanitized = SecurityUtils.sanitizeFilePath(path)
    // Use sanitized path
}
```

#### Command Validation

```swift
static func validateCommand(_ command: String) -> Bool
static func sanitizeShellArgument(_ string: String) -> String
```

**Example:**
```swift
if SecurityUtils.validateCommand(command) {
    let safe = SecurityUtils.sanitizeShellArgument(argument)
    // Execute command
}
```

#### Input Validation

```swift
static func validateEmail(_ email: String) -> Bool
static func validateURL(_ urlString: String) -> Bool
static func validatePort(_ port: Int) -> Bool
static func validateLength(_ string: String, min: Int = 0, max: Int) -> Bool
```

#### Input Sanitization

```swift
static func sanitizeSQL(_ string: String) -> String
static func sanitizeHTML(_ string: String) -> String
static func sanitizeUserInput(_ string: String) -> String
```

#### String Validation

```swift
static func isAlphanumeric(_ string: String) -> Bool
static func isAlphanumericWithSymbols(_ string: String, allowedSymbols: Set<Character>) -> Bool
static func validatePasswordStrength(_ password: String, minLength: Int = 8) -> Bool
```

#### Secure Random

```swift
static func generateSecureRandomString(length: Int) -> String?
static func generateSecureToken(byteCount: Int = 32) -> String?
```

#### Rate Limiting

```swift
actor RateLimiter {
    init(maxRequests: Int, timeWindow: TimeInterval)
    func shouldAllowRequest(for identifier: String) -> Bool
    func clearRateLimit(for identifier: String)
}
```

**Example:**
```swift
let rateLimiter = SecurityUtils.RateLimiter(maxRequests: 10, timeWindow: 60.0)

if await rateLimiter.shouldAllowRequest(for: userID) {
    // Process request
} else {
    // Rate limit exceeded
}
```

---

## Settings

### AppSettings

Singleton class managing application settings.

```swift
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Published properties
    @Published var selectedModel: MLXModel?
    @Published var availableModels: [MLXModel] = []
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Int = 2048
    // ... more properties
}
```

#### Properties

| Category | Properties |
|----------|-----------|
| **Model Settings** | `selectedModel`, `availableModels` |
| **Generation** | `temperature`, `maxTokens`, `topP`, `topK` |
| **Paths** | `pythonPath`, `xcodeProjectsPath`, `workspacePath`, `modelsPath`, `templatesPath`, `conversationsExportPath` |
| **UI** | `theme`, `fontSize`, `enableSyntaxHighlighting` |
| **Auto-Save** | `enableAutoSave`, `autoSaveInterval`, `maxConversationHistory` |

#### Methods

```swift
func loadSettings()
func saveSettings()
func resetToDefaults()
func validatePythonPath() -> Bool
func validateDirectoryPath(_ path: String) -> Bool
func openInFinder(_ path: String)
```

**Example:**
```swift
let settings = AppSettings.shared

// Modify settings
settings.temperature = 0.8
settings.maxTokens = 4096

// Save (auto-saves with debounce)
// or manually:
settings.saveSettings()

// Reset to defaults
settings.resetToDefaults()

// Validate paths
if settings.validatePythonPath() {
    print("Python path is valid")
}
```

---

## Security

### Security Best Practices

#### Input Validation

**Always validate user input:**
```swift
// Validate and sanitize
let input = SecurityUtils.sanitizeUserInput(userInput)
guard SecurityUtils.validateLength(input, max: 10000) else {
    throw ValidationError.inputTooLong
}
```

#### File Path Security

**Prevent directory traversal:**
```swift
guard SecurityUtils.validateFilePath(path) else {
    throw SecurityError.invalidPath
}

let sanitized = SecurityUtils.sanitizeFilePath(path)
let expanded = (sanitized as NSString).expandingTildeInPath
```

#### Command Injection Prevention

**Validate commands:**
```swift
guard SecurityUtils.validateCommand(command) else {
    throw SecurityError.dangerousCommand
}
```

#### SQL Injection Prevention

**Use parameterized queries or sanitize:**
```swift
let safe = SecurityUtils.sanitizeSQL(userInput)
// Better: Use parameterized queries
```

#### XSS Prevention

**Escape HTML:**
```swift
let safe = SecurityUtils.sanitizeHTML(userInput)
```

---

## Error Handling

### Error Types

All services define custom error types conforming to `LocalizedError`:

```swift
// MLXService
enum MLXServiceError: LocalizedError {
    case invalidModel
    case modelNotDownloaded
    case modelNotFound(String)
    // ...
}

// FileService
enum FileServiceError: LocalizedError {
    case invalidPath(String)
    case fileNotFound(String)
    // ...
}

// GitService
enum GitError: LocalizedError {
    case notARepository
    case commandFailed(String)
    // ...
}
```

### Error Handling Patterns

**Using do-catch:**
```swift
do {
    let result = try await service.performOperation()
    // Handle success
} catch let error as MLXServiceError {
    // Handle specific error
    print("MLX Error: \(error.localizedDescription)")
} catch {
    // Handle generic error
    print("Error: \(error)")
}
```

**Using Result:**
```swift
func loadModel() -> Result<MLXModel, MLXServiceError> {
    // Implementation
}

switch loadModel() {
case .success(let model):
    print("Loaded: \(model.name)")
case .failure(let error):
    print("Failed: \(error)")
}
```

---

## Thread Safety

### Actor-Based Services

All services use Swift's actor model for thread safety:

```swift
actor MLXService { }
actor FileService { }
actor GitService { }
```

**Usage:**
```swift
// Automatically isolated
let result = await MLXService.shared.generate(prompt: "Hello")

// Multiple calls are serialized
Task {
    await service.operation1()
    await service.operation2()
}
```

### MainActor Usage

View models and settings use `@MainActor`:

```swift
@MainActor
class ChatViewModel: ObservableObject { }

@MainActor
class AppSettings: ObservableObject { }
```

---

## Examples

### Complete Chat Example

```swift
import SwiftUI

struct ChatExampleView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            // Messages
            ScrollView {
                ForEach(viewModel.currentConversation?.messages ?? []) { message in
                    MessageRow(message: message)
                }
            }

            // Input
            HStack {
                TextField("Type a message", text: $viewModel.userInput)
                Button("Send") {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
                .disabled(!viewModel.isModelLoaded || viewModel.userInput.isEmpty)
            }
        }
        .onAppear {
            Task {
                let model = MLXModel.commonModels()[0]
                await viewModel.loadModel(model)
            }
        }
    }
}
```

### Complete File Operations Example

```swift
Task {
    // Read file
    let content = try await FileService.shared.read(path: "~/input.txt")

    // Find Swift files
    let swiftFiles = try await FileService.shared.glob(
        pattern: "**/*.swift",
        in: "~/Project"
    )

    // Search for pattern
    let results = try await FileService.shared.grep(
        pattern: "TODO:",
        in: swiftFiles
    )

    // Process results
    for result in results {
        print("\(result.path):\(result.lineNumber): \(result.line)")
    }
}
```

### Complete Git Example

```swift
Task {
    let repoPath = "~/Projects/MyApp"

    // Get status
    let status = try await GitService.shared.getStatus(in: repoPath)

    if status.hasChanges {
        // Stage modified files
        try await GitService.shared.stageFiles(
            status.modifiedFiles,
            in: repoPath
        )

        // Generate commit message
        let message = try await GitService.shared.generateCommitMessage(
            in: repoPath
        )

        // Create commit
        try await GitService.shared.commit(
            message: message,
            in: repoPath
        )

        print("Committed: \(message)")
    }
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.11 | 2025-11-18 | Initial API documentation |

---

**Document Status:** ✅ Complete
**Last Updated:** November 18, 2025
**Review Date:** TBD
