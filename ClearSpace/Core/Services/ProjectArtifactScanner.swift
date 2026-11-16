import Foundation

enum ProjectArtifactScanner {
    private static let minimumSize: Int64 = 1024 * 1024
    private static let skippedFolders: Set<String> = [".git", ".Trash", "Library", "Applications"]

    /// Finds dependency and build folders that their tools can recreate.
    static func scan(root: URL) async -> [ArtifactItem] {
        scanSync(root: root)
    }

    private static func scanSync(root: URL) -> [ArtifactItem] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [ArtifactItem] = []
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }

            let name = url.lastPathComponent
            if skippedFolders.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let parent = url.deletingLastPathComponent()
            guard let kind = ArtifactKind.match(folderName: name, parent: parent) else { continue }
            enumerator.skipDescendants()

            let size = SizeCalculator.allocatedSize(of: url)
            guard size >= minimumSize else { continue }
            results.append(ArtifactItem(url: url, kind: kind, project: parent.lastPathComponent, size: size))
        }

        results.sort { $0.size > $1.size }
        return results
    }
}
