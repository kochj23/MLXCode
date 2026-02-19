//
//  ToolTier.swift
//  MLX Code
//
//  Tool tiering system to minimize system prompt size.
//  Core tools always in prompt; development tools when project is open.
//  Created on 2026-02-19. Updated 2026-02-19.
//

import Foundation

/// Tool tier classification for context-budget-aware tool inclusion
enum ToolTier: Int, CaseIterable, Comparable {
    /// Always included in system prompt (file ops, bash, grep, glob, edit)
    case core = 0
    /// Included when a project is open (xcode, git, error diagnosis, test gen, code nav, diff)
    case development = 1

    static func < (lhs: ToolTier, rhs: ToolTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Maps tool names to their tier classification
struct ToolTierClassifier {

    /// Returns the tier for a given tool name
    static func tier(for toolName: String) -> ToolTier {
        switch toolName {
        case "file_operations", "bash", "grep", "glob", "edit":
            return .core
        case "xcode", "git_integration", "code_navigation", "test_generation",
             "error_diagnosis", "diff_preview", "help":
            return .development
        default:
            return .development
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
