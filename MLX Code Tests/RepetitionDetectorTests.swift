//
//  RepetitionDetectorTests.swift
//  MLX Code Tests
//
//  Unit tests for RepetitionDetector: pattern detection, buffer management,
//  excessive repetition detection, and edge cases.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class RepetitionDetectorTests: XCTestCase {

    // MARK: - Basic Detection

    func testNoRepetitionInNormalText() {
        let detector = RepetitionDetector()
        let tokens = "The quick brown fox jumps over the lazy dog and runs away into the forest".split(separator: " ")
        var detected = false
        for token in tokens {
            if detector.addToken(String(token) + " ") {
                detected = true
                break
            }
        }
        XCTAssertFalse(detected, "Normal text should not trigger repetition detection")
    }

    func testDetectsRepeatedPattern() {
        let detector = RepetitionDetector(minPatternLength: 5, repetitionThreshold: 3, maxBufferSize: 2000)
        let pattern = "hello world "
        var detected = false
        // Feed the same pattern many times
        for _ in 0..<20 {
            if detector.addToken(pattern) {
                detected = true
                break
            }
        }
        XCTAssertTrue(detected, "Repeating the same pattern should trigger detection")
    }

    func testShortInputDoesNotTrigger() {
        let detector = RepetitionDetector()
        XCTAssertFalse(detector.addToken("Hi"), "Single short token should not trigger detection")
        XCTAssertFalse(detector.addToken(" there"), "Two short tokens should not trigger detection")
    }

    // MARK: - Buffer Management

    func testResetClearsBuffer() {
        let detector = RepetitionDetector()
        _ = detector.addToken("Some text")
        XCTAssertFalse(detector.currentBuffer.isEmpty, "Buffer should have content after adding a token")

        detector.reset()
        XCTAssertTrue(detector.currentBuffer.isEmpty, "Buffer should be empty after reset")
    }

    func testBufferTrimming() {
        let detector = RepetitionDetector(maxBufferSize: 100)
        // Add more than maxBufferSize characters
        let longToken = String(repeating: "a", count: 150)
        _ = detector.addToken(longToken)
        XCTAssertLessThanOrEqual(detector.currentBuffer.count, 100, "Buffer should be trimmed to maxBufferSize")
    }

    // MARK: - Excessive Repetition Detection

    func testDetectsExcessiveRepetition() {
        let detector = RepetitionDetector()
        let repeatedSentence = "please let me know. "
        for _ in 0..<10 {
            _ = detector.addToken(repeatedSentence)
        }
        XCTAssertTrue(detector.detectExcessiveRepetition(),
            "Many identical sentences should trigger excessive repetition detection")
    }

    func testNoExcessiveRepetitionInVariedText() {
        let detector = RepetitionDetector()
        let sentences = [
            "The first point is about design. ",
            "The second point covers testing. ",
            "The third addresses deployment. ",
            "Finally we discuss monitoring. ",
            "In conclusion everything works. "
        ]
        for s in sentences {
            _ = detector.addToken(s)
        }
        XCTAssertFalse(detector.detectExcessiveRepetition(),
            "Varied sentences should not trigger excessive repetition")
    }

    func testTooFewSentencesDoesNotTrigger() {
        let detector = RepetitionDetector()
        _ = detector.addToken("Short text. And one more.")
        XCTAssertFalse(detector.detectExcessiveRepetition(),
            "Fewer than 3 sentences should not trigger excessive repetition")
    }

    // MARK: - Configuration

    func testCustomThreshold() {
        let detector = RepetitionDetector(minPatternLength: 5, repetitionThreshold: 5, maxBufferSize: 2000)
        let pattern = "abcdefghij"
        var count = 0
        var detected = false
        // With threshold 5, need 5 consecutive repeats
        for _ in 0..<10 {
            count += 1
            if detector.addToken(pattern) {
                detected = true
                break
            }
        }
        if detected {
            XCTAssertGreaterThanOrEqual(count, 5, "Should need at least 5 repetitions with threshold 5")
        }
        // Detection is expected with 10 iterations
        XCTAssertTrue(detected, "Should detect after feeding 10 copies of 10-char pattern with threshold 5")
    }

    // MARK: - Performance

    func testPerformanceWithLargeBuffer() {
        let detector = RepetitionDetector(maxBufferSize: 5000)
        measure {
            detector.reset()
            for i in 0..<500 {
                _ = detector.addToken("token_\(i) ")
            }
        }
    }
}
