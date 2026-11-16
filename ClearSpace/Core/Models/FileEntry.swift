import Foundation

/// A single large file found by the Large Files scan.
struct FileEntry: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let size: Int64
    let modified: Date
    let location: String

    var id: String { url.path }

    var deletionEntry: DeletionEntry {
        DeletionEntry(
            id: id,
            url: url,
            title: name,
            size: size,
            safety: .review,
            contentsOnly: false,
            forcePermanent: false
        )
    }
}
