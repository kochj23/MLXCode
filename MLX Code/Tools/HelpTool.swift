//
//  HelpTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for providing interactive help and tutorials - Self-contained version
class HelpTool: BaseTool {
    init() {
        super.init(
            name: "help",
            description: "Get help, tutorials, and examples for any tool or feature",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Help operation",
                        enum: ["list_tools", "show_guide"]
                    ),
                    "tool_name": ParameterProperty(
                        type: "string",
                        description: "Name of tool to get help for"
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        switch operation {
        case "list_tools":
            return try await listTools()
        case "show_guide":
            return try await showGuide(parameters: parameters)
        default:
            throw ToolError.missingParameter("Invalid operation")
        }
    }

    private func listTools() async throws -> ToolResult {
        var result = "# MLX Code - Complete Tool Reference (31 Tools)\n\n"
        result += "## Core Tools (5)\n"
        result += "1. **file_operations** - Read, write, edit files\n"
        result += "2. **bash** - Execute shell commands\n"
        result += "3. **grep** - Search code with regex\n"
        result += "4. **glob** - Find files by pattern\n"
        result += "5. **xcode** - Build and manage Xcode projects\n\n"

        result += "## Advanced Development (10)\n"
        result += "6. **error_diagnosis** - Diagnose and fix build errors\n"
        result += "7. **test_generation** - Generate and run tests\n"
        result += "8. **code_navigation** - Navigate code and find symbols\n"
        result += "9. **git** - Git operations with AI commits\n"
        result += "10. **refactor** - Refactor code safely\n"
        result += "11. **documentation** - Generate documentation\n"
        result += "12. **dependencies** - Manage dependencies\n"
        result += "13. **simulator** - Manage simulators\n"
        result += "14. **assets** - Manage assets\n"
        result += "15. **scheme** - Manage build schemes\n\n"

        result += "## Claude Code Features (15)\n"
        result += "16. **mcp** - Connect to MCP servers\n"
        result += "17. **diff_preview** - Preview file changes\n"
        result += "18. **context_memory** - Store and retrieve context\n"
        result += "19. **debugger** - Interactive debugging\n"
        result += "20. **code_review** - Automated code review\n"
        result += "21. **code_completion** - Context-aware completions\n"
        result += "22. **template_generator** - Generate project templates\n"
        result += "23. **task_planning** - Plan and track tasks\n"
        result += "24. **workspace_analysis** - Analyze project structure\n"
        result += "25. **collaboration** - Real-time collaboration\n"
        result += "26. **profiling** - Performance profiling\n"
        result += "27. **regression_testing** - Automated regression tests\n"
        result += "28. **security_scanner** - Find vulnerabilities\n"
        result += "29. **cicd** - Manage CI/CD pipelines\n"
        result += "30. **nl2code** - Generate code from descriptions\n\n"

        result += "## Meta Tool (1)\n"
        result += "31. **help** - This tool! Get help for any feature\n\n"

        result += "## Usage\n"
        result += "To get detailed help for any tool:\n"
        result += "\"Show me the guide for [tool_name]\"\n"

        return .success(result)
    }

    private func showGuide(parameters: [String: Any]) async throws -> ToolResult {
        guard let toolName = parameters["tool_name"] as? String else {
            throw ToolError.missingParameter("tool_name")
        }

        let guide = getGuide(for: toolName)
        return .success(guide)
    }

    private func getGuide(for tool: String) -> String {
        switch tool {
        case "mcp":
            return """
            # MCP Server Integration Guide

            ## What is MCP?
            Model Context Protocol allows connecting to external data sources and tools.

            ## Operations
            1. **discover** - Find local MCP servers
            2. **connect** - Connect to a server
            3. **list_tools** - See available tools
            4. **call_tool** - Execute a tool

            ## Example Workflow
            ```
            1. "Use MCP to discover servers"
            2. "Connect to MCP server at http://localhost:3000"
            3. "List tools on that MCP server"
            4. "Use that server to get weather for San Francisco"
            ```

            ## Use Cases
            - Weather data APIs
            - Stock market info
            - Database queries
            - Custom integrations
            """

        case "security_scanner":
            return """
            # Security Scanner Guide

            ## Operations
            1. **find_secrets** - Find hardcoded passwords, API keys, tokens
            2. **scan_dependencies** - Check for CVE vulnerabilities
            3. **detect_vulnerabilities** - Find common security issues

            ## Example
            ```
            "Scan my code for hardcoded secrets"
            ```

            ## What It Finds
            - Hardcoded passwords
            - API keys in code
            - Authentication tokens
            - Database credentials

            ## Best Practices
            - Run before every commit
            - Use Keychain for secrets
            - Rotate exposed credentials immediately
            - Add scanning to CI/CD
            """

        case "diff_preview":
            return """
            # Diff Preview Guide

            ## Workflow
            1. Make code changes
            2. Create a diff
            3. Preview changes
            4. Apply or reject

            ## Example
            ```
            "Create a diff for MyFile.swift with these changes..."
            "Show me the diff preview"
            "Apply the diff"
            ```

            ## Benefits
            - See exact changes before applying
            - Review additions/deletions
            - Batch multiple files
            - Safe refactoring
            """

        default:
            return """
            # \(tool) Guide

            Detailed guide coming soon!

            For now, the AI knows how to use this tool.
            Simply ask: "Use \(tool) to [describe what you want]"

            Or ask: "List all tools" to see all 31 available tools.
            """
        }
    }
}
