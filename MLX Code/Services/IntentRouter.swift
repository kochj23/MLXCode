//
//  IntentRouter.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//  Inspired by TinyLLM project by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation

/// Automatically classifies user intent and routes to appropriate tools
/// Uses lightweight classification to determine which tools should be invoked
/// Based on intent routing architecture from TinyLLM by Jason Cox
actor IntentRouter {
    static let shared = IntentRouter()

    private init() {}

    /// Analyzes user prompt and suggests appropriate tools
    /// - Parameters:
    ///   - prompt: User's input text
    ///   - availableTools: List of available tools
    ///   - context: Execution context
    /// - Returns: Array of suggested tool names with confidence scores
    func routeIntent(prompt: String, availableTools: [String], context: ToolContext) async -> [IntentSuggestion] {
        var suggestions: [IntentSuggestion] = []

        let lowerPrompt = prompt.lowercased()

        // Web Fetch patterns
        if detectWebFetchIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "web_fetch",
                confidence: 0.9,
                reason: "Detected URL or documentation request"
            ))
        }

        // News patterns
        if detectNewsIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "news",
                confidence: 0.95,
                reason: "Detected request for current news or updates"
            ))
        }

        // Image generation patterns
        if detectImageGenerationIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "generate_image",
                confidence: 0.9,
                reason: "Detected request to create or generate image"
            ))
        }

        // File operations
        if detectFileOperationIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "file_operations",
                confidence: 0.85,
                reason: "Detected file manipulation request"
            ))
        }

        // Git operations
        if detectGitIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "git",
                confidence: 0.9,
                reason: "Detected Git command or version control request"
            ))
        }

        // Bash/shell commands
        if detectBashIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "bash",
                confidence: 0.85,
                reason: "Detected shell command or terminal operation"
            ))
        }

        // Grep/search
        if detectSearchIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "grep",
                confidence: 0.9,
                reason: "Detected code search request"
            ))
        }

        // Xcode build/test
        if detectXcodeIntent(lowerPrompt) {
            suggestions.append(IntentSuggestion(
                toolName: "xcode",
                confidence: 0.95,
                reason: "Detected Xcode build/test request"
            ))
        }

        // Sort by confidence
        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Intent Detection

    private func detectWebFetchIntent(_ prompt: String) -> Bool {
        let patterns = [
            "http://", "https://", "www.",
            "fetch", "download", "get content from",
            "summarize this url", "what does this page say",
            "check this link", "read this article"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectNewsIntent(_ prompt: String) -> Bool {
        let patterns = [
            "latest news", "current news", "recent news",
            "what's new in", "updates on", "headlines",
            "swift news", "ios news", "tech news",
            "what's happening with", "recent developments"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectImageGenerationIntent(_ prompt: String) -> Bool {
        let patterns = [
            "generate image", "create image", "make an image",
            "draw", "design", "icon", "mockup", "diagram",
            "visualize", "illustrate", "picture of",
            "app icon", "ui design", "screenshot"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectFileOperationIntent(_ prompt: String) -> Bool {
        let patterns = [
            "read file", "write file", "create file",
            "delete file", "copy file", "move file",
            "edit file", "modify file", "rename file",
            "file contents", "show me the file"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectGitIntent(_ prompt: String) -> Bool {
        let patterns = [
            "git commit", "git push", "git pull", "git status",
            "git diff", "git log", "git branch", "git checkout",
            "commit this", "push changes", "check git",
            "version control", "commit message"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectBashIntent(_ prompt: String) -> Bool {
        let patterns = [
            "run command", "execute", "terminal",
            "bash", "shell", "zsh", "command line",
            "brew install", "npm install", "pip install",
            "ls ", "cd ", "mkdir", "rm ", "cp ", "mv "
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectSearchIntent(_ prompt: String) -> Bool {
        let patterns = [
            "search for", "find", "grep", "look for",
            "where is", "locate", "search code",
            "find all instances", "find occurrences"
        ]
        return patterns.contains { prompt.contains($0) }
    }

    private func detectXcodeIntent(_ prompt: String) -> Bool {
        let patterns = [
            "build", "compile", "run tests", "test",
            "xcodebuild", "run project", "build project",
            "run unit tests", "analyze", "archive"
        ]
        return patterns.contains { prompt.contains($0) }
    }
}

/// Intent classification result
struct IntentSuggestion {
    let toolName: String
    let confidence: Double  // 0.0 to 1.0
    let reason: String

    var shouldAutoExecute: Bool {
        // Only auto-execute if very confident
        return confidence >= 0.9
    }
}
