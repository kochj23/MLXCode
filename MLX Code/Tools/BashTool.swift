//
//  BashTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for executing bash commands
class BashTool: BaseTool {
    /// Maximum command execution time (30 seconds)
    private let timeout: TimeInterval = 30.0

    init() {
        let parameters = ToolParameterSchema(
            properties: [
                "command": ParameterProperty(
                    type: "string",
                    description: "Bash command to execute"
                ),
                "working_directory": ParameterProperty(
                    type: "string",
                    description: "Working directory for command execution (optional)"
                ),
                "timeout": ParameterProperty(
                    type: "number",
                    description: "Command timeout in seconds (default: 30, max: 120)"
                )
            ],
            required: ["command"]
        )

        super.init(
            name: "bash",
            description: "Execute bash commands and return output",
            parameters: parameters
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        do {
            // Validate required parameters
            try validateParameters(parameters, required: ["command"])

            let command = try stringParameter(parameters, key: "command")
            let workingDir = try? stringParameter(parameters, key: "working_directory", default: context.workingDirectory)
            let timeoutSeconds = try? intParameter(parameters, key: "timeout", default: 30)

            // 🔒 CRITICAL SECURITY: Validate command before execution
            let validatedCommand = try CommandValidator.validateBashCommand(command)

            // Validate timeout
            let actualTimeout = min(Double(timeoutSeconds ?? 30), 120.0)

            logInfo("Executing validated bash command: \(validatedCommand.prefix(100))", category: "BashTool")

            // Execute command (use validated version)
            let result = try await executeCommand(
                command: validatedCommand,
                workingDirectory: workingDir ?? context.workingDirectory,
                timeout: actualTimeout
            )

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

    // MARK: - Command Execution

    /// Execute a bash command
    private func executeCommand(command: String, workingDirectory: String, timeout: TimeInterval) async throws -> ToolResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Timeout timer
            var timeoutOccurred = false
            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                if process.isRunning {
                    process.terminate()
                    timeoutOccurred = true
                }
            }

            do {
                try process.run()

                // Wait for completion
                process.waitUntilExit()
                timer.invalidate()

                // Read output
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: outputData, encoding: .utf8) ?? ""
                let stderr = String(data: errorData, encoding: .utf8) ?? ""

                // Check for timeout
                if timeoutOccurred {
                    continuation.resume(returning: .failure(
                        "Command timed out after \(timeout) seconds",
                        metadata: [
                            "command": command,
                            "working_directory": workingDirectory,
                            "timeout": timeout
                        ]
                    ))
                    return
                }

                // Check exit status
                let exitCode = process.terminationStatus

                if exitCode == 0 {
                    let output = stdout.isEmpty ? stderr : stdout
                    continuation.resume(returning: .success(output, metadata: [
                        "command": command,
                        "exit_code": exitCode,
                        "working_directory": workingDirectory
                    ]))
                } else {
                    let errorOutput = stderr.isEmpty ? stdout : stderr
                    continuation.resume(returning: .failure(
                        "Command failed with exit code \(exitCode):\n\(errorOutput)",
                        metadata: [
                            "command": command,
                            "exit_code": exitCode,
                            "working_directory": workingDirectory,
                            "stdout": stdout,
                            "stderr": stderr
                        ]
                    ))
                }

            } catch {
                timer.invalidate()
                continuation.resume(returning: .failure(
                    "Failed to execute command: \(error.localizedDescription)",
                    metadata: [
                        "command": command,
                        "error": error.localizedDescription
                    ]
                ))
            }
        }
    }
}
