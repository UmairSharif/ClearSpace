import Foundation

enum DeletionService {
    private static let maximumReportedFailures = 100

    /// Removes the entries off the main thread and reports what happened.
    static func perform(_ entries: [DeletionEntry], mode: DeletionMode) async -> DeletionReport {
        performSync(entries, mode: mode)
    }

    private static func performSync(_ entries: [DeletionEntry], mode: DeletionMode) -> DeletionReport {
        let fileManager = FileManager.default
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
                targets = (try? fileManager.contentsOfDirectory(
                    at: entry.url,
                    includingPropertiesForKeys: nil,
                    options: []
                )) ?? []
            } else {
                targets = [entry.url]
            }

            var failed = false
            for target in targets {
                guard SafetyGuard.isDeletable(target) else {
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
}
