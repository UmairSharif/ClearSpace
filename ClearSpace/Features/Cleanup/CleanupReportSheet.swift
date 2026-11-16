import SwiftUI

/// Summary shown after a cleanup, including anything that could not be removed.
struct CleanupReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let report: DeletionReport

    private var succeeded: Bool { report.failures.isEmpty }

    private var headline: String {
        switch report.mode {
        case .trash: "\(report.freedBytes.formattedBytes) moved to the Trash"
        case .permanent: "\(report.freedBytes.formattedBytes) reclaimed"
        }
    }

    private var detail: String {
        let done = "\(report.deletedIDs.count) of \(Pluralize.items(report.requestedCount)) cleaned."
        switch report.mode {
        case .trash: return done + " Empty the Trash to reclaim the space."
        case .permanent: return done
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(succeeded ? Color.green : Color.orange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xSmall) {
                Text(headline)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !report.failures.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Could not remove \(Pluralize.items(report.failures.count))")
                        .font(.headline)

                    List(report.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(failure.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .listStyle(.bordered)
                    .frame(height: 150)

                    Text("Files in use, or protected by macOS, are skipped. Quit the app that owns them or grant Full Disk Access and try again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                if report.mode == .trash && report.freedBytes > 0 {
                    Button("Show Trash") {
                        SystemActions.openTrash()
                    }
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(Theme.Spacing.xLarge)
        .frame(width: 460)
    }
}
