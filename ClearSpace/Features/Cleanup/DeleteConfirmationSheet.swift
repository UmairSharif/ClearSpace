import SwiftUI

/// The only place deletions are started. Lists exactly what will be removed and
/// lets the user choose between the Trash and permanent deletion.
struct DeleteConfirmationSheet: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(SettingsKey.deletionMode) private var modeRawValue = DeletionMode.trash.rawValue
    let request: DeletionRequest

    private var mode: DeletionMode {
        DeletionMode(rawValue: modeRawValue) ?? .trash
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            header

            if request.needsReview {
                notice(
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange,
                    text: "Some selected items are marked Review. They may not be recreated automatically."
                )
            }

            entryList

            VStack(alignment: .leading, spacing: 6) {
                Picker("When cleaning", selection: $modeRawValue) {
                    ForEach(DeletionMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(appModel.isDeleting)

                Text(mode.footnote)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if request.hasForcedPermanent {
                    Text("Items already in the Trash are always deleted permanently.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            buttons
        }
        .padding(Theme.Spacing.xLarge)
        .frame(width: 540)
        .interactiveDismissDisabled(appModel.isDeleting)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.medium) {
            IconTile(symbol: "trash.fill", tint: .red, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                    .font(.title2.weight(.semibold))
                Text("\(Pluralize.items(request.entries.count)), \(request.totalSize.formattedBytes)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var entryList: some View {
        List(request.entries) { entry in
            HStack(spacing: Theme.Spacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(entry.displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: Theme.Spacing.small)
                if entry.safety == .review {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("Marked Review")
                        .accessibilityLabel("Marked Review")
                }
                Text(entry.size.formattedBytes)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .listStyle(.bordered)
        .alternatingRowBackgrounds()
        .frame(height: 220)
    }

    private var buttons: some View {
        HStack {
            if appModel.isDeleting {
                ProgressView()
                    .controlSize(.small)
                Text("Cleaning…")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                appModel.pendingDeletion = nil
            }
            .keyboardShortcut(.cancelAction)
            .disabled(appModel.isDeleting)

            Button(mode.title, role: .destructive) {
                Task { await appModel.performDeletion(request, mode: mode) }
            }
            .disabled(appModel.isDeleting)
        }
        .controlSize(.large)
    }

    private func notice(symbol: String, tint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.icon, style: .continuous))
    }
}
