//
//  InteractivePromptView.swift
//  MLX Code
//
//  Interactive prompts for agent clarification
//  Created on 2025-12-09
//

import SwiftUI

/// Shows when agent needs clarification from user
struct InteractivePromptView: View {
    let question: String
    let options: [String]?
    let allowCustomInput: Bool
    let onResponse: (String) -> Void

    @State private var selectedOption: String?
    @State private var customInput: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Question
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text("Clarification Needed")
                        .font(.headline)
                }

                Text(question)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Options
            if let options = options {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select an option:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedOption = option
                        }) {
                            HStack {
                                Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedOption == option ? .blue : .secondary)

                                Text(option)
                                    .font(.body)

                                Spacer()
                            }
                            .padding()
                            .background(selectedOption == option ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom input
            if allowCustomInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or provide custom response:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Your answer...", text: $customInput)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Submit") {
                    let response = !customInput.isEmpty ? customInput : (selectedOption ?? "")
                    onResponse(response)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedOption == nil && customInput.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

// MARK: - Interactive Mode Manager

/// Manages interactive clarification prompts
@MainActor
class InteractiveModeManager: ObservableObject {
    static let shared = InteractiveModeManager()

    @Published var pendingQuestion: InteractiveQuestion?

    private init() {}

    /// Asks user a question and waits for response
    /// - Parameters:
    ///   - question: Question text
    ///   - options: Optional predefined choices
    ///   - allowCustom: Allow custom text input
    /// - Returns: User's response
    func ask(
        question: String,
        options: [String]? = nil,
        allowCustom: Bool = true
    ) async -> String {
        return await withCheckedContinuation { continuation in
            self.pendingQuestion = InteractiveQuestion(
                question: question,
                options: options,
                allowCustom: allowCustom,
                continuation: continuation
            )
        }
    }

    /// Submits response to pending question
    func respond(_ answer: String) {
        guard let question = pendingQuestion else { return }
        question.continuation.resume(returning: answer)
        pendingQuestion = nil
    }

    /// Cancels pending question
    func cancel() {
        guard let question = pendingQuestion else { return }
        question.continuation.resume(returning: "")
        pendingQuestion = nil
    }
}

/// Pending interactive question
struct InteractiveQuestion {
    let question: String
    let options: [String]?
    let allowCustom: Bool
    let continuation: CheckedContinuation<String, Never>
}

// MARK: - Preview

struct InteractivePromptView_Previews: PreviewProvider {
    static var previews: some View {
        InteractivePromptView(
            question: "Which approach should I use for the authentication system?",
            options: ["OAuth 2.0", "JWT Tokens", "Session-based"],
            allowCustomInput: true,
            onResponse: { response in
                print("User selected: \(response)")
            }
        )
    }
}
