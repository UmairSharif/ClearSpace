import XCTest
@testable import ClearSpace

final class ProjectArtifactScannerTests: XCTestCase {
    private var root: TemporaryDirectory!

    override func setUpWithError() throws {
        root = try TemporaryDirectory()
    }

    override func tearDown() {
        root = nil
    }

    func testFindsArtifactsAboveMinimumSizeSortedLargestFirst() async throws {
        try root.makeFile("web/package.json")
        try root.makeFile("web/node_modules/lib/index.js", size: 3 * Bytes.megabyte)
        try root.makeFile("ios/Podfile")
        try root.makeFile("ios/Pods/Lib/Lib.a", size: 2 * Bytes.megabyte)

        let results = await ProjectArtifactScanner.scan(root: root.url)

        XCTAssertEqual(results.map(\.kind), [.nodeModules, .pods])
        XCTAssertEqual(results.map(\.project), ["web", "ios"])
        XCTAssertEqual(results.map(\.url.lastPathComponent), ["node_modules", "Pods"])
        XCTAssertTrue(results.allSatisfy { $0.size >= Bytes.megabyte })
    }

    func testSkipsArtifactsBelowOneMegabyte() async throws {
        try root.makeFile("tiny/node_modules/a.js", size: 10 * Bytes.kilobyte)
        let results = await ProjectArtifactScanner.scan(root: root.url)
        XCTAssertTrue(results.isEmpty)
    }

    func testIgnoresAmbiguousFoldersWithoutMarkers() async throws {
        try root.makeFile("notes/build/report.pdf", size: 2 * Bytes.megabyte)
        try root.makeFile("java/target/app.jar", size: 2 * Bytes.megabyte)
        try root.makeFile("java/pom.xml")

        let results = await ProjectArtifactScanner.scan(root: root.url)
        XCTAssertTrue(results.isEmpty, "\(results.map(\.url.path))")
    }

    func testDoesNotDescendIntoSkippedFolders() async throws {
        try root.makeFile(".git/modules/node_modules/x.js", size: 2 * Bytes.megabyte)
        try root.makeFile("Library/app/node_modules/x.js", size: 2 * Bytes.megabyte)
        try root.makeFile(".Trash/old/node_modules/x.js", size: 2 * Bytes.megabyte)

        let results = await ProjectArtifactScanner.scan(root: root.url)
        XCTAssertTrue(results.isEmpty, "\(results.map(\.url.path))")
    }

    func testNestedArtifactsAreReportedOnceAtTheOuterFolder() async throws {
        try root.makeFile("app/node_modules/pkg/node_modules/dep/index.js", size: 2 * Bytes.megabyte)

        let results = await ProjectArtifactScanner.scan(root: root.url)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.url.deletingLastPathComponent().lastPathComponent, "app")
    }

    func testScanOnlyReads() async throws {
        let file = try root.makeFile("app/node_modules/index.js", size: 2 * Bytes.megabyte)
        _ = await ProjectArtifactScanner.scan(root: root.url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeletionEntryIsSafeAndRemovesTheWholeFolder() async throws {
        try root.makeFile("app/node_modules/index.js", size: 2 * Bytes.megabyte)
        let results = await ProjectArtifactScanner.scan(root: root.url)
        let item = try XCTUnwrap(results.first)

        let entry = item.deletionEntry
        XCTAssertEqual(entry.url, item.url)
        XCTAssertEqual(entry.safety, .safe)
        XCTAssertFalse(entry.contentsOnly)
        XCTAssertFalse(entry.forcePermanent)
    }

    func testCancelledScanReturnsNothing() async throws {
        try root.makeFile("app/node_modules/index.js", size: 2 * Bytes.megabyte)
        let task = Task { () -> [ArtifactItem] in
            withUnsafeCurrentTask { $0?.cancel() }
            return await ProjectArtifactScanner.scan(root: root.url)
        }
        let results = await task.value
        XCTAssertTrue(results.isEmpty)
    }
}
