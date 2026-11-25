import Foundation

enum SmartScanService {
    /// Items smaller than this are noise and are left out of the results.
    private static let minimumItemSize: Int64 = 5 * 1024 * 1024

    /// Measures one catalog target. Safe to call from any thread.
    /// `home` is injectable so tests can run against a temporary folder.
    static func resolve(
        _ target: CleanupTarget,
        reservedPaths: Set<String>,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [CleanupItem] {
        let fileManager = FileManager.default
        let url = home.appendingPathComponent(target.relativePath)

        guard fileManager.fileExists(atPath: url.path) else { return [] }

        switch target.mode {
        case .whole, .contents:
            let size = SizeCalculator.allocatedSize(of: url)
            guard size >= minimumItemSize else { return [] }
            return [makeItem(target: target, title: target.title, url: url, size: size)]

        case .eachChild:
            let children = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []

            var items: [CleanupItem] = []
            for child in children {
                if Task.isCancelled { break }
                let name = child.lastPathComponent
                if name == ".DS_Store" { continue }
                if reservedPaths.contains(child.standardizedFileURL.path) { continue }
                if target.excludedChildPrefixes.contains(where: { name.hasPrefix($0) }) { continue }

                let size = SizeCalculator.allocatedSize(of: child)
                guard size >= minimumItemSize else { continue }

                let title = target.category == .appCaches ? name : "\(target.title): \(name)"
                items.append(makeItem(target: target, title: title, url: child, size: size, contentsOnly: false))
            }
            return items
        }
    }

    /// Absolute paths of every single-item target, so `eachChild` scans do not list them twice.
    static func reservedPaths(
        for targets: [CleanupTarget] = CleanupCatalog.targets,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Set<String> {
        var paths = Set<String>()
        for target in targets {
            if case .eachChild = target.mode { continue }
            paths.insert(home.appendingPathComponent(target.relativePath).standardizedFileURL.path)
        }
        return paths
    }

    private static func makeItem(
        target: CleanupTarget,
        title: String,
        url: URL,
        size: Int64,
        contentsOnly: Bool? = nil
    ) -> CleanupItem {
        let keepFolder: Bool
        if let contentsOnly {
            keepFolder = contentsOnly
        } else if case .contents = target.mode {
            keepFolder = true
        } else {
            keepFolder = false
        }

        return CleanupItem(
            id: url.standardizedFileURL.path,
            title: title,
            explanation: target.explanation,
            url: url,
            category: target.category,
            safety: target.safety,
            size: size,
            contentsOnly: keepFolder,
            forcePermanent: target.forcePermanent,
            hint: target.hint
        )
    }
}
