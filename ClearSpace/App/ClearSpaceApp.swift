import SwiftUI

@main
struct ClearSpaceApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        Window("ClearSpace", id: "main") {
            RootView()
                .environment(appModel)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 700)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Run Smart Scan") {
                    appModel.navigation.open(.smartClean)
                    Task { await appModel.smartClean.scan() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Refresh Disk Usage") {
                    appModel.refreshDiskUsage()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appModel)
        }
    }
}
