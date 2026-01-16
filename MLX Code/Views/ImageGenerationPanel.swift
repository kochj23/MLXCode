//
//  ImageGenerationPanel.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/7/26.
//  Copyright © 2026 Local. All rights reserved.
//

import SwiftUI
import AppKit

/// Dedicated panel for image generation with proper GUI controls
///
/// **Features:**
/// - Large prompt text area (not cramped chat input)
/// - Model selector with descriptions
/// - Size presets (Portrait, Square, Landscape)
/// - Style templates for common use cases
/// - Advanced options (steps, guidance, seed)
/// - Preview area for generated image
/// - Quick access buttons for common styles
///
/// **Author:** Jordan Koch
struct ImageGenerationPanel: View {
    @EnvironmentObject var settings: AppSettings
    @State private var prompt: String = ""
    @State private var selectedModel: String = "flux"
    @State private var imageSize: ImageSize = .square512
    @State private var showAdvanced: Bool = false
    @State private var numSteps: Int = 4
    @State private var guidanceScale: Double = 7.5
    @State private var seed: String = ""
    @State private var generatedImagePath: String?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?

    // Size presets
    enum ImageSize: String, CaseIterable, Identifiable {
        case portrait512 = "Portrait (512×768)"
        case square512 = "Square (512×512)"
        case square1024 = "Large Square (1024×1024)"
        case landscape512 = "Landscape (768×512)"
        case landscape1024 = "Large Landscape (1024×768)"

        var id: String { rawValue }

        var dimensions: (width: Int, height: Int) {
            switch self {
            case .portrait512: return (512, 768)
            case .square512: return (512, 512)
            case .square1024: return (1024, 1024)
            case .landscape512: return (768, 512)
            case .landscape1024: return (1024, 768)
            }
        }
    }

    // Style templates
    let styleTemplates: [(name: String, prompt: String)] = [
        ("Portrait", "Professional portrait photography, studio lighting, 85mm lens, shallow depth of field, sharp focus"),
        ("Landscape", "Landscape photography, golden hour, dramatic sky, wide angle lens, professional"),
        ("Product", "Commercial product photography, studio lighting, clean background, high key, sharp details"),
        ("Architecture", "Architectural photography, modern design, wide angle, professional real estate photo"),
        ("Food", "Food photography, natural window light, shallow depth of field, appetizing, Michelin style"),
        ("App Icon", "Modern app icon, minimalist design, flat style, clean, professional, 1024x1024")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Left: Controls
                VStack(alignment: .leading, spacing: 16) {
                    // Prompt area
                    promptSection

                    // Style templates
                    styleTemplatesSection

                    // Model selector
                    modelSection

                    // Size selector
                    sizeSection

                    // Advanced options
                    advancedSection

                    Spacer()

                    // Generate button
                    generateButton
                }
                .frame(width: 400)
                .padding()

                Divider()

                // Right: Preview
                previewSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)

