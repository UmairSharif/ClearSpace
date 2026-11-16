import Foundation

/// Last line of defence before anything is removed. Even if a scan produced a bad
/// path, these locations are never deleted.
enum SafetyGuard {
    private static let protectedRelativePaths: Set<String> = [
        "Applications",
        "Desktop",
        "Documents",
        "Downloads",
        "Movies",
        "Music",
        "Pictures",
        "Public",
        "Library",
        "Library/Application Support",
        "Library/Caches",
        "Library/Containers",
        "Library/Developer",
        "Library/Group Containers",
        "Library/Keychains",
        "Library/Logs",
        "Library/Mail",
        "Library/Mobile Documents",
        "Library/Preferences",
        ".Trash",
        ".ssh"
    ]

    static func isDeletable(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

        if path.hasPrefix(home + "/") {
            let relative = String(path.dropFirst(home.count + 1))
            return !relative.isEmpty && !protectedRelativePaths.contains(relative)
        }

        // External volumes: allow anything below the volume root, never the root itself.
        if path.hasPrefix("/Volumes/") {
            return path.split(separator: "/").count >= 3
        }

        return false
    }
}
