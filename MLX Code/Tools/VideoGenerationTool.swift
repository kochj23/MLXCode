//
//  VideoGenerationTool.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//

import Foundation
import AppKit

/// Generate videos from image sequences using FFmpeg
/// Generates multiple frames and stitches them into smooth video
///
/// FAST: 2-5 minutes for 30-60 frame videos on M3 Ultra
/// FREE: No API costs, 100% local
/// SAFE: Uses existing Stable Diffusion (SafeTensors)
///
/// **Author:** Jordan Koch
class VideoGenerationTool: BaseTool {

    init() {
        super.init(
            name: "generate_video",
            description: "Generate video from image sequence. Creates multiple frames and combines with FFmpeg. Fast on M3 Ultra (2-5 min). FREE and local. Useful for: product rotations, timelapse, animations, UI transitions.",
            parameters: ToolParameterSchema(
                properties: [
                    "prompt": ParameterProperty(
                        type: "string",
                        description: "Base description for the video (e.g., 'sunset timelapse', 'rotating logo')"
                    ),
                    "num_frames": ParameterProperty(
                        type: "integer",
                        description: "Number of frames to generate (default: 30, max: 120)",
                        default: "30"
                    ),
                    "fps": ParameterProperty(
                        type: "integer",
                        description: "Frames per second (default: 24, options: 24, 30, 60)",
                        default: "24"
                    ),
                    "variation_strength": ParameterProperty(
                        type: "number",
                        description: "How much each frame varies (0.0-1.0, default: 0.3)",
                        default: "0.3"
                    ),
                    "save_to": ParameterProperty(
                        type: "string",
                        description: "Output video path (default: /tmp/video_[timestamp].mp4)"
                    )
                ],
                required: ["prompt"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        // Extract parameters
        let prompt = try stringParameter(parameters, key: "prompt")
        let numFrames = (try? intParameter(parameters, key: "num_frames")) ?? 30
        let fps = (try? intParameter(parameters, key: "fps")) ?? 24
        let variationStrength = (try? stringParameter(parameters, key: "variation_strength")).flatMap { Float($0) } ?? 0.3
        let saveTo = try? stringParameter(parameters, key: "save_to")

        // Validate
        guard numFrames >= 10 && numFrames <= 120 else {
            return .failure("num_frames must be between 10 and 120")
        }

        guard fps == 24 || fps == 30 || fps == 60 else {
            return .failure("fps must be 24, 30, or 60")
        }

        logInfo("[VideoGen] Generating \(numFrames) frame video: '\(prompt)'", category: "VideoGenerationTool")

        // Create temporary directory for frames
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("video_\(Date().timeIntervalSince1970)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Determine output path
        let outputPath: String
        if let path = saveTo {
            outputPath = (path as NSString).expandingTildeInPath
        } else {
            outputPath = "/tmp/video_\(Date().timeIntervalSince1970).mp4"
        }

        logInfo("[VideoGen] Temp frames: \(tempDir.path)", category: "VideoGenerationTool")
        logInfo("[VideoGen] Output video: \(outputPath)", category: "VideoGenerationTool")

        // Generate frames
        var generatedFrames: [String] = []

        for frame in 0..<numFrames {
            let progress = Float(frame) / Float(numFrames - 1)

            // Create varied prompt for this frame
            let framePrompt = "\(prompt), frame \(frame), seed \(frame * 42)"

            let framePath = tempDir.appendingPathComponent(String(format: "frame_%04d.png", frame)).path

            // Generate image using Python script
            let selectedModelId = await AppSettings.shared.selectedImageModel
            let modelArg = selectedModelId.contains("1-5") ? "sd" : "sdxl"
            let steps = modelArg == "sdxl" ? 4 : 20

            let command = """
            cd ~/mlx-examples/stable_diffusion && \
            /Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9 \
            txt2image.py "\(framePrompt)" --model \(modelArg) --steps \(steps) --seed \(frame * 42) --n_images 1 --output "\(framePath)"
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            try? process.run()

            // Wait for completion
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }

            if FileManager.default.fileExists(atPath: framePath) {
                generatedFrames.append(framePath)
                logInfo("[VideoGen] Frame \(frame + 1)/\(numFrames) generated", category: "VideoGenerationTool")
            } else {
                logError("[VideoGen] Failed to generate frame \(frame)", category: "VideoGenerationTool")
            }
        }

        guard !generatedFrames.isEmpty else {
            return .failure("Failed to generate any frames")
        }

        logInfo("[VideoGen] Generated \(generatedFrames.count) frames, combining with FFmpeg...", category: "VideoGenerationTool")

        // Combine frames with FFmpeg
        let ffmpegCommand = """
        /opt/homebrew/bin/ffmpeg -y -framerate \(fps) -pattern_type glob -i '\(tempDir.path)/frame_*.png' \
        -c:v libx264 -pix_fmt yuv420p -preset fast "\(outputPath)"
        """

        let ffmpegProcess = Process()
        ffmpegProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        ffmpegProcess.arguments = ["-c", ffmpegCommand]

        try? ffmpegProcess.run()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ffmpegProcess.terminationHandler = { _ in
                continuation.resume()
            }
        }

        // Clean up temp frames
        try? FileManager.default.removeItem(at: tempDir)

        let duration = Date().timeIntervalSince(startTime)

        if FileManager.default.fileExists(atPath: outputPath) {
            // Open video in default player
            NSWorkspace.shared.open(URL(fileURLWithPath: outputPath))

            let fileSize = try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize ?? 0) / 1_000_000

            return .success("""
            Video generated successfully!

            Frames: \(generatedFrames.count)/\(numFrames)
            Duration: \(String(format: "%.1f", duration))s
            FPS: \(fps)
            Size: \(String(format: "%.1f", fileSizeMB))MB
            Path: \(outputPath)

            Video opened in default player.
            """)
        } else {
            return .failure("FFmpeg failed to create video. Check that FFmpeg is installed: brew install ffmpeg")
        }
    }
}