            Text("Image Generation")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Text("Powered by MLX")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.headline)

            TextEditor(text: $prompt)
                .font(.body)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if prompt.isEmpty {
                            Text("Describe the image you want to generate...")
                                .foregroundColor(.gray)
                                .padding(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                )
        }
    }

    // MARK: - Style Templates

    private var styleTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Styles")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], spacing: 8) {
                ForEach(styleTemplates, id: \.name) { template in
                    Button(action: {
                        if prompt.isEmpty {
                            prompt = template.prompt
                        } else {
                            prompt += ", " + template.prompt
                        }
                    }) {
                        Text(template.name)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.headline)

            Picker("", selection: $selectedModel) {
                Text("⚡ SDXL-Turbo (Fast, 2-5s)").tag("sdxl-turbo")
                Text("⚖️ Stable Diffusion 2.1 (Quality, 5-15s)").tag("sd-2.1")
                Text("🌟 FLUX Schnell (Professional, 10-30s)").tag("flux")
                Text("👔 FLUX Dev (Best, 30-60s)").tag("flux-dev")
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedModel) { newModel in
                // Adjust default steps based on model
                switch newModel {
                case "sdxl-turbo":
                    numSteps = 4
                case "sd-2.1":
                    numSteps = 20
                case "flux":
                    numSteps = 4
                case "flux-dev":
                    numSteps = 50
                default:
                    numSteps = 4
                }
            }
        }
    }

    // MARK: - Size Section

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size")
                .font(.headline)

            Picker("", selection: $imageSize) {
                ForEach(ImageSize.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 12) {
                    // Steps
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Steps: \(numSteps)")
                                .font(.caption)
                            Spacer()
                            Text("More = better quality but slower")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(numSteps) },
                            set: { numSteps = Int($0) }
                        ), in: 1...100, step: 1)
                    }

                    // Guidance Scale
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Guidance: \(guidanceScale, specifier: "%.1f")")
                                .font(.caption)
                            Spacer()
                            Text("Higher = follows prompt more strictly")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $guidanceScale, in: 1.0...20.0, step: 0.5)
                    }

                    // Seed
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seed (optional)")
                            .font(.caption)
                        TextField("Random", text: $seed)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }
                .padding(.top, 8)
            }
            .font(.headline)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generateImage) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isGenerating ? "Generating..." : "Generate Image")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(prompt.isEmpty || isGenerating ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(prompt.isEmpty || isGenerating)
        .buttonStyle(.plain)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack {
            if let imagePath = generatedImagePath,
               let nsImage = NSImage(contentsOfFile: imagePath) {
                VStack(spacing: 12) {
                    // Image
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)

                    // Actions
                    HStack {
                        Button("Open in Finder") {
                            NSWorkspace.shared.selectFile(imagePath, inFileViewerRootedAtPath: "")
                        }

                        Button("Copy to Clipboard") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.writeObjects([nsImage])
                        }

                        Button("Save As...") {
                            saveImageAs(imagePath)
                        }
                    }
                    .padding(.bottom)
                }
                .padding()
            } else if isGenerating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Generating your image...")
                        .foregroundColor(.secondary)
                    Text(getEstimatedTime())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No image generated yet")
                        .foregroundColor(.secondary)
                    Text("Enter a prompt and click Generate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func generateImage() {
        guard !prompt.isEmpty else { return }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let tool = LocalImageGenerationTool()
                let dims = imageSize.dimensions

                var parameters: [String: Any] = [
                    "prompt": prompt,
                    "model": selectedModel,
                    "width": dims.width,
                    "height": dims.height,
                    "num_steps": numSteps,
                    "guidance_scale": String(guidanceScale)
                ]

                if let seedInt = Int(seed), !seed.isEmpty {
                    parameters["seed"] = seedInt
                }

                let context = ToolContext(workingDirectory: FileManager.default.currentDirectoryPath,
                                         settings: settings)
                let result = try await tool.execute(parameters: parameters, context: context)

                await MainActor.run {
                    isGenerating = false

                    if result.success {
                        if let path = result.metadata["saved_path"] as? String {
                            generatedImagePath = path
                        }
                    } else {
                        errorMessage = result.error ?? "Unknown error"
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func getEstimatedTime() -> String {
        switch selectedModel {
        case "sdxl-turbo":
            return "Estimated time: 2-5 seconds"
        case "sd-2.1":
            return "Estimated time: 5-15 seconds"
        case "flux":
            return "Estimated time: 10-30 seconds"
        case "flux-dev":
            return "Estimated time: 30-60 seconds"
        default:
            return "Generating..."
        }
    }

    private func saveImageAs(_ sourcePath: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "generated_image.png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.copyItem(atPath: sourcePath, toPath: url.path)
            }
        }
    }
}

// MARK: - Preview

struct ImageGenerationPanel_Previews: PreviewProvider {
    static var previews: some View {
        ImageGenerationPanel()
            .environmentObject(AppSettings.shared)
            .frame(width: 900, height: 600)
    }
}
