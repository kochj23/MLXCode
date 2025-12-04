//
//  ThinkingIndicatorView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Animated thinking indicator shown when LLM is processing
struct ThinkingIndicatorView: View {
    /// Animation state for pulsing dots
    @State private var animatingDot1 = false
    @State private var animatingDot2 = false
    @State private var animatingDot3 = false

    /// Whether to show the thinking message
    let showMessage: Bool

    /// Custom message to display
    let message: String

    init(showMessage: Bool = true, message: String = "Thinking") {
        self.showMessage = showMessage
        self.message = message
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated dots
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot1 ? 1.2 : 0.8)
                    .opacity(animatingDot1 ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true),
                        value: animatingDot1
                    )

                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot2 ? 1.2 : 0.8)
                    .opacity(animatingDot2 ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(0.2),
                        value: animatingDot2
                    )

                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot3 ? 1.2 : 0.8)
                    .opacity(animatingDot3 ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(0.4),
                        value: animatingDot3
                    )
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            if showMessage {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            animatingDot1 = true
            animatingDot2 = true
            animatingDot3 = true
        }
    }
}

/// Full-screen thinking overlay for initial processing
struct ThinkingOverlayView: View {
    /// Message to display
    let message: String

    /// Animation state
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Thinking card
            VStack(spacing: 20) {
                // Animated brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )

                // Message
                Text(message)
                    .font(.title2)
                    .fontWeight(.medium)

                // Animated dots
                ThinkingIndicatorView(showMessage: false, message: "")

                // Subtext
                Text("This may take a moment...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .onAppear {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Preview

struct ThinkingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // With message
            ThinkingIndicatorView()

            // Without message
            ThinkingIndicatorView(showMessage: false, message: "")

            // Custom message
            ThinkingIndicatorView(message: "Processing your request")

            // Overlay
            ThinkingOverlayView(message: "Preparing response...")
        }
        .frame(width: 400, height: 500)
        .padding()
    }
}
