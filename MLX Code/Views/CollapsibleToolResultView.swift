//
//  CollapsibleToolResultView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// View for displaying collapsible tool execution results
struct CollapsibleToolResultView: View {
    /// The message containing tool results
    let message: Message

    /// Font size for content
    let fontSize: CGFloat

    /// Whether to enable syntax highlighting
    let enableSyntaxHighlighting: Bool

    /// Whether the disclosure group is expanded
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                MarkdownTextView(
                    markdown: message.content,
                    fontSize: fontSize,
                    enableSyntaxHighlighting: enableSyntaxHighlighting
                )
                .padding(.top, 8)
            },
            label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.orange)
                    Text("Tool Execution Results")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(isExpanded ? "Hide" : "Show")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        )
        .onAppear {
            // Check if metadata says it should be collapsed
            isExpanded = message.metadata?["collapsed"] != "true"
        }
    }
}

/// Preview provider for CollapsibleToolResultView
#Preview {
    CollapsibleToolResultView(
        message: Message(
            role: .system,
            content: """
            # Tool Execution Results

            ## Tool Call 1
            ```json
            {
              "success": true,
              "output": "File read successfully"
            }
            ```
            """,
            metadata: ["collapsible": "true", "collapsed": "true"]
        ),
        fontSize: 14,
        enableSyntaxHighlighting: true
    )
    .padding()
    .frame(width: 600)
}
