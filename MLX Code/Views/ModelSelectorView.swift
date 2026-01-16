//
//  ModelSelectorView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// View for selecting and loading MLX models
struct ModelSelectorView: View {
    /// App settings
    @ObservedObject private var settings = AppSettings.shared

    /// Whether the model is currently loading
    @State private var isLoading = false

    /// Whether the model is currently downloading
    @State private var isDownloading = false

    /// Download progress (0.0 to 1.0)
    @State private var downloadProgress: Double = 0.0

    /// Download status message
    @State private var downloadStatus: String = ""

    /// Error message to display
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Model picker with glass styling and visible text
                Picker("Model", selection: $settings.selectedModel) {
                    Text("No Model Selected")
                        .tag(nil as MLXModel?)
                        .foregroundColor(ModernColors.textSecondary)

                    if settings.availableModels.isEmpty {
                        Text("No models available - check Settings")
                            .tag(nil as MLXModel?)
                            .foregroundColor(ModernColors.textSecondary)
                    } else {
                        ForEach(settings.availableModels) { model in
                            Text(model.name + (model.isDownloaded ? "" : " ↓"))
                                .tag(model as MLXModel?)
                                .foregroundColor(ModernColors.textPrimary)
                        }
                    }
                }
                .frame(width: 250)
                .disabled(isLoading || isDownloading)
                .pickerStyle(.menu)
                .tint(ModernColors.cyan)
                .foregroundColor(ModernColors.textPrimary)

