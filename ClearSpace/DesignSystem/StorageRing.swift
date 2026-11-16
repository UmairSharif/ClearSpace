import SwiftUI

/// Circular gauge showing how full the disk is.
struct StorageRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 14

    private var tint: Color {
        switch fraction {
        case ..<0.75: .accentColor
        case ..<0.9: .orange
        default: .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(min(fraction, 1), 0.001))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: fraction)

            VStack(spacing: 0) {
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk usage")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}
