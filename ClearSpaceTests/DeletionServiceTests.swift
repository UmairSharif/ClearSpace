import XCTest
@testable import ClearSpace

/// Runs DeletionService against a temporary fake home and a file manager that cannot
/// reach the real Trash or anything outside the temporary folder.
final class DeletionServiceTests: XCTestCase {
    private var home: TemporaryDirectory!
    private var fileManager: RecordingFileManager!

    override func setUpWithError() throws {
        home = try TemporaryDirectory()
        fileManager = RecordingFileManager(sandbox: home.url)
    }

    override func tearDown() {
        fileManager = nil
        home = nil
    }

    private func entry(
        _ relativePath: String,
        size: Int64 = 1_000,
        safety: SafetyLevel = .safe,
        contentsOnly: Bool = false,
        forcePermanent: Bool = false
    ) -> DeletionEntry {
        let url = home.path(relativePath)
        return DeletionEntry(
            id: url.path,
            url: url,
            title: url.lastPathComponent,
            size: size,
            safety: safety,
            contentsOnly: contentsOnly,
            forcePermanent: forcePermanent
        )
    }

    private func canonical(_ url: URL) -> String {
        TemporaryDirectory.canonical(url)
    }

    private func perform(_ entries: [DeletionEntry], mode: DeletionMode) async -> DeletionReport {
        await DeletionService.perform(entries, mode: mode, home: home.url, fileManager: fileManager)
    }

    // MARK: Modes

    func testTrashModeMovesToTrashAndDoesNotRemove() async throws {
        try home.makeFile("Projects/app/node_modules/index.js")
        let item = entry("Projects/app/node_modules", size: 4_096)

        let report = await perform([item], mode: .trash)

        XCTAssertFalse(home.exists("Projects/app/node_modules"))
        XCTAssertEqual(fileManager.trashed, [canonical(item.url)])
        XCTAssertTrue(fileManager.removed.isEmpty)
        XCTAssertEqual(report.mode, .trash)
        XCTAssertEqual(report.deletedIDs, [item.id])
        XCTAssertEqual(report.freedBytes, 4_096)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(report.requestedCount, 1)

        // The item is recoverable from the (fake) Trash.
        let inTrash = try FileManager.default.contentsOfDirectory(atPath: fileManager.fakeTrash.path)
        XCTAssertEqual(inTrash.count, 1)
    }

    func testPermanentModeRemovesAndDoesNotTrash() async throws {
        try home.makeFile("Library/Caches/com.example/cache.db")
        let item = entry("Library/Caches/com.example")

        let report = await perform([item], mode: .permanent)

        XCTAssertFalse(home.exists("Library/Caches/com.example"))
        XCTAssertTrue(home.exists("Library/Caches"))
        XCTAssertEqual(fileManager.removed, [canonical(item.url)])
        XCTAssertTrue(fileManager.trashed.isEmpty)
        XCTAssertEqual(report.deletedIDs, [item.id])
    }

    func testForcePermanentOverridesTrashModeForThatEntryOnly() async throws {
        try home.makeFile(".Trash/old.zip")
        try home.makeFile("Projects/app/.dart_tool/cache")
        let trashContents = entry(".Trash", safety: .review, contentsOnly: true, forcePermanent: true)
        let artifact = entry("Projects/app/.dart_tool")

        let report = await perform([trashContents, artifact], mode: .trash)

        XCTAssertEqual(fileManager.removed, [canonical(home.path(".Trash/old.zip"))])
        XCTAssertEqual(fileManager.trashed, [canonical(artifact.url)])
        XCTAssertEqual(report.mode, .trash)
        XCTAssertEqual(report.deletedIDs, [trashContents.id, artifact.id])
    }

    // MARK: Contents-only entries

    func testContentsOnlyEmptiesTheFolderButKeepsIt() async throws {
        try home.makeFile("Library/Developer/Xcode/DerivedData/App-abc/Build/x.o")
        try home.makeFile("Library/Developer/Xcode/DerivedData/Other-def/info.plist")
        let item = entry("Library/Developer/Xcode/DerivedData", contentsOnly: true)

        let report = await perform([item], mode: .permanent)

        XCTAssertTrue(home.exists("Library/Developer/Xcode/DerivedData"))
        let left = try FileManager.default.contentsOfDirectory(atPath: item.url.path)
        XCTAssertTrue(left.isEmpty, "\(left)")
        XCTAssertEqual(Set(fileManager.removed.map { ($0 as NSString).lastPathComponent }), ["App-abc", "Other-def"])
        XCTAssertEqual(report.deletedIDs, [item.id])
    }

    func testEmptyContentsOnlyFolderSucceedsWithoutRemovingAnything() async throws {
        try home.makeDirectory("Library/Logs")
        let item = entry("Library/Logs", contentsOnly: true)

        let report = await perform([item], mode: .trash)

        XCTAssertTrue(home.exists("Library/Logs"))
        XCTAssertTrue(fileManager.trashed.isEmpty)
        XCTAssertTrue(fileManager.removed.isEmpty)
        XCTAssertTrue(report.failures.isEmpty)
    }

    // MARK: SafetyGuard is enforced

