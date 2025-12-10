//
//  AutonomousAgent.swift
//  MLX Code
//
//  Autonomous agent that can work independently on complex tasks
//  Created on 2025-12-09
//

import Foundation

/// Autonomous agent for multi-step task execution
actor AutonomousAgent {
    static let shared = AutonomousAgent()

    // MARK: - Properties

    private var isRunning: Bool = false
    private var currentPlan: TaskPlan?
    private var executionLog: [ExecutionStep] = []

    private init() {}

    // MARK: - Task Execution

    /// Executes a complex task autonomously
    /// - Parameters:
    ///   - task: Task description
    ///   - progressHandler: Callback for progress updates
    /// - Returns: Final result
    func executeTask(
        _ task: String,
        context: [String] = [],
        progressHandler: ((AgentProgress) -> Void)? = nil
    ) async throws -> String {
        guard !isRunning else {
            throw AgentError.alreadyRunning
        }

        isRunning = true
        defer { isRunning = false }

        executionLog = []

        // Step 1: Generate execution plan
        progressHandler?(.planning)
        let plan = try await generatePlan(task, context: context)
        currentPlan = plan

        logStep(type: .planning, description: "Created plan with \(plan.steps.count) steps", success: true)
        progressHandler?(.executing(0, plan.steps.count))

        // Step 2: Execute each step
        var results: [String] = []

        for (index, step) in plan.steps.enumerated() {
            progressHandler?(.executing(index + 1, plan.steps.count))

            do {
                let result = try await executeStep(step, context: results)
                results.append(result)
                logStep(type: .execution, description: "Step \(index + 1): \(step.description)", success: true)
            } catch {
                logStep(type: .execution, description: "Step \(index + 1) failed: \(error.localizedDescription)", success: false)

                // Try to recover
                if step.allowRetry {
                    progressHandler?(.retrying(index + 1))
                    let retryResult = try await retryStep(step, previousError: error, context: results)
                    results.append(retryResult)
                    logStep(type: .retry, description: "Step \(index + 1) succeeded on retry", success: true)
                } else {
                    throw error
                }
            }
        }

        // Step 3: Synthesize final result
        progressHandler?(.synthesizing)
        let finalResult = try await synthesizeResults(results, originalTask: task)

        progressHandler?(.complete)
        logStep(type: .completion, description: "Task completed successfully", success: true)

        return finalResult
    }

    /// Generates an execution plan for a task
    private func generatePlan(_ task: String, context: [String]) async throws -> TaskPlan {
        let prompt = """
        Break down this task into concrete, executable steps:

        Task: \(task)

        \(context.isEmpty ? "" : "Context:\n" + context.joined(separator: "\n"))

        Generate a step-by-step plan. For each step:
        1. What to do
        2. What files/commands are needed
        3. Expected outcome
        4. Can it retry if it fails?

        Format as JSON:
        {
          "steps": [
            {
              "description": "...",
              "type": "read_file|write_file|run_command|generate_code",
              "target": "...",
              "allowRetry": true
            }
          ]
        }
        """

        let response = try await MLXService.shared.generate(prompt: prompt)

        // Parse JSON plan
        return try parsePlan(from: response)
    }

    /// Executes a single step
    private func executeStep(_ step: PlanStep, context: [String]) async throws -> String {
        switch step.type {
        case .readFile:
            return try await executeReadFile(step, context: context)
        case .writeFile:
            return try await executeWriteFile(step, context: context)
        case .runCommand:
            return try await executeCommand(step, context: context)
        case .generateCode:
            return try await executeGenerate(step, context: context)
        case .analyzeCode:
            return try await executeAnalyze(step, context: context)
        }
    }

    /// Retries a failed step with adjusted approach
    private func retryStep(_ step: PlanStep, previousError: Error, context: [String]) async throws -> String {
        let prompt = """
        Previous attempt failed with error: \(previousError.localizedDescription)

        Step that failed: \(step.description)
        Type: \(step.type.rawValue)
        Target: \(step.target ?? "none")

        Context from previous steps:
        \(context.joined(separator: "\n"))

        Suggest an alternative approach and execute it.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    /// Synthesizes final result from step results
    private func synthesizeResults(_ results: [String], originalTask: String) async throws -> String {
        let prompt = """
        Original task: \(originalTask)

        Completed steps:
        \(results.enumerated().map { "Step \($0 + 1): \($1)" }.joined(separator: "\n"))

        Synthesize a final, coherent response that:
        1. Summarizes what was accomplished
        2. Highlights key findings or changes
        3. Provides next steps if relevant
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Step Execution Methods

    private func executeReadFile(_ step: PlanStep, context: [String]) async throws -> String {
        guard let path = step.target else {
            throw AgentError.invalidStep("No file path specified")
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        return "File content of \(path): \(content.prefix(1000))..."
    }

    private func executeWriteFile(_ step: PlanStep, context: [String]) async throws -> String {
        guard let path = step.target else {
            throw AgentError.invalidStep("No file path specified")
        }

        // Generate content using context
        let prompt = """
        Generate content for file: \(path)

        Requirements: \(step.description)

        Context:
        \(context.joined(separator: "\n"))

        Provide only the file content, no explanation.
        """

        let content = try await MLXService.shared.generate(prompt: prompt)
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        return "Created file: \(path) (\(content.count) characters)"
    }

    private func executeCommand(_ step: PlanStep, context: [String]) async throws -> String {
        guard let command = step.target else {
            throw AgentError.invalidStep("No command specified")
        }

        // Execute shell command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return "Command output: \(output.prefix(500))"
    }

    private func executeGenerate(_ step: PlanStep, context: [String]) async throws -> String {
        let prompt = """
        Generate code for: \(step.description)

        \(step.target != nil ? "Target: \(step.target!)" : "")

        Context from previous steps:
        \(context.joined(separator: "\n"))

        Generate complete, production-ready code.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    private func executeAnalyze(_ step: PlanStep, context: [String]) async throws -> String {
        let prompt = """
        Analyze: \(step.description)

        \(step.target != nil ? "Target: \(step.target!)" : "")

        Context:
        \(context.joined(separator: "\n"))

        Provide detailed analysis with findings and recommendations.
        """

        return try await MLXService.shared.generate(prompt: prompt)
    }

    // MARK: - Helper Methods

    private func parsePlan(from response: String) throws -> TaskPlan {
        // Extract JSON from response
        let lines = response.components(separatedBy: "\n")
        var jsonLines: [String] = []
        var inJSON = false

        for line in lines {
            if line.contains("{") {
                inJSON = true
            }
            if inJSON {
                jsonLines.append(line)
            }
            if line.contains("}") && inJSON {
                break
            }
        }

        let jsonString = jsonLines.joined(separator: "\n")
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AgentError.invalidPlan("Could not convert response to data")
        }

        do {
            let decoded = try JSONDecoder().decode(TaskPlan.self, from: jsonData)
            return decoded
        } catch {
            // Fallback: create simple single-step plan
            return TaskPlan(steps: [
                PlanStep(
                    description: "Execute task directly",
                    type: .generateCode,
                    target: nil,
                    allowRetry: true
                )
            ])
        }
    }

    private func logStep(type: ExecutionStepType, description: String, success: Bool) {
        let step = ExecutionStep(
            type: type,
            description: description,
            timestamp: Date(),
            success: success
        )
        executionLog.append(step)
        print("[\(type.rawValue.uppercased())] \(success ? "✅" : "❌") \(description)")
    }

    /// Gets the execution log
    func getExecutionLog() async -> [ExecutionStep] {
        return executionLog
    }
}

// MARK: - Supporting Types

/// Task execution plan
struct TaskPlan: Codable {
    let steps: [PlanStep]
}

/// Individual plan step
struct PlanStep: Codable {
    let description: String
    let type: StepType
    let target: String?
    let allowRetry: Bool

    enum StepType: String, Codable {
        case readFile = "read_file"
        case writeFile = "write_file"
        case runCommand = "run_command"
        case generateCode = "generate_code"
        case analyzeCode = "analyze_code"
    }
}

/// Execution step log
struct ExecutionStep {
    let type: ExecutionStepType
    let description: String
    let timestamp: Date
    let success: Bool
}

enum ExecutionStepType: String {
    case planning
    case execution
    case retry
    case completion
}

/// Agent progress updates
enum AgentProgress {
    case planning
    case executing(Int, Int)  // current, total
    case retrying(Int)
    case synthesizing
    case complete
}

/// Agent errors
enum AgentError: LocalizedError {
    case alreadyRunning
    case invalidPlan(String)
    case invalidStep(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Agent is already running a task"
        case .invalidPlan(let details):
            return "Invalid plan: \(details)"
        case .invalidStep(let details):
            return "Invalid step: \(details)"
        }
    }
}
