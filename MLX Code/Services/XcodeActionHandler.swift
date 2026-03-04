//
//  XcodeActionHandler.swift
//  MLX Code
//
//  Handles incoming requests from the Xcode Source Editor Extension.
//  Reads the JSON request written to the shared App Group container and
//  pre-loads the appropriate context into a new chat conversation.
//
//  Created by Jordan Koch on 2026-03-04.
//

import Foundation

/// Maps a Xcode extension command to a user-facing prompt template.
@MainActor
class XcodeActionHandler: ObservableObject {
    static let shared = XcodeActionHandler()

    private let appGroupID = "group.com.jkoch.mlxcode"
    private let requestFileName = "mlxcode-xcode-request.json"

    private init() {}

    /// Called when the main app receives `mlxcode://xcode-action`.
    /// Reads the pending request from the App Group container, builds a
    /// pre-filled chat prompt, and returns it for the ChatViewModel to use.
    func handleIncomingRequest(chatViewModel: ChatViewModel) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return
        }

        let requestURL = groupURL.appendingPathComponent(requestFileName)
        guard let data = try? Data(contentsOf: requestURL),
              let request = try? JSONDecoder().decode(XcodeRequest.self, from: data) else {
            return
        }

        // Clean up the file immediately
        try? FileManager.default.removeItem(at: requestURL)

        // Build prompt from command + code context
        let prompt = buildPrompt(for: request)

        // Start a new conversation with the prompt pre-loaded
        chatViewModel.newConversation()
        chatViewModel.userInput = prompt
    }

    // MARK: - Private

    private func buildPrompt(for request: XcodeRequest) -> String {
        let language = language(from: request.contentUTI)
        let codeBlock = "```\(language)\n\(request.selectedText.trimmingCharacters(in: .whitespacesAndNewlines))\n```"

        switch request.commandIdentifier {
        case "com.local.mlxcode.xcodeeditor.explain":
            return "Explain what this code does:\n\n\(codeBlock)"

        case "com.local.mlxcode.xcodeeditor.refactor":
            return "Refactor this code for clarity and performance. Show the improved version:\n\n\(codeBlock)"

        case "com.local.mlxcode.xcodeeditor.tests":
            return "Write unit tests for this code:\n\n\(codeBlock)"

        case "com.local.mlxcode.xcodeeditor.fix":
            return "Find and fix any bugs or issues in this code:\n\n\(codeBlock)"

        case "com.local.mlxcode.xcodeeditor.ask":
            // Just load the code — user types their own question
            return codeBlock

        default:
            return codeBlock
        }
    }

    /// Maps a UTI (e.g. "public.swift-source") to a Markdown language tag.
    private func language(from uti: String) -> String {
        switch uti {
        case "public.swift-source":           return "swift"
        case "public.objective-c-source":     return "objc"
        case "public.objective-c-plus-plus-source": return "objcpp"
        case "public.c-source":               return "c"
        case "public.c-plus-plus-source":     return "cpp"
        case "com.sun.java-source":           return "java"
        case "public.python-script":          return "python"
        case "com.netscape.javascript-source": return "javascript"
        case "public.shell-script":           return "bash"
        default:                              return ""
        }
    }
}

/// Mirrors XcodeRequest in the extension target (must stay in sync).
struct XcodeRequest: Codable {
    let commandIdentifier: String
    let selectedText: String
    let fullSource: String
    let contentUTI: String
}
