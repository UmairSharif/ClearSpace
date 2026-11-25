import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Default action", value: DeletionMode.initialChoice.title)
            } header: {
                Text("Cleaning")
            } footer: {
                Text("You always confirm before anything is removed. Each cleanup starts with Move to Trash, and you can choose Delete Permanently in the confirmation for that cleanup only.")
            }

            Section("Permissions") {
                LabeledContent("Full Disk Access") {
                    HStack(spacing: Theme.Spacing.small) {
                        Label(
                            appModel.hasFullDiskAccess ? "Allowed" : "Not allowed",
                            systemImage: appModel.hasFullDiskAccess ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        .foregroundStyle(appModel.hasFullDiskAccess ? Color.green : Color.secondary)

                        Button("Open System Settings") {
                            PermissionService.openFullDiskAccessSettings()
                        }
                    }
                }

                Button("Show Welcome Screen Again") {
                    hasCompletedOnboarding = false
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            appModel.refreshPermissions()
        }
    }
}
