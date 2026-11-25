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
    /// No longer used. Earlier builds remembered the delete mode here, which could make
    /// Delete Permanently the default. `AppModel` removes the stale value at launch.
    static let legacyDeletionMode = "deletionMode"
    static let projectsRootPath = "projectsRootPath"
}
