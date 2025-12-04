//
//  GaugeView.swift
//  MLX Code
//
//  Created on 2025-11-19.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// Circular gauge/speedometer view for metrics
struct GaugeView: View {
    /// Current value
    let value: Double

    /// Maximum value
    let maxValue: Double

    /// Label text
    let label: String

    /// Value text (displayed in center)
    let valueText: String

    /// Gauge color
    let color: Color

    /// Size of the gauge
    let size: CGFloat

    /// Progress (0.0 to 1.0)
    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    /// Color based on progress
    private var progressColor: Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, color: Color? = nil, size: CGFloat = 60) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.color = color ?? .blue
        self.size = size
    }

    var body: some View {
        VStack(spacing: 4) {
            // Circular gauge
            ZStack {
                // Background arc
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.1)
                    .frame(width: size, height: size)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: size * 0.1,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // Center value
                VStack(spacing: 0) {
                    Text(valueText)
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(width: size * 0.7)
            }

            // Label
            Text(label)
                .font(.system(size: size * 0.15, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

/// Speedometer-style gauge with needle indicator
struct SpeedometerGaugeView: View {
    /// Current value
    let value: Double

    /// Maximum value
    let maxValue: Double

    /// Label text
    let label: String

    /// Value text
    let valueText: String

    /// Size
    let size: CGFloat

    /// Progress (0.0 to 1.0)
    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    /// Needle angle (-90° to 90°, total 180° arc)
    private var needleAngle: Double {
        -90 + (progress * 180)
    }

    /// Color based on value
    private var gaugeColor: Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, size: CGFloat = 80) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.size = size
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background arc (180° semicircle)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.08)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))

                // Colored segments
                ForEach(0..<3) { segment in
                    Circle()
                        .trim(from: Double(segment) * 0.5 / 3.0, to: Double(segment + 1) * 0.5 / 3.0)
                        .stroke(
                            segment == 0 ? Color.green : (segment == 1 ? Color.orange : Color.red),
                            lineWidth: size * 0.08
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(90))
                        .opacity(0.3)
                }

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress * 0.5)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(
                            lineWidth: size * 0.08,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)

                // Needle
                Rectangle()
                    .fill(gaugeColor)
                    .frame(width: 2, height: size * 0.4)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(needleAngle))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: needleAngle)

                // Center circle
                Circle()
                    .fill(gaugeColor)
                    .frame(width: size * 0.1, height: size * 0.1)

                // Value display (below gauge)
                VStack {
                    Spacer()
                    Text(valueText)
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundColor(gaugeColor)
                }
                .frame(height: size)
                .offset(y: size * 0.15)
            }
            .frame(height: size * 0.7)

            // Label
            Text(label)
                .font(.system(size: size * 0.13, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

/// Compact horizontal bar gauge
struct BarGaugeView: View {
    /// Current value
    let value: Double

    /// Maximum value
    let maxValue: Double

    /// Label
    let label: String

    /// Value text
    let valueText: String

    /// Width
    let width: CGFloat

    /// Progress
    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    /// Color
    private var color: Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, width: CGFloat = 120) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(valueText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .frame(width: width)
    }
}

// MARK: - Preview

struct GaugeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            HStack(spacing: 20) {
                // Circular gauges
                GaugeView(
                    value: 1500,
                    maxValue: 8192,
                    label: "Tokens",
                    valueText: "1.5K",
                    size: 60
                )

                GaugeView(
                    value: 125,
                    maxValue: 200,
                    label: "Speed",
                    valueText: "125",
                    color: .green,
                    size: 60
                )
            }

            HStack(spacing: 20) {
                // Speedometer gauges
                SpeedometerGaugeView(
                    value: 2500,
                    maxValue: 8192,
                    label: "Tokens",
                    valueText: "2.5K",
                    size: 80
                )

                SpeedometerGaugeView(
                    value: 150,
                    maxValue: 200,
                    label: "t/s",
                    valueText: "150",
                    size: 80
                )
            }

            // Bar gauges
            VStack(spacing: 12) {
                BarGaugeView(
                    value: 3500,
                    maxValue: 8192,
                    label: "Tokens",
                    valueText: "3,500 / 8,192"
                )

                BarGaugeView(
                    value: 145,
                    maxValue: 200,
                    label: "Speed (t/s)",
                    valueText: "145 t/s"
                )
            }
        }
        .padding()
        .frame(width: 500, height: 600)
    }
}
