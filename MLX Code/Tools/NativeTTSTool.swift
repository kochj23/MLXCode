//
//  NativeTTSTool.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//

import Foundation
import AVFoundation

/// Native macOS text-to-speech using AVSpeechSynthesizer
///
/// SECURITY: 100% SAFE - Uses only built-in macOS APIs
/// - No external dependencies
/// - No model downloads
/// - No code execution
/// - No network requests
/// - Built-in to macOS since 10.14
///
/// **Author:** Jordan Koch
class NativeTTSTool: BaseTool {

    init() {
        super.init(
            name: "native_tts",
            description: "Convert text to speech using built-in macOS voices. Fast, free, no external dependencies. Supports 40+ languages with multiple voice options. 100% secure - uses only native macOS APIs.",
            parameters: ToolParameterSchema(
                properties: [
                    "text": ParameterProperty(
                        type: "string",
                        description: "The text to convert to speech"
                    ),
                    "language": ParameterProperty(
                        type: "string",
                        description: "Language code (e.g., 'en-US', 'es-ES', 'fr-FR', 'de-DE', 'ja-JP')",
                        default: "en-US"
                    ),
                    "rate": ParameterProperty(
                        type: "number",
                        description: "Speech rate: 0.0 (slowest) to 1.0 (fastest), default 0.5",
                        default: "0.5"
                    ),
                    "voice_name": ParameterProperty(
                        type: "string",
                        description: "Specific voice name (e.g., 'Samantha', 'Alex', 'Daniel'). Leave empty for default."
                    ),
                    "save_to": ParameterProperty(
                        type: "string",
                        description: "Optional: Save audio to file path (.aiff format)"
                    )
                ],
                required: ["text"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        // Extract parameters
        let text = try stringParameter(parameters, key: "text")
        let language = (try? stringParameter(parameters, key: "language")) ?? "en-US"
        let rate = (try? stringParameter(parameters, key: "rate")).flatMap { Float($0) } ?? 0.5
        let voiceName = try? stringParameter(parameters, key: "voice_name")
        let saveTo = try? stringParameter(parameters, key: "save_to")

        logInfo("[NativeTTS] Speaking: '\(text.prefix(50))...' in \(language)", category: "NativeTTSTool")

        // Get available voices
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // Select voice
        var selectedVoice: AVSpeechSynthesisVoice?

        if let voiceName = voiceName {
            // Find voice by name
            selectedVoice = voices.first { $0.name == voiceName }
            if selectedVoice == nil {
                logWarning("[NativeTTS] Voice '\(voiceName)' not found, using default", category: "NativeTTSTool")
            }
        }

        if selectedVoice == nil {
            // Find voice by language
            selectedVoice = AVSpeechSynthesisVoice(language: language)
        }

        if selectedVoice == nil {
            // Fallback to first available voice
            selectedVoice = voices.first
        }

        guard let voice = selectedVoice else {
            return .failure("No voices available")
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Speak or save to file
        if let savePath = saveTo {
            // Save to file
            let expandedPath = (savePath as NSString).expandingTildeInPath
            let audioURL = URL(fileURLWithPath: expandedPath)

            let success = await saveToFile(utterance: utterance, url: audioURL)

            if success {
                let duration = Date().timeIntervalSince(startTime)
                logInfo("[NativeTTS] ✅ Saved to: \(expandedPath)", category: "NativeTTSTool")

                return .success("""
                🔊 **Audio Generated**

                **Text:** \(text.prefix(100))\(text.count > 100 ? "..." : "")
                **Voice:** \(voice.name)
                **Language:** \(voice.language)
                **Duration:** \(String(format: "%.2f", duration))s
                **Saved to:** \(expandedPath)
                """, metadata: [
                    "voice": voice.name,
                    "language": voice.language,
                    "duration": duration,
                    "saved_path": expandedPath
                ])
            } else {
                return .failure("Failed to save audio to file")
            }
        } else {
            // Speak directly
            let synthesizer = AVSpeechSynthesizer()

            await withCheckedContinuation { continuation in
                let delegate = SpeechDelegate {
                    continuation.resume()
                }
                synthesizer.delegate = delegate
                synthesizer.speak(utterance)
            }

            let duration = Date().timeIntervalSince(startTime)
            logInfo("[NativeTTS] ✅ Spoke \(text.count) characters in \(String(format: "%.2f", duration))s", category: "NativeTTSTool")

            return .success("""
            🔊 **Text Spoken**

            **Text:** \(text.prefix(100))\(text.count > 100 ? "..." : "")
            **Voice:** \(voice.name)
            **Language:** \(voice.language)
            **Characters:** \(text.count)
            """, metadata: [
                "voice": voice.name,
                "language": voice.language,
                "characters": text.count,
                "duration": duration
            ])
        }
    }

    // MARK: - File Saving

    private func saveToFile(utterance: AVSpeechUtterance, url: URL) async -> Bool {
        // macOS doesn't provide direct AVSpeechSynthesizer → file export
        // This would require using NSSpeechSynthesizer (older API) which does support file output

        let synthesizer = NSSpeechSynthesizer()

        if let voice = utterance.voice {
            synthesizer.setVoice(NSSpeechSynthesizer.VoiceName(rawValue: voice.identifier))
        }

        synthesizer.startSpeaking(utterance.speechString, to: url)

        // Wait for completion
        while synthesizer.isSpeaking {
            try? await Task.sleep(for: .milliseconds(100))
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Voice Discovery

    /// Lists all available voices on the system
    static func listAvailableVoices() -> [VoiceInfo] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.map { voice in
            VoiceInfo(
                name: voice.name,
                identifier: voice.identifier,
                language: voice.language,
                quality: voice.quality.description
            )
        }
    }
}

// MARK: - Speech Delegate

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// MARK: - Models

struct VoiceInfo: Codable {
    let name: String
    let identifier: String
    let language: String
    let quality: String
}

extension AVSpeechSynthesisVoiceQuality {
    var description: String {
        switch self {
        case .default: return "Default"
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        @unknown default: return "Unknown"
        }
    }
}
