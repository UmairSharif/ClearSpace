import XCTest
@testable import ClearSpace

final class SmartScanServiceTests: XCTestCase {
    private var home: TemporaryDirectory!
    /// Above SmartScanService's 5 MB noise threshold.
    private let bigFile = 6 * Bytes.megabyte

    override func setUpWithError() throws {
        home = try TemporaryDirectory()
    }

    override func tearDown() {
        home = nil
    }

    private func target(
        _ relativePath: String,
        mode: CleanupTarget.Mode = .whole,
        category: CleanupCategory = .packageManagers,
        safety: SafetyLevel = .safe,
        forcePermanent: Bool = false,
        excluded: [String] = []
    ) -> CleanupTarget {
        CleanupTarget(
            title: "Test Target",
            relativePath: relativePath,
            category: category,
            safety: safety,
            explanation: "Used by tests.",
            mode: mode,
            forcePermanent: forcePermanent,
            hint: nil,
            excludedChildPrefixes: excluded
        )
    }

    private func resolve(_ target: CleanupTarget, reserved: Set<String> = []) -> [CleanupItem] {
        SmartScanService.resolve(target, reservedPaths: reserved, home: home.url)
    }

    func testMissingLocationYieldsNothing() {
        XCTAssertTrue(resolve(target(".npm/_cacache")).isEmpty)
    }

    func testWholeModeOffersOneItemForTheFolder() throws {
        try home.makeFile(".npm/_cacache/content/blob", size: bigFile)

        let items = resolve(target(".npm/_cacache", safety: .safe))

        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.url.path, home.path(".npm/_cacache").path)
        XCTAssertFalse(item.contentsOnly)
        XCTAssertEqual(item.safety, .safe)
        XCTAssertGreaterThanOrEqual(item.size, Int64(bigFile))
        XCTAssertTrue(item.isSelectable)
    }

    func testContentsModeKeepsTheFolder() throws {
        try home.makeFile("Library/Developer/Xcode/DerivedData/App-abc/Build/x.o", size: bigFile)

        let items = resolve(target("Library/Developer/Xcode/DerivedData", mode: .contents))

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].contentsOnly)
        XCTAssertTrue(items[0].deletionEntry.contentsOnly)
    }

    func testSmallLocationsAreLeftOut() throws {
        try home.makeFile("Library/Caches/Yarn/index", size: 64 * Bytes.kilobyte)
        XCTAssertTrue(resolve(target("Library/Caches/Yarn")).isEmpty)
    }

    func testEachChildModeOffersEveryLargeChildSeparately() throws {
        try home.makeFile("Library/Developer/Xcode/iOS DeviceSupport/17.0 (21A329)/Symbols/a", size: bigFile)
        try home.makeFile("Library/Developer/Xcode/iOS DeviceSupport/18.1 (22B83)/Symbols/a", size: bigFile)
        try home.makeFile("Library/Developer/Xcode/iOS DeviceSupport/tiny/a", size: 4 * Bytes.kilobyte)
        try home.makeFile("Library/Developer/Xcode/iOS DeviceSupport/.DS_Store", size: bigFile)

        let items = resolve(target("Library/Developer/Xcode/iOS DeviceSupport", mode: .eachChild, category: .xcode))

        XCTAssertEqual(Set(items.map(\.url.lastPathComponent)), ["17.0 (21A329)", "18.1 (22B83)"])
        XCTAssertTrue(items.allSatisfy { !$0.contentsOnly })
        XCTAssertTrue(items.allSatisfy { $0.title.hasPrefix("Test Target: ") })
    }

    func testEachChildSkipsExcludedPrefixesAndReservedPaths() throws {
        try home.makeFile("Library/Caches/com.example.app/data", size: bigFile)
        try home.makeFile("Library/Caches/com.apple.keep/data", size: bigFile)
        try home.makeFile("Library/Caches/Yarn/data", size: bigFile)
        let reserved: Set<String> = [home.path("Library/Caches/Yarn").standardizedFileURL.path]

        let items = resolve(
            target("Library/Caches", mode: .eachChild, category: .appCaches, excluded: ["com.apple."]),
            reserved: reserved
        )

        XCTAssertEqual(items.map(\.url.lastPathComponent), ["com.example.app"])
        // App cache items are titled by the folder name alone.
        XCTAssertEqual(items.first?.title, "com.example.app")
    }

    func testItemCarriesTargetSafetyAndForcePermanent() throws {
        try home.makeFile(".Trash/old.zip", size: bigFile)

        let items = resolve(target(".Trash", mode: .contents, category: .trash, safety: .review, forcePermanent: true))

        let entry = try XCTUnwrap(items.first).deletionEntry
        XCTAssertEqual(entry.safety, .review)
        XCTAssertTrue(entry.forcePermanent)
        XCTAssertTrue(entry.contentsOnly)
    }

    func testManualItemsAreNotSelectable() throws {
        try home.makeFile("Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", size: bigFile)

        let items = resolve(target(
            "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
            category: .virtualDisks,
            safety: .manual
        ))

        XCTAssertEqual(items.count, 1)
        XCTAssertFalse(items[0].isSelectable)
    }

    func testReservedPathsListOnlySingleItemTargets() {
        let targets = [
            target("Library/Caches/Yarn"),
            target("Library/Logs", mode: .contents),
            target("Library/Caches", mode: .eachChild)
        ]
        let reserved = SmartScanService.reservedPaths(for: targets, home: home.url)
        XCTAssertEqual(reserved, [
            home.url.appendingPathComponent("Library/Caches/Yarn").standardizedFileURL.path,
            home.url.appendingPathComponent("Library/Logs").standardizedFileURL.path
        ])
    }

    func testResolveOnlyReads() throws {
        let file = try home.makeFile(".npm/_cacache/content/blob", size: bigFile)
        _ = resolve(target(".npm/_cacache"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
}
