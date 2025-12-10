//
//  MultiModelComparison.swift
//  MLX Code
//
//  Run same query against multiple models simultaneously
//  Created on 2025-12-09
//

import Foundation

/// Runs queries against multiple models in parallel
actor MultiModelComparison {
    static let shared = MultiModelComparison()

    private init() {}

    // MARK: - Comparison Execution

    /// Runs same prompt against multiple models
    /// - Parameters:
    ///   - prompt: Query to run
    ///   - models: Models to compare
    ///   - parameters: Generation parameters
    /// - Returns: Results from each model
    func compare(
        prompt: String,
        models: [MLXModel],
        parameters: ModelParameters? = nil
    ) async throws -> [ComparisonResult] {
        guard models.count >= 2 else {
            throw ComparisonError.notEnoughModels
        }

        guard models.count <= 5 else {
            throw ComparisonError.tooManyModels
        }

        var results: [ComparisonResult] = []

        // Run in parallel
        await withTaskGroup(of: ComparisonResult.self) { group in
            for model in models {
                group.addTask {
                    let startTime = Date()

                    do {
                        // Load model
                        try await MLXService.shared.loadModel(model)

                        // Generate response
                        let response = try await MLXService.shared.generate(
                            prompt: prompt,
                            parameters: parameters
                        )

                        let duration = Date().timeIntervalSince(startTime)

                        return ComparisonResult(
                            model: model,
                            response: response,
                            duration: duration,
                            tokensPerSecond: Double(response.count / 4) / duration, // Rough estimate
                            success: true,
                            error: nil
                        )
                    } catch {
                        return ComparisonResult(
                            model: model,
                            response: "",
                            duration: Date().timeIntervalSince(startTime),
                            tokensPerSecond: 0,
                            success: false,
                            error: error.localizedDescription
                        )
                    }
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Sort by duration (fastest first)
        return results.sorted { $0.duration < $1.duration }
    }

    /// Scores which model gave the best response
    /// - Parameter results: Comparison results
    /// - Returns: Ranked results with quality scores
    func rankByQuality(_ results: [ComparisonResult], originalPrompt: String) async throws -> [RankedResult] {
        // Use an evaluator model to score responses
        let evaluationPrompt = """
        Original query: \(originalPrompt)

        Evaluate these responses and score 1-10:

        \(results.enumerated().map { i, r in
            "Response \(i+1) (\(r.model.name)):\n\(r.response)\n"
        }.joined(separator: "\n"))

        For each response, provide:
        - Score (1-10)
        - Reasoning
        - Strengths
        - Weaknesses

        Format: Response X: Score, Reasoning
        """

        let evaluation = try await MLXService.shared.generate(prompt: evaluationPrompt)

        // Parse scores (simple implementation)
        var ranked: [RankedResult] = []
        for result in results {
            ranked.append(RankedResult(
                result: result,
                qualityScore: 7.0, // TODO: Parse from evaluation
                reasoning: "Evaluation pending"
            ))
        }

        return ranked.sorted { $0.qualityScore > $1.qualityScore }
    }
}

// MARK: - Supporting Types

/// Result from one model in comparison
struct ComparisonResult: Identifiable {
    let id = UUID()
    let model: MLXModel
    let response: String
    let duration: TimeInterval
    let tokensPerSecond: Double
    let success: Bool
    let error: String?

    var durationFormatted: String {
        String(format: "%.2fs", duration)
    }

    var speedFormatted: String {
        String(format: "%.1f tok/s", tokensPerSecond)
    }
}

/// Ranked comparison result with quality score
struct RankedResult {
    let result: ComparisonResult
    let qualityScore: Double
    let reasoning: String

    var grade: String {
        switch qualityScore {
        case 9...10: return "A+"
        case 8..<9: return "A"
        case 7..<8: return "B"
        case 6..<7: return "C"
        default: return "D"
        }
    }
}

/// Comparison errors
enum ComparisonError: LocalizedError {
    case notEnoughModels
    case tooManyModels

    var errorDescription: String? {
        switch self {
        case .notEnoughModels:
            return "Need at least 2 models for comparison"
        case .tooManyModels:
            return "Maximum 5 models for comparison"
        }
    }
}
