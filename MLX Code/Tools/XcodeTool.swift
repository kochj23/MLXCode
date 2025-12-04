//
//  XcodeTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for Xcode operations (build, test, clean, archive)
class XcodeTool: BaseTool {
    enum XcodeOperation: String {
        case build
        case test
        case clean
        case archive
        case analyze
        case list_schemes
        case list_targets
    }

    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "Xcode operation: build, test, clean, archive, analyze, list_schemes, list_targets",
                    enum: ["build", "test", "clean", "archive", "analyze", "list_schemes", "list_targets"]
                ),
                "project_path": ParameterProperty(
                    type: "string",
                    description: "Path to .xcodeproj or .xcworkspace"
                ),
                "scheme": ParameterProperty(
                    type: "string",
                    description: "Scheme name to build/test"
                ),
                "configuration": ParameterProperty(
                    type: "string",
                    description: "Build configuration: Debug or Release (default: Debug)"
                ),
                "destination": ParameterProperty(
                    type: "string",
                    description: "Build destination (e.g., 'platform=macOS', 'generic/platform=iOS')"
                ),
                "clean_build": ParameterProperty(
                    type: "boolean",
                    description: "Clean before building (default: false)"
                ),
                "parallel": ParameterProperty(
                    type: "boolean",
                    description: "Enable parallel build (default: true)"
                )
            ],
            required: ["operation"]
        )

        super.init(
            name: "xcode",
            description: "Perform Xcode operations: build, test, clean, archive, analyze",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        do {
            // Validate required parameters
            try validateParameters(parameters, required: ["operation"])

            let operationStr = try stringParameter(parameters, key: "operation")
            guard let operation = XcodeOperation(rawValue: operationStr) else {
                throw ToolError.invalidParameterType("operation", expected: "valid Xcode operation")
            }

            // Get project path (default to context project path)
            let projectPath: String
            if let path = try? stringParameter(parameters, key: "project_path") {
                projectPath = resolvePath(path, workingDirectory: context.workingDirectory)
            } else if let contextPath = context.projectPath {
                projectPath = contextPath
            } else {
                // Try to find .xcodeproj in working directory
                projectPath = try findXcodeProject(in: context.workingDirectory)
            }

            logInfo("Executing Xcode operation: \(operation) on \(projectPath)", category: "XcodeTool")

            // Execute operation
            let result: ToolResult
            switch operation {
            case .build:
                result = try await buildProject(projectPath: projectPath, parameters: parameters, context: context)
            case .test:
                result = try await testProject(projectPath: projectPath, parameters: parameters, context: context)
            case .clean:
                result = try await cleanProject(projectPath: projectPath, parameters: parameters, context: context)
            case .archive:
                result = try await archiveProject(projectPath: projectPath, parameters: parameters, context: context)
            case .analyze:
                result = try await analyzeProject(projectPath: projectPath, parameters: parameters, context: context)
            case .list_schemes:
                result = try await listSchemes(projectPath: projectPath, context: context)
            case .list_targets:
                result = try await listTargets(projectPath: projectPath, context: context)
            }

            // Record telemetry
            let _ = Date().timeIntervalSince(startTime)
            ToolTelemetry(
                toolName: name,
                startTime: startTime,
                endTime: Date(),
                success: result.success,
                error: result.error
            ).log()

            return result

        } catch {
            let _ = Date().timeIntervalSince(startTime)
            ToolTelemetry(
                toolName: name,
                startTime: startTime,
                endTime: Date(),
                success: false,
                error: error.localizedDescription
            ).log()

            throw error
        }
    }

    // MARK: - Xcode Operations

    /// Build project
    private func buildProject(projectPath: String, parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var args = buildXcodebuildArgs(projectPath: projectPath, parameters: parameters)
        args.append("build")

        return try await runXcodebuild(args: args, operation: "build")
    }

    /// Test project
    private func testProject(projectPath: String, parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var args = buildXcodebuildArgs(projectPath: projectPath, parameters: parameters)
        args.append("test")

        return try await runXcodebuild(args: args, operation: "test")
    }

    /// Clean project
    private func cleanProject(projectPath: String, parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var args = buildXcodebuildArgs(projectPath: projectPath, parameters: parameters)
        args.append("clean")

        return try await runXcodebuild(args: args, operation: "clean")
    }

    /// Archive project
    private func archiveProject(projectPath: String, parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var args = buildXcodebuildArgs(projectPath: projectPath, parameters: parameters)

        let archivePath = "/tmp/MLX_Code_\(Date().timeIntervalSince1970).xcarchive"
        args.append("archive")
        args.append("-archivePath")
        args.append(archivePath)

        let result = try await runXcodebuild(args: args, operation: "archive")

        if result.success {
            return .success("Archive created at: \(archivePath)", metadata: [
                "archive_path": archivePath,
                "project": projectPath
            ])
        }

        return result
    }

    /// Analyze project
    private func analyzeProject(projectPath: String, parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        var args = buildXcodebuildArgs(projectPath: projectPath, parameters: parameters)
        args.append("analyze")

        return try await runXcodebuild(args: args, operation: "analyze")
    }

    /// List schemes
    private func listSchemes(projectPath: String, context: ToolContext) async throws -> ToolResult {
        let args = ["-list", "-project", projectPath]
        return try await runXcodebuild(args: args, operation: "list")
    }

    /// List targets
    private func listTargets(projectPath: String, context: ToolContext) async throws -> ToolResult {
        let args = ["-list", "-project", projectPath]
        let result = try await runXcodebuild(args: args, operation: "list")

        // Parse output to extract targets
        if result.success, let output = result.output as? String {
            let lines = output.components(separatedBy: .newlines)
            var targets: [String] = []
            var inTargetsSection = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed == "Targets:" {
                    inTargetsSection = true
                    continue
                }

                if inTargetsSection {
                    if trimmed.isEmpty || trimmed.hasSuffix(":") {
                        break
                    }
                    targets.append(trimmed)
                }
            }

            return .success(targets.joined(separator: "\n"), metadata: [
                "project": projectPath,
                "target_count": targets.count
            ])
        }

        return result
    }

    // MARK: - Helpers

    /// Build xcodebuild arguments
    private func buildXcodebuildArgs(projectPath: String, parameters: [String: Any]) -> [String] {
        var args: [String] = []

        // Project/Workspace
        if projectPath.hasSuffix(".xcworkspace") {
            args.append("-workspace")
        } else {
            args.append("-project")
        }
        args.append(projectPath)

        // Scheme
        if let scheme = try? stringParameter(parameters, key: "scheme") {
            args.append("-scheme")
            args.append(scheme)
        }

        // Configuration
        let configuration = try? stringParameter(parameters, key: "configuration", default: "Debug")
        args.append("-configuration")
        args.append(configuration ?? "Debug")

        // Destination
        if let destination = try? stringParameter(parameters, key: "destination") {
            args.append("-destination")
            args.append(destination)
        }

        // Clean build
        if let cleanBuild = try? boolParameter(parameters, key: "clean_build", default: false), cleanBuild {
            args.append("clean")
        }

        // Parallel build
        if let parallel = try? boolParameter(parameters, key: "parallel", default: true), !parallel {
            args.append("-parallelizeTargets")
            args.append("NO")
        }

        return args
    }

    /// Run xcodebuild command
    private func runXcodebuild(args: [String], operation: String) async throws -> ToolResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = args
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: outputData, encoding: .utf8) ?? ""
                let stderr = String(data: errorData, encoding: .utf8) ?? ""

                let exitCode = process.terminationStatus

                if exitCode == 0 {
                    // Parse build results
                    let (errors, warnings) = parseBuildOutput(stdout + stderr)

                    var summary = "Xcode \(operation) succeeded"
                    if errors > 0 || warnings > 0 {
                        summary += " with \(errors) error(s) and \(warnings) warning(s)"
                    }

                    continuation.resume(returning: .success(summary, metadata: [
                        "operation": operation,
                        "exit_code": exitCode,
                        "errors": errors,
                        "warnings": warnings,
                        "output": stdout
                    ]))
                } else {
                    let (errors, warnings) = parseBuildOutput(stdout + stderr)

                    continuation.resume(returning: .failure(
                        "Xcode \(operation) failed with \(errors) error(s) and \(warnings) warning(s)",
                        metadata: [
                            "operation": operation,
                            "exit_code": exitCode,
                            "errors": errors,
                            "warnings": warnings,
                            "output": stdout,
                            "error_output": stderr
                        ]
                    ))
                }

            } catch {
                continuation.resume(returning: .failure(
                    "Failed to execute xcodebuild: \(error.localizedDescription)",
                    metadata: ["error": error.localizedDescription]
                ))
            }
        }
    }

    /// Parse build output for errors and warnings
    private func parseBuildOutput(_ output: String) -> (errors: Int, warnings: Int) {
        var errors = 0
        var warnings = 0

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") {
                errors += 1
            } else if line.contains("warning:") {
                warnings += 1
            }
        }

        return (errors, warnings)
    }

    /// Find Xcode project in directory
    private func findXcodeProject(in directory: String) throws -> String {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            throw ToolError.notFound("No Xcode project found in \(directory)")
        }

        // Look for .xcworkspace first, then .xcodeproj
        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return (directory as NSString).appendingPathComponent(workspace)
        }

        if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
            return (directory as NSString).appendingPathComponent(project)
        }

        throw ToolError.notFound("No Xcode project found in \(directory)")
    }

    /// Resolve relative path to absolute path
    private func resolvePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }

        if path.hasPrefix("~/") {
            return NSString(string: path).expandingTildeInPath
        }

        return (workingDirectory as NSString).appendingPathComponent(path)
    }
}
