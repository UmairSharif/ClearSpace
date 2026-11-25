import XCTest
@testable import ClearSpace

/// Covers the fixes for false "cleaned" reports, the Trash default, symlink sizing
/// and SafetyGuard normalization. Everything runs inside a temporary fake home.
final class CleanupFixesTests: XCTestCase {
    private var home: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        home = fileManager.temporaryDirectory
            .appendingPathComponent("ClearSpaceTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let home {
            // Restore permissions changed by a test so the folder can be removed.
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.appendingPathComponent("Locked").path)
            try? fileManager.removeItem(at: home)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func makeFolder(_ relative: String) throws -> URL {
        let url = home.appendingPathComponent(relative, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func makeFile(_ relative: String, bytes: Int = 64 * 1024) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    private func entry(_ url: URL, size: Int64 = 1_000, contentsOnly: Bool) -> DeletionEntry {
        DeletionEntry(
            id: url.standardizedFileURL.path,
            url: url,
            title: url.lastPathComponent,
            size: size,
            safety: .safe,
            contentsOnly: contentsOnly,
            forcePermanent: false
        )
    }

    // MARK: - Contents-only folders that cannot be listed

    func testUnlistableContentsOnlyFolderIsReportedAsFailed() throws {
        let locked = try makeFolder("Locked")
        try makeFile("Locked/inside.bin")
        try fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        try XCTSkipIf(
            (try? fileManager.contentsOfDirectory(atPath: locked.path)) != nil,
            "Running with privileges that can list a 000 folder."
        )

        let item = entry(locked, size: 5_000, contentsOnly: true)
        let report = DeletionService.performSync([item], mode: .permanent, home: home)

        XCTAssertFalse(report.deletedIDs.contains(item.id))
        XCTAssertEqual(report.freedBytes, 0)
        XCTAssertEqual(report.failures.count, 1)
    }

    func testMissingContentsOnlyFolderIsReportedAsFailed() {
        let missing = home.appendingPathComponent("DoesNotExist", isDirectory: true)
        let item = entry(missing, size: 5_000, contentsOnly: true)

        let report = DeletionService.performSync([item], mode: .permanent, home: home)

        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.freedBytes, 0)
        XCTAssertEqual(report.failures.count, 1)
    }

    func testListableContentsOnlyFolderIsEmptiedAndKept() throws {
        let folder = try makeFolder("Cache")
        try makeFile("Cache/a.bin")
        try makeFile("Cache/sub/b.bin")
        let item = entry(folder, size: 5_000, contentsOnly: true)

        let report = DeletionService.performSync([item], mode: .permanent, home: home)

        XCTAssertTrue(report.deletedIDs.contains(item.id))
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(report.freedBytes, 5_000)
        XCTAssertTrue(fileManager.fileExists(atPath: folder.path))
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: folder.path), [])
    }

    func testContentsOnlyFolderThatIsALinkIsNotEmptied() throws {
        let real = try makeFolder("Real")
        let kept = try makeFile("Real/keep.bin")
        let link = home.appendingPathComponent("LinkedCache")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: real)

        let item = entry(link, contentsOnly: true)
        let report = DeletionService.performSync([item], mode: .permanent, home: home)

        XCTAssertTrue(report.deletedIDs.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertTrue(fileManager.fileExists(atPath: kept.path))
    }

    // MARK: - Delete mode default

    func testEveryConfirmationStartsWithTrash() {
        XCTAssertEqual(DeletionMode.initialChoice, .trash)
    }

    // MARK: - Symlink sizing

    func testSymlinkToFolderIsSizedAsTheLinkNotTheTarget() throws {
        let target = try makeFolder("Big")
        try makeFile("Big/payload.bin", bytes: 4 * 1024 * 1024)
        let link = home.appendingPathComponent("BigLink")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: target)

        let targetSize = SizeCalculator.allocatedSize(of: target)
        let linkSize = SizeCalculator.allocatedSize(of: link)

        XCTAssertGreaterThanOrEqual(targetSize, 4 * 1024 * 1024)
        XCTAssertLessThan(linkSize, 64 * 1024)
    }

    func testSymlinkToFileIsSizedAsTheLink() throws {
        let target = try makeFile("big.bin", bytes: 2 * 1024 * 1024)
        let link = home.appendingPathComponent("big-link.bin")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertLessThan(SizeCalculator.allocatedSize(of: link), 64 * 1024)
    }

    func testDanglingSymlinkDoesNotCrashAndIsTiny() throws {
        let link = home.appendingPathComponent("dangling")
        try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: home.appendingPathComponent("nope").path)

        XCTAssertLessThan(SizeCalculator.allocatedSize(of: link), 64 * 1024)
    }

    func testFolderContainingSymlinkDoesNotCountTheTarget() throws {
        let outside = try makeFolder("Outside")
        try makeFile("Outside/payload.bin", bytes: 4 * 1024 * 1024)
        let folder = try makeFolder("Cache")
        try makeFile("Cache/small.bin", bytes: 8 * 1024)
        try fileManager.createSymbolicLink(at: folder.appendingPathComponent("link"), withDestinationURL: outside)

        XCTAssertLessThan(SizeCalculator.allocatedSize(of: folder), 1024 * 1024)
    }

    // MARK: - SafetyGuard normalization

    func testProtectedPathsMatchCaseInsensitively() {
        for path in ["Documents", "documents", "DOCUMENTS", "library/application support", "LIBRARY/Caches", ".TRASH"] {
            XCTAssertFalse(SafetyGuard.isDeletable(home.appendingPathComponent(path), home: home), path)
        }
    }

    func testHomeItselfAndPathsOutsideHomeAreRefused() {
        XCTAssertFalse(SafetyGuard.isDeletable(home, home: home))
        XCTAssertFalse(SafetyGuard.isDeletable(URL(fileURLWithPath: "/System/Library"), home: home))
        XCTAssertFalse(SafetyGuard.isDeletable(home.appendingPathComponent("../elsewhere"), home: home))
    }

    func testOrdinaryChildrenAreAllowed() {
        XCTAssertTrue(SafetyGuard.isDeletable(home.appendingPathComponent("Library/Caches/com.example"), home: home))
        XCTAssertTrue(SafetyGuard.isDeletable(home.appendingPathComponent("documents/old.zip"), home: home))
    }

    func testProtectedFolderReachedThroughParentLinkIsRefused() throws {
        try makeFolder("Documents")
        let link = home.appendingPathComponent("HomeLink")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: home)

        XCTAssertFalse(SafetyGuard.isDeletable(link.appendingPathComponent("Documents"), home: home))
        XCTAssertFalse(SafetyGuard.isDeletable(link.appendingPathComponent("documents"), home: home))
    }

    func testPathOutsideHomeReachedThroughParentLinkIsRefused() throws {
        let link = home.appendingPathComponent("SystemLink")
        try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: "/System")

        XCTAssertFalse(SafetyGuard.isDeletable(link.appendingPathComponent("Library"), home: home))
    }

    func testALinkItselfIsJudgedByItsOwnPath() throws {
        try makeFolder("Documents")
        let link = home.appendingPathComponent("DocsLink")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: home.appendingPathComponent("Documents"))

        // Removing the link removes only the link, so it is allowed.
        XCTAssertTrue(SafetyGuard.isDeletable(link, home: home))
        XCTAssertTrue(SafetyGuard.isSymbolicLink(link))
    }

    func testHomeGivenThroughALinkStillProtects() throws {
        try makeFolder("Documents")
        let linkedHome = fileManager.temporaryDirectory.appendingPathComponent("ClearSpaceHomeLink-\(UUID().uuidString)")
        try fileManager.createSymbolicLink(at: linkedHome, withDestinationURL: home)
        defer { try? fileManager.removeItem(at: linkedHome) }

        XCTAssertFalse(SafetyGuard.isDeletable(home.appendingPathComponent("Documents"), home: linkedHome))
        XCTAssertFalse(SafetyGuard.isDeletable(linkedHome.appendingPathComponent("Documents"), home: home))
    }
}
