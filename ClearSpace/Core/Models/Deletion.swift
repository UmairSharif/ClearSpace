import Foundation

enum DeletionMode: String, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    /// The action every confirmation starts with. Permanent deletion is always a
    /// choice made for one cleanup, never a remembered default.
    static let initialChoice: DeletionMode = .trash

    var title: String {
        switch self {
        case .trash: "Move to Trash"
        case .permanent: "Delete Permanently"
        }
    }

    var footnote: String {
        switch self {
        case .trash: "You can restore items from the Trash. Space is reclaimed once you empty it."
        case .permanent: "Space is reclaimed immediately. This cannot be undone."
        }
    }
}

/// One thing the user asked to remove.
struct DeletionEntry: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let title: String
    let size: Int64
    let safety: SafetyLevel
    let contentsOnly: Bool
    let forcePermanent: Bool

    var displayPath: String { url.path.abbreviatingHome }
}

/// A set of entries waiting for the user's confirmation.
struct DeletionRequest: Identifiable {
    let id = UUID()
    let title: String
    let entries: [DeletionEntry]
    let onComplete: @MainActor (DeletionReport) -> Void

    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }
    var needsReview: Bool { entries.contains { $0.safety == .review } }
    var hasForcedPermanent: Bool { entries.contains { $0.forcePermanent } }
}

struct DeletionFailure: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let message: String
}

struct DeletionReport: Identifiable, Sendable {
    let id = UUID()
    let mode: DeletionMode
    let freedBytes: Int64
    /// Entries that were removed completely.
    let deletedIDs: Set<String>
    let failures: [DeletionFailure]
    let requestedCount: Int
}
