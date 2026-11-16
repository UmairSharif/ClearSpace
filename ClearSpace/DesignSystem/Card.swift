import SwiftUI

/// Grouped surface used for dashboard panels. Follows the system's control background
/// so it adapts to light, dark and increased contrast automatically.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.large) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
