import SwiftUI

/// First-run screen. Explains each permission before macOS asks for it and makes
/// clear that nothing is removed without confirmation.
struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var folderAccess: FolderAccess = .notRequested
    let onFinish: () -> Void

    private enum FolderAccess {
        case notRequested
        case requesting
        case granted
        case denied
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xLarge) {
                header

                VStack(spacing: Theme.Spacing.medium) {
                    filesAndFoldersRow
                    fullDiskAccessRow
                }

                Label {
                    Text("ClearSpace only analyzes your disk. Nothing is deleted until you review the list and confirm, and nothing ever leaves your Mac.")
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onFinish) {
                    Text("Get Started")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(Theme.Spacing.xxLarge)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("Welcome to ClearSpace")
                .font(.largeTitle.weight(.bold))

            Text("See what is filling your Mac and reclaim the space safely.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var filesAndFoldersRow: some View {
        PermissionRow(
            symbol: "folder.fill",
            tint: .blue,
            title: "Files and Folders",
            message: "Lets ClearSpace measure Desktop, Documents and Downloads. macOS asks you to confirm each folder.",
            isGranted: folderAccess == .granted
        ) {
            switch folderAccess {
            case .granted:
                EmptyView()
            case .requesting:
                ProgressView()
                    .controlSize(.small)
            case .notRequested:
                Button("Allow…") { requestFolderAccess() }
            case .denied:
                Button("Try Again") { requestFolderAccess() }
            }
        }
    }

    private var fullDiskAccessRow: some View {
        PermissionRow(
            symbol: "internaldrive.fill",
            tint: .purple,
            title: "Full Disk Access",
            message: "Recommended. Needed to measure the Trash, app containers and some caches. Turn on ClearSpace in System Settings, then return here.",
            isGranted: appModel.hasFullDiskAccess
        ) {
            if !appModel.hasFullDiskAccess {
                Button("Open System Settings") {
                    PermissionService.openFullDiskAccessSettings()
                }
            }
        }
    }

    private func requestFolderAccess() {
        folderAccess = .requesting
        Task {
            let granted = await PermissionService.requestStandardFolderAccess()
            folderAccess = granted ? .granted : .denied
        }
    }
}

struct PermissionRow<Accessory: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let isGranted: Bool
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            IconTile(symbol: symbol, tint: tint, size: 36)

            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if isGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.medium)

            accessory()
        }
        .card()
    }
}
