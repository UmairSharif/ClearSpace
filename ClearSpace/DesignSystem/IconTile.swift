import SwiftUI

/// A rounded, tinted symbol in the style of System Settings rows.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}
