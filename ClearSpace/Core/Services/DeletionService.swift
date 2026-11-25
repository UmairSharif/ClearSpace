import Foundation

enum DeletionService {
    private static let maximumReportedFailures = 100

    /// Removes the entries off the main thread and reports what happened.
    ///
    /// `home` is the folder `SafetyGuard` treats as the user's home, and `fileManager`
    /// does the listing, trashing and removing. Tests pass a temporary folder and a
    /// fake file manager so nothing touches the real home or Trash.
    static func perform(
        _ entries: [DeletionEntry],
        mode: DeletionMode,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) async -> DeletionReport {
        performSync(entries, mode: mode, home: home, fileManager: fileManager)
    }

    static func performSync(
        _ entries: [DeletionEntry],
        mode: DeletionMode,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> DeletionReport {
        var freed: Int64 = 0
        var deleted = Set<String>()
        var failures: [DeletionFailure] = []

        func record(_ path: String, _ message: String) {
            guard failures.count < maximumReportedFailures else { return }
            failures.append(DeletionFailure(path: path.abbreviatingHome, message: message))
        }

        for entry in entries {
            let effectiveMode: DeletionMode = entry.forcePermanent ? .permanent : mode

            let targets: [URL]
            if entry.contentsOnly {
                // Never empty a folder through a link: its children would resolve to
                // wherever the link points, which SafetyGuard cannot see from here.
                if SafetyGuard.isSymbolicLink(entry.url) {
                    record(entry.url.path, "This folder is a link and was skipped.")
                    continue
                }
                do {
                    targets = try fileManager.contentsOfDirectory(
                        at: entry.url,
                        includingPropertiesForKeys: nil,
                        options: []
                    )
                } catch {
                    // Usually missing Full Disk Access (for example the Trash). Nothing
                    // was removed, so this must not be reported as cleaned.
                    record(entry.url.path, unreadableFolderMessage(for: error))
                    continue
                }
            } else {
                targets = [entry.url]
            }

            var failed = false
            for target in targets {
                guard SafetyGuard.isDeletable(target, home: home) else {
                    failed = true
                    record(target.path, "This location is protected and was skipped.")
                    continue
                }
                do {
                    switch effectiveMode {
                    case .trash:
                        try fileManager.trashItem(at: target, resultingItemURL: nil)
                    case .permanent:
                        try fileManager.removeItem(at: target)
                    }
                } catch {
                    failed = true
                    record(target.path, error.localizedDescription)
                }
            }

            if failed {
                let remaining = SizeCalculator.allocatedSize(of: entry.url)
                freed += max(entry.size - remaining, 0)
            } else {
                freed += entry.size
                deleted.insert(entry.id)
            }
        }

        return DeletionReport(
            mode: mode,
            freedBytes: freed,
            deletedIDs: deleted,
            failures: failures,
            requestedCount: entries.count
        )
    }

    private static func unreadableFolderMessage(for error: Error) -> String {
        let nsError = error as NSError
        let permissionCodes = [NSFileReadNoPermissionError, Int(EPERM), Int(EACCES)]
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        if permissionCodes.contains(nsError.code) || permissionCodes.contains(underlying?.code ?? 0) {
            return "ClearSpace could not open this folder, so nothing was removed. Allow Full Disk Access in System Settings and try again."
        }
        return "ClearSpace could not open this folder, so nothing was removed. \(error.localizedDescription)"
    }
}
