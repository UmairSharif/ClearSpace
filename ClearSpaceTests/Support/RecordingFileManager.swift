import Foundation

/// A FileManager that only ever acts inside one sandbox folder. "Trash" moves items into
/// `sandbox/.Trash` instead of the real Trash, and any attempt to touch a path outside the
/// sandbox stops the test run before anything happens.
final class RecordingFileManager: FileManager {
    let sandbox: URL
    private(set) var trashed: [URL] = []
    private(set) var removed: [URL] = []
    /// Paths (standardized) that fail with a permission error when trashed or removed.
    var failingPaths: Set<String> = []

    init(sandbox: URL) {
        self.sandbox = sandbox.standardizedFileURL
        super.init()
    }

    var fakeTrash: URL { sandbox.appendingPathComponent(".Trash", isDirectory: true) }

    private func requireInsideSandbox(_ url: URL) {
        let path = url.standardizedFileURL.path
        precondition(
            path.hasPrefix(sandbox.path + "/"),
            "Test tried to delete outside its temporary folder: \(path)"
        )
    }

    private func failIfAsked(_ url: URL) throws {
        if failingPaths.contains(url.standardizedFileURL.path) {
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
        try moveItem(at: url, to: destination)
        trashed.append(url.standardizedFileURL)
        outResultingURL?.pointee = destination as NSURL
    }

    override func removeItem(at url: URL) throws {
        requireInsideSandbox(url)
        try failIfAsked(url)
        try super.removeItem(at: url)
        removed.append(url.standardizedFileURL)
    }

    override func removeItem(atPath path: String) throws {
        try removeItem(at: URL(fileURLWithPath: path))
    }
}
