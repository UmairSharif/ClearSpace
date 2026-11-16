import SwiftUI

struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(level.tint)
            .background(level.tint.opacity(0.14), in: Capsule())
            .help(level.explanation)
            .accessibilityLabel("Safety: \(level.title)")
    }
}
