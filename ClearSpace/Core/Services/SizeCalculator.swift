import Foundation

enum SizeCalculator {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]
    private static let keySet = Set(keys)

    /// Space a file or folder actually occupies on disk. Symbolic links are not followed.
    static func allocatedSize(of url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        guard isDirectory.boolValue else { return fileSize(url) }

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
