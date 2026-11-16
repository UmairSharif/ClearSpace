import Foundation

extension Int64 {
    /// Human readable size using the same units Finder shows.
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension String {
    /// Replaces the home folder prefix with `~`.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}

enum Pluralize {
    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }
}

enum SettingsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let deletionMode = "deletionMode"
    static let projectsRootPath = "projectsRootPath"
}
