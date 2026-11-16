import SwiftUI
import Observation

/// Sidebar selection plus one `Router` per section, so every section keeps its own stack.
@MainActor
@Observable
final class NavigationModel {
    var selection: SidebarSection? = .dashboard

    private let routers: [SidebarSection: Router]

    init() {
        var routers: [SidebarSection: Router] = [:]
        for section in SidebarSection.allCases {
            routers[section] = Router()
        }
        self.routers = routers
    }

    func router(for section: SidebarSection) -> Router {
        routers[section] ?? Router()
    }

    /// Switches section and optionally deep links into it.
    func open(_ section: SidebarSection, routes: [Route] = []) {
        selection = section
        router(for: section).setPath(routes)
    }
}
