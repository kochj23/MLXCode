//
//  RepetitionDetector.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Detects repetitive patterns in streaming text to prevent infinite loops
class RepetitionDetector {
    /// Minimum pattern length to check (in characters)
    private let minPatternLength: Int

    /// Maximum pattern length to check (in characters)
    private let maxPatternLength: Int

    /// Number of consecutive repetitions before triggering detection
    private let repetitionThreshold: Int

    /// Accumulated text buffer for pattern detection
    private var buffer: String = ""

    /// Maximum buffer size to prevent memory issues
    private let maxBufferSize: Int

    /// Initialize repetition detector
    /// - Parameters:
    ///   - minPatternLength: Minimum pattern size to detect (default: 10 characters)
    ///   - maxPatternLength: Maximum pattern size to detect (default: 200 characters)
    ///   - repetitionThreshold: Number of repetitions needed to trigger (default: 3)
    ///   - maxBufferSize: Maximum buffer size in characters (default: 2000)
    init(
        minPatternLength: Int = 10,
        maxPatternLength: Int = 200,
        repetitionThreshold: Int = 3,
        maxBufferSize: Int = 2000
    ) {
        self.minPatternLength = minPatternLength
        self.maxPatternLength = maxPatternLength
        self.repetitionThreshold = repetitionThreshold
        self.maxBufferSize = maxBufferSize
    }

    /// Add new token to buffer and check for repetition
    /// - Parameter token: New token from stream
    /// - Returns: True if repetition detected, false otherwise
    func addToken(_ token: String) -> Bool {
        buffer += token

        // Trim buffer if too large (keep last maxBufferSize characters)
        if buffer.count > maxBufferSize {
            let startIndex = buffer.index(buffer.endIndex, offsetBy: -maxBufferSize)
            buffer = String(buffer[startIndex...])
        }

        // Check for repetition
        return detectRepetition()
    }

    /// Reset the detector state
    func reset() {
        buffer = ""
    }

    /// Get current buffer contents
    var currentBuffer: String {
        return buffer
    }

    /// Detect if the buffer contains repetitive patterns
    /// - Returns: True if repetition detected
    private func detectRepetition() -> Bool {
        // Need enough text to detect patterns
        guard buffer.count >= minPatternLength * repetitionThreshold else {
            return false
        }

        // Check different pattern lengths
        for patternLength in minPatternLength...min(maxPatternLength, buffer.count / repetitionThreshold) {
            if hasRepeatingPattern(length: patternLength) {
                return true
            }
        }

        return false
    }

    /// Check if buffer has repeating pattern of given length
    /// - Parameter length: Pattern length to check
    /// - Returns: True if pattern repeats at least repetitionThreshold times
    private func hasRepeatingPattern(length: Int) -> Bool {
        guard buffer.count >= length * repetitionThreshold else {
            return false
        }

        // Extract the pattern from the end of the buffer
        let endIndex = buffer.endIndex
        let patternStart = buffer.index(endIndex, offsetBy: -length)
        let pattern = String(buffer[patternStart..<endIndex])

        // Check if this pattern appears consecutively before current position
        var matchCount = 1  // Current pattern at end counts as 1
        var checkPosition = patternStart

        for _ in 1..<repetitionThreshold {
            // Move back one pattern length
            guard checkPosition >= buffer.index(buffer.startIndex, offsetBy: length) else {
                break
            }

            let checkEnd = checkPosition
            let checkStart = buffer.index(checkEnd, offsetBy: -length)
            let checkPattern = String(buffer[checkStart..<checkEnd])

            // Compare patterns (normalize whitespace for comparison)
            if normalizeWhitespace(pattern) == normalizeWhitespace(checkPattern) {
                matchCount += 1
                checkPosition = checkStart
            } else {
                break
            }
        }

        return matchCount >= repetitionThreshold
    }

    /// Normalize whitespace in string for comparison
    /// - Parameter text: Input text
    /// - Returns: Normalized text
    private func normalizeWhitespace(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Check if buffer ends with excessive repetition of short phrases
    /// This catches patterns like "please let me know. please let me know. please let me know."
    /// - Returns: True if excessive repetition detected
    func detectExcessiveRepetition() -> Bool {
        // Split into sentences/phrases
        let sentences = buffer.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count >= 3 else {
            return false
        }

        // Check last 5 sentences
        let recentSentences = sentences.suffix(5)
        let sentenceSet = Set(recentSentences.map { normalizeWhitespace($0) })

        // If most recent sentences are the same, it's excessive repetition
        // Example: 5 recent sentences, but only 1-2 unique = repetition
        if sentenceSet.count <= 2 && recentSentences.count >= 4 {
            return true
        }

        return false
    }
}

/// Extension to ChatViewModel for repetition detection
extension ChatViewModel {
    /// Maximum response length in characters
    static let maxResponseLength = 8000

    /// Maximum response length in tokens (approximate)
    static let maxResponseTokens = 2000
}
