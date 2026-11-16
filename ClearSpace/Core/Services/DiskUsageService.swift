import Foundation

enum DiskUsageService {
    /// Capacity of the volume that holds the user's home folder.
    static func current() -> DiskUsage {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? home.resourceValues(forKeys: keys) else { return .empty }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let important = values.volumeAvailableCapacityForImportantUsage ?? 0
        let basic = Int64(values.volumeAvailableCapacity ?? 0)

        return DiskUsage(
            volumeName: values.volumeName ?? "Macintosh HD",
            total: total,
            available: important > 0 ? important : basic
        )
    }
}
