import SwiftUI

/// Bottom bar summarising the current selection with the single destructive action.
struct SelectionBar: View {
    let count: Int
    let size: Int64
    var actionTitle = "Clean…"
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.large) {
            VStack(alignment: .leading, spacing: 2) {
                Text(count == 0 ? "Nothing selected" : "\(Pluralize.items(count)) selected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(size.formattedBytes)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()

            Button(action: action) {
                Label(actionTitle, systemImage: "trash")
                    .padding(.horizontal, Theme.Spacing.small)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(count == 0)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .padding(.horizontal, Theme.Spacing.xLarge)
        .padding(.vertical, Theme.Spacing.medium)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.default, value: size)
    }
}
