import Foundation
import XCTest

/// A throwaway folder under the system temporary directory, used as a fake home or
/// projects folder. Tests must never touch the real home folder, so every helper here
/// refuses to work outside this folder.
final class TemporaryDirectory {
    let url: URL

    init(file: StaticString = #filePath, line: UInt = #line) throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClearSpaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        // Use the fully resolved path (`/private/var/...` on macOS) so paths returned by
        // FileManager enumerators compare equal to the ones the tests build.
        guard let resolved = realpath(base.path, nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        defer { free(resolved) }
        url = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)

        let realHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        XCTAssertFalse(
            url.path == realHome || realHome.hasPrefix(url.path + "/"),
            "Temporary directory must not contain the real home folder",
            file: file,
            line: line
        )
    }

    deinit {
        // Only ever removes the folder this instance created.
        if url.lastPathComponent.hasPrefix("ClearSpaceTests-") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Returns `url/relativePath` after checking it stays inside this folder.
    func path(_ relativePath: String) -> URL {
        let child = url.appendingPathComponent(relativePath)
        precondition(contains(child), "Test path escaped the temporary directory: \(child.path)")
        return child
    }

    func contains(_ other: URL) -> Bool {
        Self.canonical(other).hasPrefix(Self.canonical(url) + "/")
    }

    /// Standardized path without the `/private` prefix. `standardizedFileURL` drops
    /// `/private` only when the item exists, so paths are compared in this form.
    static func canonical(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        for prefix in ["/private/var/", "/private/tmp/"] where path.hasPrefix(prefix) {
            return String(path.dropFirst("/private".count))
        }
        return path
    }

    @discardableResult
    func makeDirectory(_ relativePath: String) throws -> URL {
        let directory = path(relativePath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes a file of `size` bytes of non-zero data so the file system allocates real blocks.
    @discardableResult
    func makeFile(_ relativePath: String, size: Int = 16) throws -> URL {
        let file = path(relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0xA5, count: size).write(to: file)
        return file
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: path(relativePath).path)
    }
}

enum Bytes {
    static let kilobyte = 1024
    static let megabyte = 1024 * 1024
}
