import Foundation

struct DiskUsage: Equatable, Sendable {
    var volumeName: String
    var total: Int64
    var available: Int64

    var used: Int64 { max(total - available, 0) }

    var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    static let empty = DiskUsage(volumeName: "Macintosh HD", total: 0, available: 0)
}
