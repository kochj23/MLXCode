//
//  ImageGenerationTool.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//  Inspired by TinyLLM project by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation
import AppKit

/// Tool for generating images using DALL-E or Stable Diffusion
/// Based on image generation features from TinyLLM by Jason Cox
class ImageGenerationTool: BaseTool {

    init() {
        super.init(
            name: "generate_image",
            description: "Generate images using AI (DALL-E, Stable Diffusion). Useful for creating app icons, UI mockups, diagrams, or concept art.",
            parameters: ToolParameterSchema(
                properties: [
                    "prompt": ParameterProperty(
                        type: "string",
                        description: "Description of the image to generate"
                    ),
                    "size": ParameterProperty(
                        type: "string",
                        description: "Image size: '256x256', '512x512', '1024x1024', '1792x1024', '1024x1792'",
                        enum: ["256x256", "512x512", "1024x1024", "1792x1024", "1024x1792"],
                        default: "1024x1024"
                    ),
                    "style": ParameterProperty(
                        type: "string",
                        description: "Image style: 'vivid' (dramatic), 'natural' (realistic)",
                        enum: ["vivid", "natural"],
                        default: "natural"
                    ),
                    "quality": ParameterProperty(
                        type: "string",
                        description: "Quality: 'standard', 'hd'",
                        enum: ["standard", "hd"],
                        default: "standard"
                    ),
                    "save_to": ParameterProperty(
                        type: "string",
                        description: "Optional: Save image to file path"
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
        let size = (try? stringParameter(parameters, key: "size")) ?? "1024x1024"
        let style = (try? stringParameter(parameters, key: "style")) ?? "natural"
        let quality = (try? stringParameter(parameters, key: "quality")) ?? "standard"
        let saveTo = try? stringParameter(parameters, key: "save_to")

        logInfo("[ImageGen] Generating: \(prompt)", category: "ImageGenerationTool")

        // Check for OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ??
                          context.settings.value(forKey: "openai_api_key") as? String else {
            return .failure("OpenAI API key not configured. Set OPENAI_API_KEY environment variable or configure in settings.")
        }

        do {
            // Call DALL-E API
            let imageURL = try await generateImage(
                prompt: prompt,
                size: size,
                style: style,
                quality: quality,
                apiKey: apiKey
            )

            // Download generated image
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)

            // Save to file if requested
            var savedPath: String?
            if let savePath = saveTo {
                let expandedPath = (savePath as NSString).expandingTildeInPath
                try imageData.write(to: URL(fileURLWithPath: expandedPath))
                savedPath = expandedPath
                logInfo("[ImageGen] 💾 Saved to: \(expandedPath)", category: "ImageGenerationTool")
            } else {
                // Save to temporary location
                let tempDir = FileManager.default.temporaryDirectory
                let filename = "generated_\(Date().timeIntervalSince1970).png"
                let tempURL = tempDir.appendingPathComponent(filename)
                try imageData.write(to: tempURL)
                savedPath = tempURL.path

                // Open in default viewer
                NSWorkspace.shared.open(tempURL)
            }

            let duration = Date().timeIntervalSince(startTime)

            let output = """
            🎨 **Image Generated Successfully**

            **Prompt:** \(prompt)
            **Size:** \(size)
            **Style:** \(style)
            **Quality:** \(quality)
            **File Size:** \(formatBytes(imageData.count))
            **Generation Time:** \(String(format: "%.2f", duration))s
            **Saved to:** \(savedPath ?? "Temporary directory")

            The image has been opened in your default image viewer.
            """

            logInfo("[ImageGen] ✅ Generated image: \(size) in \(String(format: "%.2f", duration))s", category: "ImageGenerationTool")

            return .success(output, metadata: [
                "prompt": prompt,
                "size": size,
                "file_size": imageData.count,
                "duration": duration,
                "saved_path": savedPath ?? ""
            ])

        } catch {
            logError("[ImageGen] ❌ Error: \(error.localizedDescription)", category: "ImageGenerationTool")
            return .failure("Image generation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - DALL-E API

    private func generateImage(prompt: String, size: String, style: String, quality: String, apiKey: String) async throws -> URL {
        let endpoint = URL(string: "https://api.openai.com/v1/images/generations")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": size,
            "quality": quality,
            "style": style
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response from OpenAI")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ToolError.executionFailed("OpenAI API error: \(message)")
            }
            throw ToolError.executionFailed("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let urlString = first["url"] as? String,
              let imageURL = URL(string: urlString) else {
            throw ToolError.executionFailed("Failed to parse DALL-E response")
        }

        return imageURL
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Models

struct NewsHeadline: Codable {
    let title: String
    let url: String?
    let source: String?
    let date: Date?
}
