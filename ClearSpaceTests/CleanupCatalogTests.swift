import XCTest
@testable import ClearSpace

/// Guards the curated list of cleanup locations against entries that would weaken the
/// safety model. Pure path checks: nothing on disk is touched.
final class CleanupCatalogTests: XCTestCase {
    private let fakeHome = URL(fileURLWithPath: "/tmp/ClearSpaceTests-catalog/Users/tester", isDirectory: true)
    private let targets = CleanupCatalog.targets

    func testRelativePathsStayInsideHome() {
        for target in targets {
            let path = target.relativePath
            XCTAssertFalse(path.isEmpty, target.title)
            XCTAssertFalse(path.hasPrefix("/"), target.title)
            XCTAssertFalse(path.hasPrefix("~"), target.title)
            XCTAssertFalse(path.split(separator: "/").contains(".."), target.title)
        }
    }

    func testRelativePathsAreUnique() {
        let paths = targets.map(\.relativePath)
        XCTAssertEqual(paths.count, Set(paths).count)
    }

    func testWholeTargetsAreDeletable() {
        for target in targets where target.safety != .manual {
            guard case .whole = target.mode else { continue }
            let url = fakeHome.appendingPathComponent(target.relativePath)
            XCTAssertTrue(SafetyGuard.isDeletable(url, home: fakeHome), target.relativePath)
        }
    }

    func testChildrenOfContainerTargetsAreDeletable() {
        for target in targets where target.safety != .manual {
            if case .whole = target.mode { continue }
            let child = fakeHome.appendingPathComponent(target.relativePath).appendingPathComponent("child")
            XCTAssertTrue(SafetyGuard.isDeletable(child, home: fakeHome), target.relativePath)
        }
    }

    func testNeverOffersUserDataLocations() {
        // Wallets, browser profiles, documents and credentials are never caches.
        let forbiddenPrefixes = [
            "Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music",
            "Library/Application Support", "Library/Keychains", "Library/Mail",
            "Library/Mobile Documents", "Library/Preferences", "Library/Group Containers",
            ".ssh", ".gnupg"
        ]
        for target in targets {
            let path = target.relativePath.lowercased()
            for prefix in forbiddenPrefixes {
                let forbidden = prefix.lowercased()
                XCTAssertFalse(
                    path == forbidden || path.hasPrefix(forbidden + "/"),
                    "\(target.relativePath) is under \(prefix)"
                )
            }
        }
    }

    func testDockerDiskAndSimulatorDevicesAreManualWithAHint() throws {
        let docker = try XCTUnwrap(targets.first { $0.relativePath.hasSuffix("Docker.raw") })
        XCTAssertEqual(docker.safety, .manual)
        XCTAssertFalse(docker.hint?.isEmpty ?? true)

        let simulators = try XCTUnwrap(targets.first { $0.relativePath == "Library/Developer/CoreSimulator/Devices" })
        XCTAssertEqual(simulators.safety, .manual)
        XCTAssertFalse(simulators.hint?.isEmpty ?? true)
    }

    func testTrashIsEmptiedPermanentlyAfterReview() throws {
        let trash = try XCTUnwrap(targets.first { $0.relativePath == ".Trash" })
        XCTAssertEqual(trash.safety, .review)
        XCTAssertTrue(trash.forcePermanent)
        guard case .contents = trash.mode else {
            return XCTFail("The Trash folder itself must be kept")
        }
    }

    func testOnlyTheTrashForcesPermanentDeletion() {
        let forced = targets.filter(\.forcePermanent).map(\.relativePath)
        XCTAssertEqual(forced, [".Trash"])
    }

    func testEveryTargetExplainsItself() {
        for target in targets {
            XCTAssertFalse(target.title.isEmpty)
            XCTAssertFalse(target.explanation.isEmpty, target.title)
        }
    }
}
