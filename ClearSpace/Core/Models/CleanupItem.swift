import Foundation

/// A concrete, measured thing on disk that Smart Clean can offer to remove.
struct CleanupItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let url: URL
    let category: CleanupCategory
    let safety: SafetyLevel
    let size: Int64
    /// Remove the folder's contents but keep the folder itself.
    let contentsOnly: Bool
    /// Always delete permanently (used for items already in the Trash).
    let forcePermanent: Bool
    /// Instruction shown for `manual` items.
    let hint: String?

    var isSelectable: Bool { safety != .manual }
    var displayPath: String { url.path.abbreviatingHome }

    var deletionEntry: DeletionEntry {
        DeletionEntry(
            id: id,
            url: url,
            title: title,
            size: size,
            safety: safety,
            contentsOnly: contentsOnly,
            forcePermanent: forcePermanent
        )
    }
}
