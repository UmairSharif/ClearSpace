import Foundation

enum LargeFileScanner {
    private static let maximumResults = 500

    /// Finds the largest files below `root`. Runs off the main thread and honours cancellation.
    static func scan(root: URL, minimumSize: Int64, includeLibrary: Bool) async -> [FileEntry] {
        scanSync(root: root, minimumSize: minimumSize, includeLibrary: includeLibrary)
    }

    private static func scanSync(root: URL, minimumSize: Int64, includeLibrary: Bool) -> [FileEntry] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .contentModificationDateKey
        ]
        let keySet = Set(keys)
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let libraryPath = home + "/Library"
        let trashPath = home + "/.Trash"

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [FileEntry] = []
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }
            guard let values = try? url.resourceValues(forKeys: keySet) else { continue }

            if values.isDirectory == true {
                let path = url.standardizedFileURL.path
                if path == trashPath || (!includeLibrary && path == libraryPath) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= minimumSize else { continue }

            results.append(FileEntry(
                url: url,
                name: url.lastPathComponent,
                size: size,
                modified: values.contentModificationDate ?? .distantPast,
                location: url.deletingLastPathComponent().path.abbreviatingHome
            ))
        }

        results.sort { $0.size > $1.size }
        return Array(results.prefix(maximumResults))
    }
}