                // Load/Unload/Download button
                if let selectedModel = settings.selectedModel {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else if isDownloading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else if !selectedModel.isDownloaded {
                        Button(action: downloadModel) {
                            HStack(spacing: 4) {
                                Image(systemName: "icloud.and.arrow.down")
                                Text("Download")
                            }
                            .foregroundColor(ModernColors.cyan)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: toggleModelLoad) {
                            Text(isModelCurrentlyLoaded ? "Unload" : "Load")
                                .frame(width: 60)
                                .foregroundColor(ModernColors.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Download progress bar
            if isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Text(downloadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onChange(of: settings.selectedModel) {
            // When model selection changes, check if we need to load it
            updateModelLoadedState()
        }
        .onAppear {
            // Ensure models are initialized
            if settings.availableModels.isEmpty {
                logWarning("No models available on appear, initializing with common models", category: "ModelSelector")
                settings.availableModels = MLXModel.commonModels()
                if settings.selectedModel == nil {
                    settings.selectedModel = settings.availableModels.first
                }
            }
            logInfo("Model selector initialized with \(settings.availableModels.count) models", category: "ModelSelector")

            // Verify downloaded models actually exist
            verifyModelDownloads()

            // Update model loaded state
            updateModelLoadedState()
        }
    }

    // MARK: - Computed Properties

    /// Whether a model is currently loaded (tracked via state)
    @State private var isAnyModelLoaded: Bool = false

    /// Whether the selected model is currently loaded
    private var isModelCurrentlyLoaded: Bool {
        return isAnyModelLoaded
    }

    // MARK: - Actions

    /// Downloads the selected model
    private func downloadModel() {
        guard let model = settings.selectedModel else {
            return
        }

        Task {
            isDownloading = true
            downloadProgress = 0.0
            downloadStatus = "Preparing download..."
            errorMessage = nil

            do {
                // Download model and get updated model with correct path
                let updatedModel = try await MLXService.shared.downloadModel(model) { progress in
                    Task { @MainActor in
                        downloadProgress = progress

                        // Update status message based on progress
                        if progress < 0.1 {
                            downloadStatus = "Initializing download..."
                        } else if progress < 1.0 {
                            if let sizeInBytes = model.sizeInBytes {
                                let mbDownloaded = Int(progress * Double(sizeInBytes) / 1_000_000)
                                let mbTotal = Int(sizeInBytes / 1_000_000)
                                downloadStatus = "Downloading \(model.name)... \(mbDownloaded) / \(mbTotal) MB"
                            } else {
                                downloadStatus = "Downloading \(model.name)..."
                            }
                        } else {
                            downloadStatus = "Download complete!"
                        }
                    }
                }

                // Update model with correct path and mark as downloaded
                var downloadedModel: MLXModel?
                await MainActor.run {
                    if let index = settings.availableModels.firstIndex(where: { $0.id == model.id }) {
                        var modelToUpdate = updatedModel
                        modelToUpdate.isDownloaded = true
                        settings.availableModels[index] = modelToUpdate

                        // Update selected model reference
                        settings.selectedModel = modelToUpdate
                        downloadedModel = modelToUpdate
                    }
                }

                logInfo("Model downloaded successfully: \(model.name) at path: \(updatedModel.path)", category: "ModelSelector")

                // Automatically load the model after download
                if let modelToLoad = downloadedModel {
                    logInfo("Automatically loading downloaded model: \(modelToLoad.name)", category: "ModelSelector")

                    do {
                        try await MLXService.shared.loadModel(modelToLoad)
                        logInfo("Model loaded successfully: \(modelToLoad.name)", category: "ModelSelector")
                    } catch {
                        logError("Failed to auto-load model: \(error.localizedDescription)", category: "ModelSelector")
                        // Show error but don't fail the download
                        await MainActor.run {
                            errorMessage = "Model downloaded but failed to load: \(error.localizedDescription)\nYou can manually load it later."
                        }
                    }
                }

            } catch {
                errorMessage = "Failed to download model: \(error.localizedDescription)"
                logError("Model download error: \(error.localizedDescription)", category: "ModelSelector")
            }

            await MainActor.run {
                isDownloading = false
                downloadProgress = 0.0
                downloadStatus = ""
            }
        }
    }

    /// Toggles between loading and unloading the selected model
    private func toggleModelLoad() {
        print("🔘🔘🔘 toggleModelLoad() CALLED")

        guard let model = settings.selectedModel else {
            print("❌❌❌ No model selected!")
            return
        }

        print("✅✅✅ Selected model: \(model.name), downloaded: \(model.isDownloaded), path: \(model.path)")

        Task {
            print("🚀🚀🚀 Starting load task for: \(model.name)")
            isLoading = true
            errorMessage = nil

            do {
                if isModelCurrentlyLoaded {
                    // Unload model
                    print("📤📤📤 Unloading model...")
                    await MLXService.shared.unloadModel()
                    print("✅✅✅ Model unloaded")
                    logInfo("Model unloaded: \(model.name)", category: "ModelSelector")
                } else {
                    // Load model
                    print("📥📥📥 Loading model: \(model.name)")
                    print("📁📁📁 Model path: \(model.path)")
                    print("✔️✔️✔️ Model isDownloaded: \(model.isDownloaded)")

                    guard model.isDownloaded else {
                        print("❌❌❌ Model not downloaded!")
                        errorMessage = "Model is not downloaded. Please download it first."
                        return
                    }

                    print("🔵🔵🔵 Calling MLXService.shared.loadModel()...")
                    try await MLXService.shared.loadModel(model)
                    print("✅✅✅ MLXService.loadModel() returned successfully!")
                    logInfo("Model loaded: \(model.name)", category: "ModelSelector")

                    // CRITICAL: Trigger model selection change to update ChatViewModel
                    print("📢📢📢 Triggering selectedModel change notification...")
                    await MainActor.run {
                        // Trigger the @Published property change
                        settings.selectedModel = model
                    }
                    print("✅✅✅ Model selection notification sent")
                }
            } catch {
                print("❌❌❌ ERROR in toggleModelLoad: \(error.localizedDescription)")
                print("❌❌❌ Error type: \(type(of: error))")
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                logError("Model load error: \(error.localizedDescription)", category: "ModelSelector")
            }

            print("🏁🏁🏁 toggleModelLoad() task completing")
            isLoading = false
            updateModelLoadedState()
        }
    }

    /// Updates the model loaded state
    private func updateModelLoadedState() {
        Task {
            let loaded = await MLXService.shared.isLoaded()

            await MainActor.run {
                isAnyModelLoaded = loaded
                print("🔄🔄🔄 Updated isAnyModelLoaded = \(loaded)")
            }
        }
    }

    /// Verifies that downloaded models actually exist on disk
    private func verifyModelDownloads() {
        Task {
            let fileManager = FileManager.default
            var modelsToUpdate: [(index: Int, model: MLXModel)] = []

            // Check each model marked as downloaded
            for (index, model) in settings.availableModels.enumerated() where model.isDownloaded {
                let expandedPath = (model.path as NSString).expandingTildeInPath

                // Check if the model directory exists
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

                if !exists || !isDirectory.boolValue {
                    // Model directory doesn't exist or is not a directory
                    logWarning("Model marked as downloaded but not found at path: \(expandedPath)", category: "ModelSelector")
                    var updatedModel = model
                    updatedModel.isDownloaded = false
                    modelsToUpdate.append((index, updatedModel))
                } else {
                    // Check if config.json exists (indicator that download completed)
                    let configPath = expandedPath + "/config.json"
                    if !fileManager.fileExists(atPath: configPath) {
                        logWarning("Model directory exists but config.json missing: \(expandedPath)", category: "ModelSelector")
                        var updatedModel = model
                        updatedModel.isDownloaded = false
                        modelsToUpdate.append((index, updatedModel))
                    }
                }
            }

            // Update models on main thread
            if !modelsToUpdate.isEmpty {
                await MainActor.run {
                    for (index, updatedModel) in modelsToUpdate {
                        settings.availableModels[index] = updatedModel
                        logInfo("Updated model '\(updatedModel.name)' - marked as not downloaded", category: "ModelSelector")

                        // If this was the selected model, update the reference
                        if settings.selectedModel?.id == updatedModel.id {
                            settings.selectedModel = updatedModel
                        }
                    }

                    if modelsToUpdate.count == 1 {
                        logInfo("Verified downloads: 1 model needs re-download", category: "ModelSelector")
                    } else {
                        logInfo("Verified downloads: \(modelsToUpdate.count) models need re-download", category: "ModelSelector")
                    }
                }
            } else {
                logInfo("Verified downloads: All models OK", category: "ModelSelector")
            }
        }
    }
}

// MARK: - Preview

struct ModelSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSelectorView()
            .padding()
    }
}
