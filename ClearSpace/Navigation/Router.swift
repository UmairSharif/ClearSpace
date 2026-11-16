import SwiftUI
import Observation

/// Owns the navigation path of a single `NavigationStack`.
@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    /// Deep link: replace the whole path in one step.
    func setPath(_ routes: [Route]) {
        path = NavigationPath(routes)
    }
}
