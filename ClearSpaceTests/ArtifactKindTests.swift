import XCTest
@testable import ClearSpace

final class ArtifactKindTests: XCTestCase {
    private var root: TemporaryDirectory!

    override func setUpWithError() throws {
        root = try TemporaryDirectory()
    }

    override func tearDown() {
        root = nil
    }

    private func match(_ folder: String, markers: [String] = []) throws -> ArtifactKind? {
        let project = try root.makeDirectory("Project-\(UUID().uuidString)")
        for marker in markers {
            try Data().write(to: project.appendingPathComponent(marker))
        }
        return ArtifactKind.match(folderName: folder, parent: project)
    }

    // MARK: Unambiguous names

    func testUnambiguousNamesMatchWithoutMarkers() throws {
        XCTAssertEqual(try match("node_modules"), .nodeModules)
        XCTAssertEqual(try match(".dart_tool"), .dartTool)
        XCTAssertEqual(try match("DerivedData"), .derivedData)
    }

    // MARK: Names that need a marker file

    func testPodsNeedsPodfile() throws {
        XCTAssertNil(try match("Pods"))
        XCTAssertEqual(try match("Pods", markers: ["Podfile"]), .pods)
    }

    func testBuildNeedsFlutterOrGradleMarker() throws {
        XCTAssertNil(try match("build"))
        XCTAssertNil(try match("build", markers: ["package.json"]))
        XCTAssertEqual(try match("build", markers: ["pubspec.yaml"]), .flutterBuild)
        XCTAssertEqual(try match("build", markers: ["build.gradle"]), .flutterBuild)
        XCTAssertEqual(try match("build", markers: ["build.gradle.kts"]), .flutterBuild)
    }

    func testGradleNeedsGradleMarker() throws {
        XCTAssertNil(try match(".gradle"))
        for marker in ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"] {
            XCTAssertEqual(try match(".gradle", markers: [marker]), .gradle, marker)
        }
    }

    func testTargetNeedsCargoToml() throws {
        XCTAssertNil(try match("target"))
        XCTAssertNil(try match("target", markers: ["pom.xml"]))
        XCTAssertEqual(try match("target", markers: ["Cargo.toml"]), .rustTarget)
    }

    func testNextNeedsPackageJson() throws {
        XCTAssertNil(try match(".next"))
        XCTAssertEqual(try match(".next", markers: ["package.json"]), .nextBuild)
    }

    func testSwiftBuildNeedsPackageSwift() throws {
        XCTAssertNil(try match(".build"))
        XCTAssertEqual(try match(".build", markers: ["Package.swift"]), .swiftBuild)
    }

    // MARK: Things that must never match

    func testUserFoldersNeverMatch() throws {
        let markers = ["Podfile", "pubspec.yaml", "build.gradle", "Cargo.toml", "package.json", "Package.swift"]
        for folder in ["src", "Sources", "lib", "Documents", ".git", "Build", "Targets", "node_module", "pods"] {
            XCTAssertNil(try match(folder, markers: markers), folder)
        }
    }

    func testMarkerMustBeASiblingNotAChild() throws {
        let project = try root.makeDirectory("Nested")
        try root.makeFile("Nested/Pods/Podfile")
        XCTAssertNil(ArtifactKind.match(folderName: "Pods", parent: project))
    }

    func testEveryKindHasTitleAndRestoreHint() {
        for kind in ArtifactKind.allCases {
            XCTAssertFalse(kind.title.isEmpty, "\(kind)")
            XCTAssertFalse(kind.restoreHint.isEmpty, "\(kind)")
        }
    }
}
