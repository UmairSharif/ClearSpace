import Foundation

/// A FileManager that only ever acts inside one sandbox folder. "Trash" moves items into
/// `sandbox/.Trash` instead of the real Trash, and any attempt to touch a path outside the
/// sandbox stops the test run before anything happens.
final class RecordingFileManager: FileManager {
    let sandbox: URL
    /// Canonical paths (see `TemporaryDirectory.canonical`) of what was trashed or removed.
    private(set) var trashed: [String] = []
    private(set) var removed: [String] = []
    /// Canonical paths that fail with a permission error when trashed or removed.
    var failingPaths: Set<String> = []

    init(sandbox: URL) {
        self.sandbox = sandbox
        super.init()
    }

    var fakeTrash: URL { sandbox.appendingPathComponent(".Trash", isDirectory: true) }

    private func requireInsideSandbox(_ url: URL) {
        let path = TemporaryDirectory.canonical(url)
        precondition(
            path.hasPrefix(TemporaryDirectory.canonical(sandbox) + "/"),
            "Test tried to delete outside its temporary folder: \(path)"
        )
    }

    private func failIfAsked(_ url: URL) throws {
        if failingPaths.contains(TemporaryDirectory.canonical(url)) {
            throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    override func trashItem(
        at url: URL,
        resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?
    ) throws {
        requireInsideSandbox(url)
        try failIfAsked(url)
        try createDirectory(at: fakeTrash, withIntermediateDirectories: true)
        let destination = fakeTrash.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        let path = TemporaryDirectory.canonical(url)
        try moveItem(at: url, to: destination)
        trashed.append(path)
        outResultingURL?.pointee = destination as NSURL
    }

    override func removeItem(at url: URL) throws {
        requireInsideSandbox(url)
        try failIfAsked(url)
        let path = TemporaryDirectory.canonical(url)
        try super.removeItem(at: url)
        removed.append(path)
    }

    override func removeItem(atPath path: String) throws {
        try removeItem(at: URL(fileURLWithPath: path))
    }
}
