//
//  XcodeService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for Xcode integration
/// Provides functionality to build, test, and interact with Xcode projects
actor XcodeService {
    /// Shared singleton instance
    static let shared = XcodeService()

    /// Current Xcode project path
    private var projectPath: String?

    private init() {}

    // MARK: - Project Management

    /// Sets the current Xcode project
    /// - Parameter path: Path to .xcodeproj or .xcworkspace
    /// - Throws: XcodeServiceError if project is invalid
    func setProject(path: String) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw XcodeServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw XcodeServiceError.projectNotFound(expandedPath)
        }

        // Verify it's an Xcode project or workspace
        let pathExtension = (expandedPath as NSString).pathExtension
        guard pathExtension == "xcodeproj" || pathExtension == "xcworkspace" else {
            throw XcodeServiceError.invalidProjectType
        }

        projectPath = expandedPath
        await SecureLogger.shared.info("Set Xcode project: \(path)", category: "XcodeService")
    }

    /// Gets the current project path
    /// - Returns: Current project path, or nil if not set
    func getCurrentProject() -> String? {
        return projectPath
    }

    // MARK: - Build Operations

    /// Builds the Xcode project
    /// - Parameters:
    ///   - scheme: Build scheme name
    ///   - configuration: Build configuration (Debug/Release)
    ///   - outputHandler: Optional callback for build output
    /// - Returns: Build result
    /// - Throws: XcodeServiceError if build fails
    func build(
        scheme: String? = nil,
        configuration: String = "Debug",
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> BuildResult {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Building project: \(project)", category: "XcodeService")

        var arguments = ["build"]

        // Add project/workspace flag
        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        // Add scheme if provided
        if let scheme = scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        // Add configuration
        arguments.append(contentsOf: ["-configuration", configuration])

        // Execute xcodebuild
        let output = try await executeXcodebuild(arguments: arguments, outputHandler: outputHandler)

        // Parse build result
        let succeeded = !output.contains("** BUILD FAILED **")
        let warnings = countOccurrences(of: "warning:", in: output)
        let errors = countOccurrences(of: "error:", in: output)

        let result = BuildResult(
            succeeded: succeeded,
            output: output,
            warnings: warnings,
            errors: errors
        )

        await SecureLogger.shared.info("Build \(succeeded ? "succeeded" : "failed") - Warnings: \(warnings), Errors: \(errors)", category: "XcodeService")

        return result
    }

    /// Cleans the build directory
    /// - Throws: XcodeServiceError if clean fails
    func clean() async throws {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Cleaning project: \(project)", category: "XcodeService")

        var arguments = ["clean"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        _ = try await executeXcodebuild(arguments: arguments)

        await SecureLogger.shared.info("Clean completed", category: "XcodeService")
    }

    // MARK: - Test Operations

    /// Runs tests for the Xcode project
    /// - Parameters:
    ///   - scheme: Test scheme name
    ///   - testTarget: Optional specific test target
    ///   - outputHandler: Optional callback for test output
    /// - Returns: Test result
    /// - Throws: XcodeServiceError if tests fail to run
    func test(
        scheme: String,
        testTarget: String? = nil,
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> TestResult {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Running tests for project: \(project)", category: "XcodeService")

        var arguments = ["test"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        arguments.append(contentsOf: ["-scheme", scheme])

        if let target = testTarget {
            arguments.append(contentsOf: ["-only-testing", target])
        }

        let output = try await executeXcodebuild(arguments: arguments, outputHandler: outputHandler)

        // Parse test results
        let succeeded = output.contains("** TEST SUCCEEDED **")
        let totalTests = countOccurrences(of: "Test Case", in: output)
        let failedTests = countOccurrences(of: "failed", in: output)
        let passedTests = totalTests - failedTests

        let result = TestResult(
            succeeded: succeeded,
            output: output,
            totalTests: totalTests,
            passedTests: passedTests,
            failedTests: failedTests
        )

        await SecureLogger.shared.info("Tests \(succeeded ? "passed" : "failed") - Total: \(totalTests), Passed: \(passedTests), Failed: \(failedTests)", category: "XcodeService")

        return result
    }

    // MARK: - Project Information

    /// Lists all schemes in the project
    /// - Returns: Array of scheme names
    /// - Throws: XcodeServiceError if listing fails
    func listSchemes() async throws -> [String] {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        var arguments = ["-list"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        let output = try await executeXcodebuild(arguments: arguments)

        // Parse schemes from output
        var schemes: [String] = []
        var inSchemesSection = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Schemes:" {
                inSchemesSection = true
                continue
            }

            if inSchemesSection {
                if trimmed.isEmpty {
                    break
                }
                schemes.append(trimmed)
            }
        }

        return schemes
    }

    /// Lists all targets in the project
    /// - Returns: Array of target names
    /// - Throws: XcodeServiceError if listing fails
    func listTargets() async throws -> [String] {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        var arguments = ["-list"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        let output = try await executeXcodebuild(arguments: arguments)

        // Parse targets from output
        var targets: [String] = []
        var inTargetsSection = false

        for line in output.components(separatedBy: .newlines) {
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

        return targets
    }

    // MARK: - Private Methods

    /// Executes xcodebuild with given arguments
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - outputHandler: Optional callback for output
    /// - Returns: Command output
    /// - Throws: XcodeServiceError if execution fails
    private func executeXcodebuild(
        arguments: [String],
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Setup output handlers if callback provided
        if let handler = outputHandler {
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    handler(output)
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw XcodeServiceError.executionFailed(error)
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var fullOutput = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if !errorOutput.isEmpty {
            fullOutput += "\n" + errorOutput
        }

        // Check exit status
        guard process.terminationStatus == 0 else {
            throw XcodeServiceError.commandFailed(process.terminationStatus, fullOutput)
        }

        return fullOutput
    }

    /// Counts occurrences of a substring in a string
    /// - Parameters:
    ///   - substring: Substring to count
    ///   - string: String to search
    /// - Returns: Number of occurrences
    private func countOccurrences(of substring: String, in string: String) -> Int {
        return string.components(separatedBy: substring).count - 1
    }
}

// MARK: - Supporting Types

/// Result from a build operation
struct BuildResult {
    let succeeded: Bool
    let output: String
    let warnings: Int
    let errors: Int
}

/// Result from a test operation
struct TestResult {
    let succeeded: Bool
    let output: String
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
}

/// Errors that can occur during Xcode service operations
enum XcodeServiceError: LocalizedError {
    case invalidPath(String)
    case projectNotFound(String)
    case invalidProjectType
    case noProjectSet
    case executionFailed(Error)
    case commandFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid project path: \(path)"
        case .projectNotFound(let path):
            return "Project not found: \(path)"
        case .invalidProjectType:
            return "Path must be an .xcodeproj or .xcworkspace file"
        case .noProjectSet:
            return "No Xcode project has been set"
        case .executionFailed(let error):
            return "Failed to execute xcodebuild: \(error.localizedDescription)"
        case .commandFailed(let status, let output):
            return "xcodebuild failed with exit code \(status): \(output)"
        }
    }
}
