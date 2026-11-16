import Foundation

/// Top-level destinations shown in the sidebar. Each one owns its own navigation stack.
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case smartClean
    case largeFiles
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Overview"
        case .smartClean: "Smart Clean"
        case .largeFiles: "Large Files"
        case .projects: "Project Junk"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.50percent"
        case .smartClean: "sparkles"
        case .largeFiles: "doc.badge.ellipsis"
        case .projects: "hammer"
        }
    }
}

/// Typed routes pushed onto a section's navigation stack.
enum Route: Hashable {
    case category(CleanupCategory)
}
