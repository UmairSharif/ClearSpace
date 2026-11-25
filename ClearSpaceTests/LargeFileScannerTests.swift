import XCTest
@testable import ClearSpace

final class LargeFileScannerTests: XCTestCase {
    private var home: TemporaryDirectory!

    override func setUpWithError() throws {
        home = try TemporaryDirectory()
    }

    override func tearDown() {
        home = nil
    }

    private func scan(minimumSize: Int = Bytes.megabyte, includeLibrary: Bool = false) async -> [FileEntry] {
        await LargeFileScanner.scan(
            root: home.url,
            minimumSize: Int64(minimumSize),
            includeLibrary: includeLibrary,
            home: home.url
        )
    }

    func testFindsFilesAboveMinimumSortedLargestFirst() async throws {
        try home.makeFile("Movies/clip.mov", size: 3 * Bytes.megabyte)
        try home.makeFile("Downloads/installer.dmg", size: 2 * Bytes.megabyte)
        try home.makeFile("Documents/notes.txt", size: 4 * Bytes.kilobyte)

        let results = await scan()

        XCTAssertEqual(results.map(\.name), ["clip.mov", "installer.dmg"])
        XCTAssertGreaterThan(results[0].size, results[1].size)
    }

    func testSkipsLibraryUnlessAsked() async throws {
        try home.makeFile("Library/Caches/big.bin", size: 2 * Bytes.megabyte)
        try home.makeFile("Desktop/big.bin", size: 2 * Bytes.megabyte)

        let without = await scan(includeLibrary: false)
        XCTAssertEqual(without.count, 1)
        XCTAssertTrue(without[0].url.path.hasSuffix("/Desktop/big.bin"))

        let with = await scan(includeLibrary: true)
        XCTAssertEqual(with.count, 2)
    }

    func testNeverListsTrash() async throws {
        try home.makeFile(".Trash/old.zip", size: 2 * Bytes.megabyte)
        let results = await scan(includeLibrary: true)
        XCTAssertTrue(results.isEmpty)
    }

    func testDoesNotLookInsidePackages() async throws {
        try home.makeFile("Applications/Tool.app/Contents/MacOS/Tool", size: 2 * Bytes.megabyte)
        let results = await scan()
        XCTAssertTrue(results.isEmpty, "\(results.map(\.url.path))")
    }

    func testDeletionEntryNeedsReview() async throws {
        try home.makeFile("Desktop/big.bin", size: 2 * Bytes.megabyte)
        let results = await scan()
        let entry = try XCTUnwrap(results.first).deletionEntry
        XCTAssertEqual(entry.safety, .review)
        XCTAssertFalse(entry.contentsOnly)
        XCTAssertFalse(entry.forcePermanent)
    }

    func testScanOnlyReads() async throws {
        let file = try home.makeFile("Desktop/big.bin", size: 2 * Bytes.megabyte)
        _ = await scan()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
}
