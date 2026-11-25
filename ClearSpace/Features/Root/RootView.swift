import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        @Bindable var appModel = appModel

        Group {
            if hasCompletedOnboarding {
                MainSplitView()
            } else {
                OnboardingView {
                    withAnimation { hasCompletedOnboarding = true }
                }
            }
        }
        .sheet(item: $appModel.pendingDeletion) { request in
            DeleteConfirmationSheet(request: request)
        }
        .sheet(item: $appModel.report) { report in
            CleanupReportSheet(report: report)
        }
        .task {
            appModel.refreshDiskUsage()
            appModel.refreshPermissions()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appModel.refreshDiskUsage()
            appModel.refreshPermissions()
        }
    }
}

struct MainSplitView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var navigation = appModel.navigation
        let section = navigation.selection ?? .dashboard

        NavigationSplitView {
            SidebarView(selection: $navigation.selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            SectionHost(section: section, router: appModel.navigation.router(for: section))
                .id(section)
        }
    }
}

/// Hosts one section inside its own `NavigationStack`, driven by that section's router.
struct SectionHost: View {
    let section: SidebarSection
    @Bindable var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .category(let category):
                        CategoryDetailView(category: category)
                    }
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .smartClean:
            SmartCleanView()
        case .largeFiles:
            LargeFilesView()
        case .projects:
            ProjectArtifactsView()
        case .malware:
            ThreatScanView()
        }
    }
}
