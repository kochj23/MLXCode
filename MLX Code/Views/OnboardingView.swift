//
//  OnboardingView.swift
//  MLX Code
//
//  First-time user onboarding flow
//  Created on 2025-12-09
//

import SwiftUI

/// Onboarding flow for new users
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var hasCompletedOnboarding = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to MLX Code",
            description: "Your local, private AI coding assistant powered by Apple's MLX framework.",
            icon: "brain",
            features: [
                "100% local - no data sent to cloud",
                "Zero cost - no API fees",
                "Optimized for Apple Silicon",
                "Full Xcode integration"
            ]
        ),
        OnboardingPage(
            title: "Download Models",
            description: "MLX Code needs at least one language model to work.",
            icon: "arrow.down.circle",
            features: [
                "Phi-3.5 Mini (4GB) - Fast, great for coding",
                "Llama 3.2 3B (7GB) - Better quality",
                "Qwen 2.5 7B (14GB) - Best for code",
                "Use Settings → Models → Scan Disk to find models"
            ]
        ),
        OnboardingPage(
            title: "Powerful Features",
            description: "MLX Code is packed with productivity tools.",
            icon: "sparkles",
            features: [
                "⌘K Command Palette - Quick access to everything",
                "AI Git integration - Auto-generate commits",
                "Code actions - Explain, test, refactor",
                "Project indexing - Semantic code search",
                "Performance metrics - Track generation speed"
            ]
        ),
        OnboardingPage(
            title: "Keyboard Shortcuts",
            description: "Work faster with keyboard shortcuts.",
            icon: "keyboard",
            features: [
                "⌘K - Command palette",
                "⌘N - New conversation",
                "⌘L - Toggle logs",
                "⌘P - Performance dashboard",
                "⌘, - Settings"
            ]
        ),
        OnboardingPage(
            title: "You're All Set!",
            description: "Ready to start coding with AI assistance.",
            icon: "checkmark.circle",
            features: [
                "1. Load a model from the dropdown",
                "2. Type your question or task",
                "3. Get instant AI-powered help",
                "4. Use ⌘K to discover more features"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding()

            // Content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                }
            }
            .padding()
        }
        .frame(width: 700, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding(.top, 40)

            // Title
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(page.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.body)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 20)

            Spacer()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}

/// Onboarding page data
struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let features: [String]
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
