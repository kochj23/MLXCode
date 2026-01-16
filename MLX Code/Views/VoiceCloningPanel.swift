//
//  VoiceCloningPanel.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/7/26.
//  Copyright © 2026 Local. All rights reserved.
//

import SwiftUI
import AppKit
import AVFoundation

/// Dedicated panel for voice cloning with proper GUI controls
///
/// **Features:**
/// - Drag & drop area for WAV files
/// - File picker button for browsing
/// - Audio preview (play reference voice)
/// - Large text area for script
/// - Voice library (saved voices for quick reuse)
/// - Audio player for generated speech
/// - Export options
///
/// **Author:** Jordan Koch
struct VoiceCloningPanel: View {
    @State private var selectedAudioPath: String?
    @State private var scriptText: String = ""
    @State private var isDragging: Bool = false
    @State private var isGenerating: Bool = false
    @State private var generatedAudioPath: String?
    @State private var errorMessage: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingReference: Bool = false
    @State private var isPlayingGenerated: Bool = false

    // Saved voices library
    @AppStorage("savedVoices") private var savedVoicesJSON: String = "[]"
    @State private var savedVoices: [SavedVoice] = []

    struct SavedVoice: Codable, Identifiable {
        let id: UUID
        let name: String
        let path: String
        let dateAdded: Date

        init(name: String, path: String) {
            self.id = UUID()
            self.name = name
            self.path = path
            self.dateAdded = Date()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Left: Voice selection and script
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Voice selection
                        voiceSelectionSection

                        Divider()

                        // Script input
                        scriptSection

                        // Generate button (right after script, no spacer)
                        generateButton
                    }
                    .padding()
                }
                .frame(width: 400)

                Divider()

                // Right: Voice library and preview
                VStack(alignment: .leading, spacing: 16) {
                    // Current voice preview
                    currentVoicePreview

                    Divider()

                    // Voice library
                    voiceLibrarySection

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            loadSavedVoices()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "waveform.circle")
                .font(.title2)

            Text("Voice Cloning")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Text("Powered by MLX")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Voice Selection

    private var voiceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reference Voice")
                .font(.headline)

