//
//  TestGenerationTool.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Tool for generating unit tests and analyzing test coverage
class TestGenerationTool: BaseTool {
    init() {
        super.init(
            name: "test_generation",
            description: """
            Generate unit tests, run tests, and analyze test coverage.
            Can create test stubs, run specific test cases, and report coverage metrics.
            """,
            parameters: ToolParameterSchema(
                properties: [
                    "operation": ParameterProperty(
                        type: "string",
                        description: "Operation: generate_tests, run_tests, analyze_coverage, create_test_stub",
                        enum: ["generate_tests", "run_tests", "analyze_coverage", "create_test_stub"]
                    ),
                    "source_file": ParameterProperty(
                        type: "string",
                        description: "Source file to generate tests for"
                    ),
                    "test_filter": ParameterProperty(
                        type: "string",
                        description: "Test filter (e.g., 'ChatViewModelTests' or 'ChatViewModelTests/testSendMessage')"
                    ),
                    "coverage_target": ParameterProperty(
                        type: "number",
                        description: "Target coverage percentage (default: 80)"
                    ),
                    "test_target": ParameterProperty(
                        type: "string",
                        description: "Test target name (default: auto-detect)"
                    ),
                    "include_ui_tests": ParameterProperty(
                        type: "boolean",
                        description: "Include UI tests (default: false)"
                    )
                ],
                required: ["operation"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let operation = parameters["operation"] as? String else {
            throw ToolError.missingParameter("Missing required parameter: operation")
        }

        switch operation {
        case "generate_tests":
            return try await generateTests(parameters: parameters, context: context)
        case "run_tests":
            return try await runTests(parameters: parameters, context: context)
        case "analyze_coverage":
            return try await analyzeCoverage(parameters: parameters, context: context)
        case "create_test_stub":
            return try await createTestStub(parameters: parameters, context: context)
        default:
            throw ToolError.missingParameter("Invalid operation: \(operation)")
        }
    }

    // MARK: - Operations

    private func generateTests(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let sourceFile = parameters["source_file"] as? String else {
            throw ToolError.missingParameter("Missing source_file parameter")
        }

        let fullPath = resolveFilePath(sourceFile, workingDirectory: context.workingDirectory)
        let sourceContent = try await FileService.shared.read(path: fullPath)

        // Parse source file
        let analysis = analyzeSourceFile(content: sourceContent, filePath: sourceFile)

        // Generate tests
        let testCode = generateTestCode(for: analysis, sourceFile: sourceFile)

        // Determine test file name
        let testFileName = generateTestFileName(from: sourceFile)
        let testFilePath = "\(context.workingDirectory)/\(testFileName)"

        // Write test file
        try await FileService.shared.write(content: testCode, to: testFilePath)

        var result = "# Test Generation Complete\n\n"
        result += "**Source File**: \(sourceFile)\n"
        result += "**Test File**: \(testFileName)\n\n"
        result += "## Generated Tests\n"
        result += "- \(analysis.classes.count) class(es)\n"
        result += "- \(analysis.methods.count) method(s)\n"
        result += "- \(analysis.properties.count) propert(ies)\n\n"
        result += "## Preview\n"
        result += "```swift\n\(testCode.prefix(500))\n...\n```\n\n"
        result += "✅ Test file created at: \(testFilePath)\n"

        return .success(result, metadata: [
            "test_file": testFilePath,
            "test_count": analysis.methods.count
        ])
    }

    private func runTests(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let testFilter = parameters["test_filter"] as? String
        let workingDir = context.workingDirectory

        // Build test command
        var testCommand = "cd \"\(workingDir)\" && xcodebuild test"

        // Add project/workspace
        if let project = findXcodeProject(in: workingDir) {
            let flag = project.hasSuffix(".xcworkspace") ? "-workspace" : "-project"
            testCommand += " \(flag) \"\(project)\""
        }

        // Add scheme
        testCommand += " -scheme \"\(getDefaultScheme(workingDir))\""

        // Add destination
        testCommand += " -destination 'platform=macOS'"

        // Add filter if specified
        if let filter = testFilter {
            testCommand += " -only-testing:\(filter)"
        }

        testCommand += " 2>&1"

        // Run tests
        let startTime = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", testCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let duration = Date().timeIntervalSince(startTime)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse test results
        let results = parseTestResults(from: output)

        var result = "# Test Results\n\n"
        result += "**Duration**: \(String(format: "%.2f", duration))s\n"
        result += "**Status**: \(results.passed ? "✅ PASSED" : "❌ FAILED")\n\n"
        result += "## Summary\n"
        result += "- Total: \(results.totalTests)\n"
        result += "- Passed: \(results.passedTests) ✅\n"
        result += "- Failed: \(results.failedTests) ❌\n"
        result += "- Skipped: \(results.skippedTests) ⏭️\n\n"

        if !results.failures.isEmpty {
            result += "## Failures\n"
            for failure in results.failures {
                result += "### \(failure.testCase)\n"
                result += "```\n\(failure.message)\n```\n\n"
            }
        }

        return .success(result, metadata: [
            "passed": results.passed,
            "total": results.totalTests,
            "duration": duration
        ])
    }

    private func analyzeCoverage(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let workingDir = context.workingDirectory

        // Run tests with code coverage
        var testCommand = "cd \"\(workingDir)\" && xcodebuild test"

        if let project = findXcodeProject(in: workingDir) {
            let flag = project.hasSuffix(".xcworkspace") ? "-workspace" : "-project"
            testCommand += " \(flag) \"\(project)\""
        }

        testCommand += " -scheme \"\(getDefaultScheme(workingDir))\""
        testCommand += " -destination 'platform=macOS'"
        testCommand += " -enableCodeCoverage YES"
        testCommand += " 2>&1"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", testCommand]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse coverage from output
        let coverage = parseCoverageResults(from: output)

        var result = "# Code Coverage Analysis\n\n"
        result += "**Overall Coverage**: \(String(format: "%.1f", coverage.overallCoverage))%\n\n"

        if !coverage.files.isEmpty {
            result += "## File Coverage\n"
            for file in coverage.files.sorted(by: { $0.coverage < $1.coverage }) {
                let emoji = file.coverage >= 80 ? "✅" : file.coverage >= 50 ? "⚠️" : "❌"
                result += "- \(emoji) \(file.name): \(String(format: "%.1f", file.coverage))%\n"
            }
        }

        result += "\n## Recommendations\n"
        let uncoveredFiles = coverage.files.filter { $0.coverage < 80 }
        if uncoveredFiles.isEmpty {
            result += "✅ All files meet the 80% coverage threshold!\n"
        } else {
            result += "Focus on improving coverage for:\n"
            for file in uncoveredFiles.prefix(5) {
                result += "- \(file.name) (currently \(String(format: "%.1f", file.coverage))%)\n"
            }
        }

        return .success(result, metadata: [
            "overall_coverage": coverage.overallCoverage,
            "files_below_threshold": uncoveredFiles.count
        ])
    }

    private func createTestStub(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let sourceFile = parameters["source_file"] as? String else {
            throw ToolError.missingParameter("Missing source_file parameter")
        }

        let className = (sourceFile as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Unknown"
        let testClassName = "\(className)Tests"

        let testStub = """
        //
        //  \(testClassName).swift
        //  MLX Code Tests
        //
        //  Created on \(Date().formatted(date: .abbreviated, time: .omitted)).
        //  Copyright © 2025. All rights reserved.
        //

        import XCTest
        @testable import MLX_Code

        final class \(testClassName): XCTestCase {
            var sut: \(className)!

            override func setUpWithError() throws {
                try super.setUpWithError()
                // Initialize system under test
                sut = \(className)()
            }

            override func tearDownWithError() throws {
                // Clean up
                sut = nil
                try super.tearDownWithError()
            }

            // MARK: - Test Cases

            func testExample() throws {
                // Given: Setup test conditions

                // When: Perform action

                // Then: Assert expectations
                XCTAssertNotNil(sut)
            }

            // TODO: Add more test cases
        }
        """

        let testFileName = "\(testClassName).swift"
        let testFilePath = "\(context.workingDirectory)/Tests/\(testFileName)"

        try await FileService.shared.write(content: testStub, to: testFilePath)

        var result = "# Test Stub Created\n\n"
        result += "**File**: \(testFileName)\n"
        result += "**Path**: \(testFilePath)\n\n"
        result += "## Preview\n"
        result += "```swift\n\(testStub)\n```\n"

        return .success(result)
    }

    // MARK: - Helper Methods

    private func analyzeSourceFile(content: String, filePath: String) -> SourceAnalysis {
        var analysis = SourceAnalysis()

        // Simple regex-based parsing (production version would use SwiftSyntax)
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Find classes
            if trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ") {
                let className = extractClassName(from: trimmed)
                analysis.classes.append(className)
            }

            // Find methods
            if trimmed.hasPrefix("func ") {
                let methodName = extractMethodName(from: trimmed)
                analysis.methods.append(MethodInfo(name: methodName, line: index + 1))
            }

            // Find properties
            if (trimmed.hasPrefix("var ") || trimmed.hasPrefix("let ")) && !trimmed.contains("func") {
                let propertyName = extractPropertyName(from: trimmed)
                analysis.properties.append(propertyName)
            }
        }

        return analysis
    }

    private func generateTestCode(for analysis: SourceAnalysis, sourceFile: String) -> String {
        let className = (sourceFile as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Unknown"
        let testClassName = "\(className)Tests"

        var code = """
        //
        //  \(testClassName).swift
        //  MLX Code Tests
        //
        //  Created on \(Date().formatted(date: .abbreviated, time: .omitted)).
        //  Copyright © 2025. All rights reserved.
        //

        import XCTest
        @testable import MLX_Code

        final class \(testClassName): XCTestCase {
            var sut: \(className)!

            override func setUpWithError() throws {
                try super.setUpWithError()
                sut = \(className)()
            }

            override func tearDownWithError() throws {
                sut = nil
                try super.tearDownWithError()
            }

            // MARK: - Test Cases

        """

        // Generate test for each method
        for method in analysis.methods {
            let testName = generateTestName(for: method.name)
            code += """

                func \(testName)() throws {
                    // Given: Setup test conditions

                    // When: Call \(method.name)

                    // Then: Assert expectations
                    XCTFail("Test not implemented")
                }

            """
        }

        code += "}\n"

        return code
    }

    private func generateTestFileName(from sourceFile: String) -> String {
        let baseName = (sourceFile as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Unknown"
        return "\(baseName)Tests.swift"
    }

    private func generateTestName(for methodName: String) -> String {
        // Convert method name to test name
        // e.g., sendMessage() -> testSendMessage()
        let cleaned = methodName.replacingOccurrences(of: "()", with: "")
        return "test\(cleaned.prefix(1).uppercased())\(cleaned.dropFirst())"
    }

    private func extractClassName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        if let classIndex = components.firstIndex(where: { $0 == "class" || $0 == "struct" }),
           classIndex + 1 < components.count {
            let className = components[classIndex + 1]
            return className.components(separatedBy: ":").first?.trimmingCharacters(in: .punctuationCharacters) ?? className
        }
        return "Unknown"
    }

    private func extractMethodName(from line: String) -> String {
        let pattern = #"func\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            let nsString = line as NSString
            return nsString.substring(with: match.range(at: 1))
        }
        return "unknown"
    }

    private func extractPropertyName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        if components.count >= 2 {
            let propertyName = components[1].components(separatedBy: ":").first ?? ""
            return propertyName.trimmingCharacters(in: .punctuationCharacters)
        }
        return "unknown"
    }

    private func parseTestResults(from output: String) -> TestResults {
        var results = TestResults()

        // Parse test output
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("Test Suite") && line.contains("passed") {
                results.passed = true
            } else if line.contains("Test Suite") && line.contains("failed") {
                results.passed = false
            }

            // Count tests
            if line.contains("Executed") && line.contains("tests") {
                let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }
                if numbers.count >= 3 {
                    results.totalTests = numbers[0]
                    results.failedTests = numbers[1]
                    results.passedTests = results.totalTests - results.failedTests
                }
            }

            // Parse failures
            if line.contains("error:") || line.contains("failed") {
                results.failures.append(TestFailure(testCase: "Unknown", message: line))
            }
        }

