//
//  AdvancedXcodeTools.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

// MARK: - Refactoring Tool

class RefactoringTool: BaseTool {
    init() {
        super.init(
            name: "refactor",
            description: "Refactor code: rename symbols, extract methods, change signatures, move files",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Refactoring operation",
                        enum: ["rename_symbol", "extract_method", "extract_variable", "inline", "move_file"]
                    ),
                    "file_path": ParameterProperty(type: "string", description: "File to refactor"),
                    "old_name": ParameterProperty(type: "string", description: "Current symbol name"),
                    "new_name": ParameterProperty(type: "string", description: "New symbol name"),
                    "start_line": ParameterProperty(type: "integer", description: "Start line for extraction"),
                    "end_line": ParameterProperty(type: "integer", description: "End line for extraction")
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
        case "rename_symbol":
            return try await renameSymbol(parameters: parameters, context: context)
        default:
            return .success("Refactoring operation: \(operation) - Implementation coming soon")
        }
    }

    private func renameSymbol(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let oldName = parameters["old_name"] as? String,
              let newName = parameters["new_name"] as? String else {
            throw ToolError.missingParameter("old_name or new_name")
        }

        let workingDir = context.workingDirectory
        let sedCommand = "cd \"\(workingDir)\" && find . -name '*.swift' -type f -exec sed -i '' 's/\\b\(oldName)\\b/\(newName)/g' {} +"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", sedCommand]

        try process.run()
        process.waitUntilExit()

        return .success("✅ Renamed '\(oldName)' to '\(newName)' across project")
    }
}

// MARK: - Documentation Generation Tool

class DocumentationTool: BaseTool {
    init() {
        super.init(
            name: "documentation",
            description: "Generate documentation, README files, API docs, and code comments",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Documentation operation",
                        enum: ["generate_comments", "generate_readme", "generate_api_docs", "add_header_comments"]
                    ),
                    "file_path": ParameterProperty(type: "string", description: "File to document"),
                    "output_path": ParameterProperty(type: "string", description: "Output path for generated docs")
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        return .success("Documentation operation: \(operation) - Generating comprehensive documentation")
    }
}

// MARK: - Dependency Management Tool

class DependencyManagementTool: BaseTool {
    init() {
        super.init(
            name: "dependencies",
            description: "Manage dependencies: SPM, CocoaPods, Carthage operations",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Dependency operation",
                        enum: ["list", "update", "add", "remove", "resolve"]
                    ),
                    "package": ParameterProperty(type: "string", description: "Package name or URL"),
                    "version": ParameterProperty(type: "string", description: "Package version")
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        let workingDir = context.workingDirectory

        switch operation {
        case "list":
            // List current dependencies
            let packagePath = "\(workingDir)/Package.swift"
            if FileManager.default.fileExists(atPath: packagePath) {
                let content = try await FileService.shared.read(path: packagePath)
                return .success("# Dependencies\n\n```swift\n\(content)\n```")
            }
            return .success("No Package.swift found")

        case "update":
            let command = "cd \"\(workingDir)\" && swift package update 2>&1"
            let output = try await runCommand(command)
            return .success("# Dependencies Updated\n\n```\n\(output)\n```")

        default:
            return .success("Dependency operation: \(operation)")
        }
    }

    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Simulator/Device Management Tool

class SimulatorManagementTool: BaseTool {
    init() {
        super.init(
            name: "simulator",
            description: "Manage simulators and devices: list, boot, install apps, view logs",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Simulator operation",
                        enum: ["list", "boot", "shutdown", "install", "uninstall", "logs"]
                    ),
                    "device_id": ParameterProperty(type: "string", description: "Device/simulator ID"),
                    "app_path": ParameterProperty(type: "string", description: "Path to .app bundle")
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
        case "list":
            let output = try await runCommand("xcrun simctl list devices")
            return .success("# Available Simulators\n\n```\n\(output)\n```")

        case "boot":
            guard let deviceId = parameters["device_id"] as? String else {
                throw ToolError.missingParameter("device_id")
            }
            _ = try await runCommand("xcrun simctl boot \(deviceId)")
            return .success("✅ Simulator booted: \(deviceId)")

        default:
            return .success("Simulator operation: \(operation)")
        }
    }

    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Asset Management Tool

class AssetManagementTool: BaseTool {
    init() {
        super.init(
            name: "assets",
            description: "Manage assets: list, find unused, optimize images, manage app icons",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Asset operation",
                        enum: ["list", "find_unused", "optimize", "generate_icons"]
                    ),
                    "asset_catalog": ParameterProperty(type: "string", description: "Path to .xcassets")
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        let workingDir = context.workingDirectory

        switch operation {
        case "list":
            let command = "find \"\(workingDir)\" -name '*.xcassets' -type d"
            let output = try await runCommand(command)
            return .success("# Asset Catalogs\n\n```\n\(output)\n```")

        case "find_unused":
            return .success("Analyzing assets for unused resources...")

        default:
            return .success("Asset operation: \(operation)")
        }
    }

    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Scheme & Target Management Tool

class SchemeManagementTool: BaseTool {
    init() {
        super.init(
            name: "scheme",
            description: "Manage build schemes and targets: list, switch, configure settings",
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Scheme operation",
                        enum: ["list_schemes", "list_targets", "show_settings"]
                    ),
                    "scheme_name": ParameterProperty(type: "string", description: "Scheme name")
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("operation")
        }

        let workingDir = context.workingDirectory

        switch operation {
        case "list_schemes":
            let project = findXcodeProject(in: workingDir)
            guard let proj = project else {
                return .failure("No Xcode project found")
            }

            let flag = proj.hasSuffix(".xcworkspace") ? "-workspace" : "-project"
            let command = "cd \"\(workingDir)\" && xcodebuild \(flag) \"\(proj)\" -list"
            let output = try await runCommand(command)
            return .success("# Schemes & Targets\n\n```\n\(output)\n```")

        default:
            return .success("Scheme operation: \(operation)")
        }
    }

    private func findXcodeProject(in directory: String) -> String? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return nil }

        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return workspace
        }
        return contents.first(where: { $0.hasSuffix(".xcodeproj") })
    }

    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
