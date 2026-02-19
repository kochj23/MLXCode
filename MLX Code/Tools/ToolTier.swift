//
//  ToolTier.swift
//  MLX Code
//
//  Tool tiering system to minimize system prompt size.
//  Only core tools are included in the prompt; others are available on-demand.
//  Created on 2026-02-19.
//

import Foundation

/// Tool tier classification for context-budget-aware tool inclusion
enum ToolTier: Int, CaseIterable, Comparable {
    /// Always included in system prompt (file ops, bash, grep, glob)
    case core = 0
    /// Included when a project is open (xcode, git, code navigation)
    case development = 1
    /// Included only when explicitly requested (image gen, video gen, TTS)
    case media = 2
    /// Never in prompt, available via "list tools" command
    case advanced = 3

    static func < (lhs: ToolTier, rhs: ToolTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Maps tool names to their tier classification
struct ToolTierClassifier {

    /// Returns the tier for a given tool name
    static func tier(for toolName: String) -> ToolTier {
        switch toolName {
        // Core: always in prompt
        case "file_operations", "bash", "grep", "glob":
            return .core
        // Development: when project is open
        case "xcode", "git_integration", "code_navigation", "test_generation", "github":
            return .development
        // Media: on-demand
        case "image_generation", "local_image_generation", "native_tts", "mlx_audio", "voice_cloning":
            return .media
        // Everything else is advanced
        default:
            return .advanced
        }
    }

    /// Returns compact tool descriptions for tools at or below the given tier
    static func compactDescriptions(maxTier: ToolTier, tools: [Tool]) -> String {
        let filtered = tools.filter { tier(for: $0.name) <= maxTier }
            .sorted { $0.name < $1.name }

        var lines: [String] = []
        for tool in filtered {
            // One-line description with required params only
            let requiredParams = tool.parameters.required.joined(separator: ", ")
            lines.append("- \(tool.name)(\(requiredParams)): \(tool.description.prefix(80))")
        }
        return lines.joined(separator: "\n")
    }
}