            // Drag & drop area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        style: StrokeStyle(lineWidth: 2, dash: [10])
                    )
                    .foregroundColor(isDragging ? .blue : .gray.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragging ? Color.blue.opacity(0.1) : Color.clear)
                    )

                VStack(spacing: 12) {
                    Image(systemName: isDragging ? "arrow.down.circle.fill" : "waveform.circle")
                        .font(.system(size: 48))
                        .foregroundColor(isDragging ? .blue : .gray)

                    if let path = selectedAudioPath {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.callout)
                            .fontWeight(.medium)

                        HStack {
                            Button("Play") {
                                playAudio(path, isReference: true)
                            }
                            .disabled(isPlayingReference)

                            Button("Remove") {
                                selectedAudioPath = nil
                            }
                        }
                    } else {
                        Text("Drag & drop WAV file here")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Browse...") {
                            selectAudioFile()
                        }
                    }
                }
                .padding()
            }
            .frame(height: 180)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }

            if let path = selectedAudioPath {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Voice will be cloned from this audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Save to Library") {
                    showSaveVoiceDialog()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Script Section

    private var scriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script")
                .font(.headline)

            Text("Enter the text you want the cloned voice to say")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $scriptText)
                .font(.body)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if scriptText.isEmpty {
                            Text("Type what you want the voice to say...")
                                .foregroundColor(.gray)
                                .padding(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                )

            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Longer text = longer generation time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: 8) {
            Button(action: cloneVoice) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "mic.badge.plus")
                    }
                    Text(isGenerating ? "Cloning Voice..." : "Clone Voice & Generate Speech")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedAudioPath == nil || scriptText.isEmpty || isGenerating ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(selectedAudioPath == nil || scriptText.isEmpty || isGenerating)
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])

            Text("Tip: Press Cmd+Return to generate")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Current Voice Preview

    private var currentVoicePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated Speech")
                .font(.headline)

            if let audioPath = generatedAudioPath {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Speech generated successfully!")
                            .font(.callout)
                            .foregroundColor(.green)
                    }

                    // Audio player controls
                    HStack {
                        Button(action: {
                            playAudio(audioPath, isReference: false)
                        }) {
                            HStack {
                                Image(systemName: isPlayingGenerated ? "stop.fill" : "play.fill")
                                Text(isPlayingGenerated ? "Stop" : "Play")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            NSWorkspace.shared.selectFile(audioPath, inFileViewerRootedAtPath: "")
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Reveal")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save As...") {
                        saveAudioAs(audioPath)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            } else if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Cloning voice and generating speech...")
                        .foregroundColor(.secondary)
                    Text("This may take 30-60 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No speech generated yet")
                        .foregroundColor(.secondary)
                    Text("Select a voice and enter text to generate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }

    // MARK: - Voice Library

    private var voiceLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Library")
                .font(.headline)

            if savedVoices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(.gray)
                    Text("No saved voices yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Click 'Save to Library' to save voices for quick reuse")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(savedVoices) { voice in
                            VoiceLibraryRow(
                                voice: voice,
                                onSelect: {
                                    selectedAudioPath = voice.path
                                },
                                onDelete: {
                                    deleteSavedVoice(voice)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func selectAudioFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.wav, .audio]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                selectedAudioPath = url.path
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "wav" else {
                return
            }

            DispatchQueue.main.async {
                selectedAudioPath = url.path
            }
        }

        return true
    }

    private func cloneVoice() {
        guard let audioPath = selectedAudioPath, !scriptText.isEmpty else { return }

        isGenerating = true
        errorMessage = nil
        generatedAudioPath = nil

        Task {
            do {
                let tool = VoiceCloningTool()
                let parameters: [String: Any] = [
                    "reference_audio": audioPath,
                    "text": scriptText
                ]

                let context = ToolContext(workingDirectory: FileManager.default.currentDirectoryPath,
                                         settings: AppSettings.shared)
                let result = try await tool.execute(parameters: parameters, context: context)

                await MainActor.run {
                    isGenerating = false

                    if result.success {
                        if let path = result.metadata["output_path"] as? String {
                            generatedAudioPath = path
                        }
                    } else {
                        errorMessage = result.error ?? "Unknown error"
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Voice cloning failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func playAudio(_ path: String, isReference: Bool) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.play()

            if isReference {
                isPlayingReference = true
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    isPlayingReference = false
                }
            } else {
                isPlayingGenerated = true
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    isPlayingGenerated = false
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func saveAudioAs(_ sourcePath: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.wav]
        savePanel.nameFieldStringValue = "cloned_voice.wav"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.copyItem(atPath: sourcePath, toPath: url.path)
            }
        }
    }

    private func showSaveVoiceDialog() {
        guard let path = selectedAudioPath else { return }

        let alert = NSAlert()
        alert.messageText = "Save Voice to Library"
        alert.informativeText = "Enter a name for this voice:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        alert.accessoryView = textField

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.isEmpty ? "Unnamed Voice" : textField.stringValue
            let voice = SavedVoice(name: name, path: path)
            savedVoices.append(voice)
            saveSavedVoices()
        }
    }

    private func deleteSavedVoice(_ voice: SavedVoice) {
        savedVoices.removeAll { $0.id == voice.id }
        saveSavedVoices()
    }

    // MARK: - Persistence

    private func loadSavedVoices() {
        guard let data = savedVoicesJSON.data(using: .utf8),
              let voices = try? JSONDecoder().decode([SavedVoice].self, from: data) else {
            return
        }
        savedVoices = voices
    }

    private func saveSavedVoices() {
        guard let data = try? JSONEncoder().encode(savedVoices),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        savedVoicesJSON = json
    }
}

// MARK: - Voice Library Row

struct VoiceLibraryRow: View {
    let voice: VoiceCloningPanel.SavedVoice
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(URL(fileURLWithPath: voice.path).lastPathComponent)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onSelect) {
                Text("Use")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Preview

struct VoiceCloningPanel_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCloningPanel()
            .frame(width: 900, height: 600)
    }
}
