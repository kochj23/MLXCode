//
//  MLXCodeWidget.swift
//  MLX Code Widget
//
//  Created on 2026-02-04.
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

/// Timeline entry for the MLX Code widget
struct MLXCodeWidgetEntry: TimelineEntry {
    let date: Date
    let data: MLXCodeWidgetData
}

// MARK: - Timeline Provider

/// Provides timeline data for the widget
struct MLXCodeWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> MLXCodeWidgetEntry {
        MLXCodeWidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MLXCodeWidgetEntry) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData() ?? .placeholder
        let entry = MLXCodeWidgetEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MLXCodeWidgetEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData() ?? .idle
        let currentDate = Date()

        // Create entry for current time
        let entry = MLXCodeWidgetEntry(date: currentDate, data: data)

        // Refresh every 5 minutes (widget will also refresh when app updates data)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

        completion(timeline)
    }
}

// MARK: - Small Widget View

struct MLXCodeWidgetSmallView: View {
    let entry: MLXCodeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                StatusBadge(status: entry.data.modelStatus)
            }

            Spacer()

            // Model name or status
            if let modelName = entry.data.modelName {
                Text(modelName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            } else {
                Text("No Model")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Token speed (if generating)
            if entry.data.isGenerating, let _ = entry.data.tokensPerSecond {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text(entry.data.formattedTokenSpeed)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
            } else if entry.data.modelStatus == .loaded {
                Text("Ready")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MLXCodeWidgetMediumView: View {
    let entry: MLXCodeWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Status and model info
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "brain")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("MLX Code")
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: entry.data.modelStatus)
                }

                // Model name
                if let modelName = entry.data.modelName {
                    Text(modelName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                } else {
                    Text("No model loaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Performance metrics
                HStack(spacing: 16) {
                    MetricView(
                        icon: "bolt.fill",
                        value: entry.data.formattedTokenSpeed,
                        label: "Speed"
                    )

                    MetricView(
                        icon: "memorychip",
                        value: entry.data.formattedMemoryUsage,
                        label: "Memory"
                    )
                }
            }

            // Right side: Quick actions
            VStack(spacing: 8) {
                ForEach([WidgetQuickCommand.newChat, .generateCode], id: \.self) { command in
                    Link(destination: command.deepLinkURL) {
                        QuickActionButton(command: command)
                    }
                }
            }
            .frame(width: 80)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget View

struct MLXCodeWidgetLargeView: View {
    let entry: MLXCodeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MLX Code")
                        .font(.headline)
                    Text("Local AI Assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(status: entry.data.modelStatus)
            }

            Divider()

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Model")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let modelName = entry.data.modelName {
                    Text(modelName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text("No model loaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Performance metrics row
            HStack(spacing: 20) {
                LargeMetricView(
                    icon: "bolt.fill",
                    value: entry.data.formattedTokenSpeed,
                    label: "Token Speed",
                    color: .blue
                )

                LargeMetricView(
                    icon: "memorychip",
                    value: entry.data.formattedMemoryUsage,
                    label: "Memory",
                    color: memoryColor
                )

                LargeMetricView(
                    icon: "number",
                    value: "\(entry.data.totalTokensGenerated)",
                    label: "Tokens",
                    color: .purple
                )
            }

            // Memory progress bar
            if entry.data.memoryUsageBytes != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Memory Usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(entry.data.memoryUsagePercent * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: entry.data.memoryUsagePercent)
                        .tint(memoryColor)
                }
            }

            Spacer()

            // Quick commands grid
            VStack(spacing: 8) {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(WidgetQuickCommand.allCases) { command in
                        Link(destination: command.deepLinkURL) {
                            QuickActionButton(command: command)
                        }
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var memoryColor: Color {
        let percent = entry.data.memoryUsagePercent
        if percent > 0.85 {
            return .red
        } else if percent > 0.70 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Helper Views

struct StatusBadge: View {
    let status: ModelStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImageName)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .loading: return .orange
        case .loaded: return .green
        case .generating: return .blue
        case .error: return .red
        }
    }
}

struct MetricView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LargeMetricView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let command: WidgetQuickCommand

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: command.systemImageName)
                .font(.body)
            Text(command.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Widget Configuration

struct MLXCodeWidget: Widget {
    let kind: String = "MLXCodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MLXCodeWidgetProvider()) { entry in
            MLXCodeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MLX Code")
        .description("Monitor your local AI assistant status, token speed, and memory usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View (Size Router)

struct MLXCodeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MLXCodeWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            MLXCodeWidgetSmallView(entry: entry)
        case .systemMedium:
            MLXCodeWidgetMediumView(entry: entry)
        case .systemLarge:
            MLXCodeWidgetLargeView(entry: entry)
        default:
            MLXCodeWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct MLXCodeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MLXCodeWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MLXCodeWidget()
} timeline: {
    MLXCodeWidgetEntry(date: .now, data: .placeholder)
    MLXCodeWidgetEntry(date: .now, data: .idle)
}

#Preview("Medium", as: .systemMedium) {
    MLXCodeWidget()
} timeline: {
    MLXCodeWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    MLXCodeWidget()
} timeline: {
    MLXCodeWidgetEntry(date: .now, data: .placeholder)
}
