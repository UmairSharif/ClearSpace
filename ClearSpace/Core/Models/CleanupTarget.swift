import Foundation

/// A known location that may hold reclaimable data. Resolved into `CleanupItem`s by a scan.
struct CleanupTarget: Sendable {
    enum Mode: Sendable {
        /// Offer the whole folder (or file) as a single item.
        case whole
        /// Offer the folder's contents as a single item and keep the folder.
        case contents
        /// Offer every child of the folder as its own item.
        case eachChild
    }

    let title: String
    /// Path relative to the user's home folder.
    let relativePath: String
    let category: CleanupCategory
    let safety: SafetyLevel
    let explanation: String
    var mode: Mode = .whole
    var forcePermanent = false
    var hint: String? = nil
    /// Child names starting with any of these prefixes are skipped in `eachChild` mode.
    var excludedChildPrefixes: [String] = []
}