    func testProtectedFoldersAreNeverRemoved() async throws {
        let protected = [
            "Documents", "Desktop", "Downloads", "Pictures", "Library",
            "Library/Application Support", "Library/Keychains", "Library/Mail", ".ssh", ".Trash"
        ]
        for path in protected {
            try home.makeFile("\(path)/keep.txt")
        }

        let report = await perform(protected.map { entry($0) }, mode: .permanent)

        for path in protected {
            XCTAssertTrue(home.exists("\(path)/keep.txt"), path)
        }
        XCTAssertTrue(fileManager.removed.isEmpty)
        XCTAssertTrue(fileManager.trashed.isEmpty)
        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, protected.count)
        XCTAssertEqual(report.freedBytes, 0)
    }

    func testProtectedFolderIsRefusedWhateverTheCase() async throws {
        try home.makeFile("Documents/thesis.pages")
        let report = await perform([entry("documents"), entry("DOCUMENTS")], mode: .permanent)

        XCTAssertTrue(home.exists("Documents/thesis.pages"))
        XCTAssertTrue(fileManager.removed.isEmpty)
        XCTAssertEqual(report.failures.count, 2)
    }

    func testHomeFolderItselfIsNeverRemoved() async throws {
        try home.makeFile("Documents/keep.txt")
        let homeEntry = DeletionEntry(
            id: home.url.path, url: home.url, title: "Home", size: 1,
            safety: .review, contentsOnly: false, forcePermanent: false
        )

        let report = await perform([homeEntry], mode: .permanent)

        XCTAssertTrue(home.exists("Documents/keep.txt"))
        XCTAssertTrue(fileManager.removed.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
    }

    func testEmptyingAContentsOnlyHomeSkipsProtectedChildren() async throws {
        // A bad catalog entry pointing at the home folder with `.contents` must not wipe it.
        try home.makeFile("Documents/keep.txt")
        try home.makeFile("Library/Preferences/com.example.plist")
        try home.makeFile("scratch.tmp")
        let homeContents = DeletionEntry(
            id: home.url.path, url: home.url, title: "Home", size: 1,
            safety: .safe, contentsOnly: true, forcePermanent: false
        )

        let report = await perform([homeContents], mode: .permanent)

        XCTAssertTrue(home.exists("Documents/keep.txt"))
        XCTAssertTrue(home.exists("Library/Preferences/com.example.plist"))
        XCTAssertFalse(home.exists("scratch.tmp"))
        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, 2)
    }

    func testPathsOutsideHomeAreRefused() async throws {
        // A sibling of the fake home: inside the sandbox but outside `home`.
        let outsideHome = try TemporaryDirectory()
        let file = try outsideHome.makeFile("outside.bin")
        let fakeHome = try home.makeDirectory("Users/tester")
        let item = DeletionEntry(
            id: file.path, url: file, title: "outside", size: 16,
            safety: .review, contentsOnly: false, forcePermanent: false
        )

        let report = await DeletionService.perform(
            [item], mode: .permanent, home: fakeHome, fileManager: fileManager
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
    }

    func testDotDotCannotEscapeIntoAProtectedFolder() async throws {
        try home.makeFile("Documents/keep.txt")
        try home.makeDirectory("Projects")
        let sneaky = home.url.appendingPathComponent("Projects/../Documents")
        let item = DeletionEntry(
            id: sneaky.path, url: sneaky, title: "sneaky", size: 1,
            safety: .safe, contentsOnly: false, forcePermanent: false
        )

        let report = await perform([item], mode: .permanent)

        XCTAssertTrue(home.exists("Documents/keep.txt"))
        XCTAssertEqual(report.failures.count, 1)
    }

    // MARK: Failures and reporting

    func testFailedRemovalIsReportedAndNotCountedAsDeleted() async throws {
        try home.makeFile("Projects/a/node_modules/x.js")
        try home.makeFile("Projects/b/node_modules/x.js")
        let ok = entry("Projects/a/node_modules", size: 500)
        let failing = entry("Projects/b/node_modules", size: 700)
        fileManager.failingPaths = [canonical(failing.url)]

        let report = await perform([ok, failing], mode: .trash)

        XCTAssertEqual(report.deletedIDs, [ok.id])
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertTrue(report.failures[0].path.hasSuffix("Projects/b/node_modules"))
        XCTAssertTrue(home.exists("Projects/b/node_modules/x.js"))
        // Only what was actually removed counts towards the freed total.
        XCTAssertGreaterThanOrEqual(report.freedBytes, 500)
        XCTAssertLessThan(report.freedBytes, 500 + 700)
    }

    func testPartiallyEmptiedFolderCountsOnlyWhatWasRemoved() async throws {
        try home.makeFile("Library/Logs/gone.log", size: 64 * Bytes.kilobyte)
        let stays = try home.makeFile("Library/Logs/stays.log", size: 64 * Bytes.kilobyte)
        fileManager.failingPaths = [canonical(stays)]
        let item = entry("Library/Logs", size: Int64(128 * Bytes.kilobyte), contentsOnly: true)

        let report = await perform([item], mode: .permanent)

        XCTAssertFalse(home.exists("Library/Logs/gone.log"))
        XCTAssertTrue(home.exists("Library/Logs/stays.log"))
        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertGreaterThan(report.freedBytes, 0)
        XCTAssertLessThan(report.freedBytes, item.size)
    }

    func testMissingItemIsReportedAsFailure() async throws {
        let item = entry("Projects/gone/node_modules")
        let report = await perform([item], mode: .trash)
        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
    }

    func testEmptyRequestDoesNothing() async {
        let report = await perform([], mode: .permanent)
        XCTAssertEqual(report.requestedCount, 0)
        XCTAssertEqual(report.freedBytes, 0)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(fileManager.removed.isEmpty)
    }

    func testReportedFailuresAreCapped() async throws {
        try home.makeDirectory("Documents")
        let entries = Array(repeating: entry("Documents"), count: 120)
        let report = await perform(entries, mode: .permanent)
        XCTAssertEqual(report.requestedCount, 120)
        XCTAssertEqual(report.failures.count, 100)
    }
}
