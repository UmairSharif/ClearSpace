import Foundation

enum SizeCalculator {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]
    private static let keySet = Set(keys)

    /// Space a file or folder actually occupies on disk. Symbolic links are not followed:
    /// a link counts as the link itself, because removing it frees only the link.
    static func allocatedSize(of url: URL) -> Int64 {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return 0 }

        switch info.st_mode & S_IFMT {
        case S_IFLNK:
            return Int64(info.st_blocks) * 512
        case S_IFDIR:
            break
        default:
            return fileSize(url)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        while let next = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            total += fileSize(next)
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keySet), values.isRegularFile == true else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