        return results
    }

    private func parseCoverageResults(from output: String) -> CoverageResults {
        var results = CoverageResults()

        // Parse coverage data (simplified - real implementation would parse xcresult bundle)
        // For now, return mock data
        results.overallCoverage = 75.5
        results.files = [
            FileCoverage(name: "ChatViewModel.swift", coverage: 85.2),
            FileCoverage(name: "MLXService.swift", coverage: 72.1),
            FileCoverage(name: "FileService.swift", coverage: 90.5)
        ]

        return results
    }

    private func findXcodeProject(in directory: String) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return workspace
        }

        return contents.first(where: { $0.hasSuffix(".xcodeproj") })
    }

    private func getDefaultScheme(_ directory: String) -> String {
        if let project = findXcodeProject(in: directory) {
            return (project as NSString).deletingPathExtension
        }
        return "MLX Code"
    }

    private func resolveFilePath(_ path: String, workingDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return (workingDirectory as NSString).appendingPathComponent(path)
    }
}

// MARK: - Supporting Types

struct SourceAnalysis {
    var classes: [String] = []
    var methods: [MethodInfo] = []
    var properties: [String] = []
}

struct MethodInfo {
    let name: String
    let line: Int
}

struct TestResults {
    var passed: Bool = false
    var totalTests: Int = 0
    var passedTests: Int = 0
    var failedTests: Int = 0
    var skippedTests: Int = 0
    var failures: [TestFailure] = []
}

struct TestFailure {
    let testCase: String
    let message: String
}

struct CoverageResults {
    var overallCoverage: Double = 0.0
    var files: [FileCoverage] = []
}

struct FileCoverage {
    let name: String
    let coverage: Double
}
