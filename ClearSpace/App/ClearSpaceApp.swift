import SwiftUI

@main
struct ClearSpaceApp: App {
    @State private var appModel = AppModel()

    private static let isHostingUnitTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        Window("ClearSpace", id: "main") {
            if Self.isHostingUnitTests {
                // The unit test bundle runs inside the app. Stay inert so tests never
                // trigger scans, permission prompts or the onboarding flow.
                Text("Running unit tests")
                    .frame(minWidth: 320, minHeight: 200)
            } else {
                RootView()
                    .environment(appModel)
                    .frame(minWidth: 920, minHeight: 600)
            }
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
