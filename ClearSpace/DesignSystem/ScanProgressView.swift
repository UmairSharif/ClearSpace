import SwiftUI

/// Centered placeholder shown while a scan is running.
struct ScanProgressView: View {
    let title: String
    let message: String
    var progress: Double? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            if let progress {
                ProgressView(value: progress)
                    .frame(width: 220)
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: Theme.Spacing.xSmall) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onCancel {
                Button("Stop", action: onCancel)
            }
        }
        .padding(Theme.Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
