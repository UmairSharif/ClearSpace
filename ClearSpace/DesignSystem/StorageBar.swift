import SwiftUI

/// Segmented bar: space in use, the part of it that can be reclaimed, and free space.
struct StorageBar: View {
    let usage: DiskUsage
    let reclaimable: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let total = max(Double(usage.total), 1)
                let reclaimWidth = width * min(Double(reclaimable) / total, 1)
                let usedWidth = max(width * usage.usedFraction - reclaimWidth, 0)

                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: usedWidth)
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: reclaimWidth)
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                }
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.5), value: reclaimable)
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            HStack(spacing: Theme.Spacing.large) {
                legend("In use", color: .accentColor, value: usage.used - min(reclaimable, usage.used))
                legend("Reclaimable", color: .orange, value: reclaimable)
                legend("Free", color: Color.primary.opacity(0.25), value: usage.available)
            }
        }
    }

    private func legend(_ title: String, color: Color, value: Int64) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value.formattedBytes)
                .monospacedDigit()
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}
