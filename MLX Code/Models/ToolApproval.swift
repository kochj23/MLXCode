//
//  ToolApproval.swift
//  MLX Code
//
//  Tool approval types and policy for the agentic loop.
//  Created on 2026-02-19.
//

import Foundation

/// Represents a pending tool call awaiting user approval
struct PendingToolCall: Identifiable {
    let id = UUID()
    let toolName: String
    let parameters: [String: Any]
    let rawJSON: String
    var approved: Bool = false

    /// Human-readable summary of the tool call
    var summary: String {
        if let path = parameters["path"] as? String {
            return "\(toolName) → \(path)"
        } else if let command = parameters["command"] as? String {
            return "\(toolName) → \(command.prefix(60))"
        } else if let pattern = parameters["pattern"] as? String {
            return "\(toolName) → \(pattern)"
        }
        return toolName
    }
}

/// Tool approval policy
enum ToolApprovalPolicy: String, CaseIterable, Identifiable {
    /// Always ask before executing any tool
    case alwaysAsk = "always_ask"
    /// Auto-approve read-only tools (file read, grep, glob, code navigation)
    case autoApproveRead = "auto_approve_read"
    /// Auto-approve all tools without asking
    case autoApproveAll = "auto_approve_all"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alwaysAsk: return "Always Ask"
        case .autoApproveRead: return "Auto-approve Read-only"
        case .autoApproveAll: return "Auto-approve All"
        }
    }

    var description: String {
        switch self {
        case .alwaysAsk:
            return "Ask before executing any tool"
        case .autoApproveRead:
            return "Auto-approve file reads, grep, glob. Ask for writes and commands."
        case .autoApproveAll:
            return "Execute all tools without asking"
        }
    }

    /// Set of tool names considered read-only
    static let readOnlyTools: Set<String> = [
        "file_operations",  // Only when operation=read
        "grep",
        "glob",
        "code_navigation",
        "workspace_analysis"
    ]

    /// Check if a tool call should be auto-approved under this policy
    func shouldAutoApprove(toolName: String, parameters: [String: Any]) -> Bool {
        switch self {
        case .alwaysAsk:
            return false
        case .autoApproveAll:
            return true
        case .autoApproveRead:
            // Special case: file_operations is only read-only for "read" operation
            if toolName == "file_operations" {
                let operation = parameters["operation"] as? String ?? ""
                return operation == "read" || operation == "list"
            }
            return Self.readOnlyTools.contains(toolName)
        }
    }
}
