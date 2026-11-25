import Foundation

/// Last line of defence before anything is removed. Even if a scan produced a bad
/// path, these locations are never deleted.
enum SafetyGuard {
    private static let protectedRelativePaths: Set<String> = Set([
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
    ].map(fold))

    /// Whether `url` may be moved to the Trash or removed.
    ///
    /// Paths are compared case-insensitively, because the default APFS volume is
    /// case-insensitive and `~/documents` is the same folder as `~/Documents`.
    /// Symbolic links in the parent folders are resolved, so `~/link/Documents`
    /// cannot reach `~/Documents` through a link to the home folder. The last
    /// component is not resolved: removing a link removes only the link.
    static func isDeletable(
        _ url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let path = fold(normalizedPath(url))
        let homePath = fold(resolvingExistingAncestor(home.standardizedFileURL).path)

        if path.hasPrefix(homePath + "/") {
            let relative = String(path.dropFirst(homePath.count + 1))
            return !relative.isEmpty && !protectedRelativePaths.contains(relative)
        }

        // External volumes: allow anything below the volume root, never the root itself.
        if path.hasPrefix("/volumes/") {
            return path.split(separator: "/").count >= 3
        }

        return false
    }

    /// Whether the item at `url` is itself a symbolic link. Does not follow it.
    static func isSymbolicLink(_ url: URL) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }

    /// Standardized path with every symbolic link above the last component resolved.
    static func normalizedPath(_ url: URL) -> String {
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent
        guard !name.isEmpty, standardized.path != "/" else { return standardized.path }

        return resolvingExistingAncestor(standardized.deletingLastPathComponent())
            .appendingPathComponent(name).path
    }

    /// Resolves links in the deepest folder that exists, then appends the missing rest.
    /// `resolvingSymlinksInPath()` alone leaves a path untouched when it does not exist,
    /// which would compare `/var/...` with the resolved home and skip the checks.
    private static func resolvingExistingAncestor(_ url: URL) -> URL {
        var existing = url
        var missing: [String] = []
        while !FileManager.default.fileExists(atPath: existing.path), existing.path != "/" {
            missing.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
        }
        var resolved = existing.resolvingSymlinksInPath()
        for component in missing {
            resolved.appendPathComponent(component)
        }
        return resolved
    }

    private static func fold(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.lowercased()
    }
}
