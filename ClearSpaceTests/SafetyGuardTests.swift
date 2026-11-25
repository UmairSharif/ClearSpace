import XCTest
@testable import ClearSpace

/// Pure path checks on SafetyGuard. Nothing is created or removed here.
/// Case, link and normalization cases are in CleanupFixesTests.
final class SafetyGuardTests: XCTestCase {
    private var home: TemporaryDirectory!

    override func setUpWithError() throws {
        home = try TemporaryDirectory()
    }

    override func tearDown() {
        home = nil
    }

    private func deletable(_ relativePath: String) -> Bool {
        SafetyGuard.isDeletable(home.url.appendingPathComponent(relativePath), home: home.url)
    }

    func testEveryProtectedFolderIsRefused() {
        let protected = [
            "Applications", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public",
            "Library", "Library/Application Support", "Library/Caches", "Library/Containers",
            "Library/Developer", "Library/Group Containers", "Library/Keychains", "Library/Logs",
            "Library/Mail", "Library/Mobile Documents", "Library/Preferences", ".Trash", ".ssh"
        ]
        for path in protected {
            XCTAssertFalse(deletable(path), path)
            XCTAssertFalse(deletable(path + "/"), path + "/")
        }
    }

    func testItemsInsideProtectedFoldersAreAllowed() {
        // Catalog entries live here; SafetyGuard protects the folders, not their contents.
        for path in [
            "Library/Caches/com.example",
            "Library/Developer/Xcode/DerivedData",
            "Library/Logs/DiagnosticReports",
            ".Trash/old.zip",
            "Downloads/installer.dmg",
            "Projects/app/node_modules"
        ] {
            XCTAssertTrue(deletable(path), path)
        }
    }

    func testHomeAndSystemLocationsAreRefused() {
        XCTAssertFalse(SafetyGuard.isDeletable(home.url, home: home.url))
        for path in ["/", "/System", "/Library/Caches", "/Applications/Safari.app", "/usr/local", "/private/var", "/Users"] {
            XCTAssertFalse(SafetyGuard.isDeletable(URL(fileURLWithPath: path), home: home.url), path)
        }
    }

    func testSiblingWithHomeAsPrefixIsRefused() {
        let sibling = URL(fileURLWithPath: home.url.path + "-other/file")
        XCTAssertFalse(SafetyGuard.isDeletable(sibling, home: home.url))
    }

    func testExternalVolumeRootsAreRefusedButContentsAllowed() {
        XCTAssertFalse(SafetyGuard.isDeletable(URL(fileURLWithPath: "/Volumes"), home: home.url))
        XCTAssertFalse(SafetyGuard.isDeletable(URL(fileURLWithPath: "/Volumes/ExternalSSD"), home: home.url))
        XCTAssertTrue(SafetyGuard.isDeletable(URL(fileURLWithPath: "/Volumes/ExternalSSD/Old Backups"), home: home.url))
    }

    func testBootVolumeAliasCannotReachSystemOrHomeFolders() throws {
        // `/Volumes/Macintosh HD` (whatever its name) links to `/`. Going through it must
        // not bypass the home and system checks.
        let volumes = (try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")) ?? []
        let bootAlias = volumes.first {
            URL(fileURLWithPath: "/Volumes/\($0)").resolvingSymlinksInPath().path == "/"
        }
        guard let name = bootAlias else {
            throw XCTSkip("No /Volumes entry links to / on this machine")
        }
        let realHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

        for path in ["/Volumes/\(name)/System", "/Volumes/\(name)/Library", "/Volumes/\(name)\(realHome)/Documents"] {
            XCTAssertFalse(SafetyGuard.isDeletable(URL(fileURLWithPath: path)), path)
        }
    }

    func testDefaultHomeOverloadProtectsTheRealHome() {
        // Pure check against the real home path. Nothing is deleted.
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertFalse(SafetyGuard.isDeletable(realHome))
        XCTAssertFalse(SafetyGuard.isDeletable(realHome.appendingPathComponent("Documents")))
        XCTAssertFalse(SafetyGuard.isDeletable(realHome.appendingPathComponent("Library/Application Support")))
    }
}
