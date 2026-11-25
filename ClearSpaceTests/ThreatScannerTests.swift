import XCTest
@testable import ClearSpace

final class ThreatScannerTests: XCTestCase {
    private var root: TemporaryDirectory!

    override func setUpWithError() throws {
        root = try TemporaryDirectory()
    }

    override func tearDown() {
        root = nil
    }

    private func finding(_ findings: [ThreatFinding], named name: String) -> ThreatFinding? {
        findings.first { $0.url.lastPathComponent == name }
    }

    func testFindsEveryPartOfTheRemovedAttack() async throws {
        try root.makeInfectedProject("ClearSpace")

        let findings = await ThreatScanner.scan(root: root.url)

        let tasks = try XCTUnwrap(finding(findings, named: "tasks.json"))
        XCTAssertEqual(tasks.kind, .autoRunTask)
        XCTAssertEqual(tasks.level, .high)
        XCTAssertEqual(tasks.project, "ClearSpace")

        let font = try XCTUnwrap(finding(findings, named: "fa-solid-600.ttf"))
        XCTAssertEqual(font.kind, .disguisedScript)
        XCTAssertEqual(font.level, .high)
        XCTAssertTrue(font.reasons[0].contains("JavaScript"))
        XCTAssertTrue(font.reasons.contains { $0.contains("hex") })

        XCTAssertEqual(
            tasks.relatedURLs.map(TemporaryDirectory.canonical),
            [TemporaryDirectory.canonical(font.url)],
            "The task should point at the disguised font it runs"
        )

        let settings = try XCTUnwrap(finding(findings, named: "settings.json"))
        XCTAssertEqual(settings.kind, .editorSettings)
        XCTAssertEqual(settings.level, .high)

        let gitignore = try XCTUnwrap(finding(findings, named: ".gitignore"))
        XCTAssertEqual(gitignore.kind, .gitignoreEntries)
        XCTAssertFalse(gitignore.isRemovable, "A .gitignore must be fixed by hand, not deleted")

        XCTAssertNil(finding(findings, named: "fa-solid-900.ttf"), "A real binary font must not be flagged")
        XCTAssertNil(finding(findings, named: "README.md"))
        XCTAssertEqual(findings.first?.level, .high, "Highest risk comes first")
        XCTAssertEqual(findings.last?.url.lastPathComponent, ".gitignore")
    }

    func testCleanProjectHasNoFindings() async throws {
        try root.makeDirectory("app/.git")
        try root.write(#"{ "editor.formatOnSave": true, }"#, to: "app/.vscode/settings.json")
        try root.write(#"{ "version": "2.0.0", "tasks": [{ "label": "build", "command": "npm run build" }] }"#, to: "app/.vscode/tasks.json")
        try root.write(#"{ "name": "app", "scripts": { "prepare": "husky install", "build": "vite build" } }"#, to: "app/package.json")
        try root.write("export const add = (a, b) => a + b\n", to: "app/src/math.js")
        try root.write(MalwareFixtures.realPNGBytes, to: "app/public/logo.png")
        try root.write(MalwareFixtures.realFontBytes, to: "app/public/fonts/Inter.ttf")
        try root.write("node_modules/\ndist/\n", to: "app/.gitignore")

        let findings = await ThreatScanner.scan(root: root.url)
        XCTAssertTrue(findings.isEmpty, "\(findings.map(\.displayPath))")
    }

    func testGitLFSPointerIsNotFlagged() async throws {
        try root.write(
            "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n",
            to: "app/assets/hero.png"
        )
        let findings = await ThreatScanner.scan(root: root.url)
        XCTAssertTrue(findings.isEmpty)
    }

    func testObfuscatedJavaScriptFileIsFlagged() async throws {
        try root.write(MalwareFixtures.obfuscatedScript, to: "app/lib/helper.js")
        let findings = await ThreatScanner.scan(root: root.url)
        let item = try XCTUnwrap(findings.first)
        XCTAssertEqual(item.kind, .obfuscatedScript)
        XCTAssertEqual(item.level, .medium)
    }

    func testCodeHiddenAfterSpacesInConfigIsFlagged() async throws {
        let config = "export default { plugins: {} };" + String(repeating: " ", count: 200) + "global['r']=require;eval(x)\n"
        try root.write(config, to: "web/postcss.config.mjs")
        let findings = await ThreatScanner.scan(root: root.url)
        let item = try XCTUnwrap(findings.first)
        XCTAssertEqual(item.kind, .hiddenCode)
        XCTAssertEqual(item.level, .high)
        XCTAssertEqual(item.evidence?.hasPrefix("global['r']=require"), true)
    }

    func testInstallScriptRunningMediaIsFlagged() async throws {
        try root.write(#"{ "scripts": { "postinstall": "node assets/icon.ico" } }"#, to: "app/package.json")
        try root.write(MalwareFixtures.obfuscatedScript, to: "app/assets/icon.ico")

        let findings = await ThreatScanner.scan(root: root.url)
        let install = try XCTUnwrap(finding(findings, named: "package.json"))
        XCTAssertEqual(install.kind, .installScript)
        XCTAssertEqual(install.level, .high)
        XCTAssertEqual(install.relatedURLs.count, 1)
        XCTAssertNotNil(finding(findings, named: "icon.ico"))
    }

    func testAutoPushHelperIsFlagged() async throws {
        try root.write("git add . && git commit -m update && git push", to: "app/temp_auto_push.bat")
        let findings = await ThreatScanner.scan(root: root.url)
        let item = try XCTUnwrap(findings.first)
        XCTAssertEqual(item.kind, .propagationScript)
        XCTAssertEqual(item.level, .high)
    }

    func testWorkspaceFileTasksAreChecked() async throws {
        try root.write(MalwareFixtures.tasksJSON, to: "team.code-workspace")
        let findings = await ThreatScanner.scan(root: root.url)
        XCTAssertEqual(findings.first?.level, .high)
    }

    func testSkipsDependencyFolders() async throws {
        try root.write(MalwareFixtures.obfuscatedScript, to: "app/node_modules/pkg/fonts/a.woff2")
        try root.write(MalwareFixtures.obfuscatedScript, to: "app/.git/objects/x.png")
        let findings = await ThreatScanner.scan(root: root.url)
        XCTAssertTrue(findings.isEmpty, "\(findings.map(\.displayPath))")
    }

    func testTasksPointingOutsideTheScanFolderAreNotRelated() async throws {
        let tasks = MalwareFixtures.tasksJSON.replacingOccurrences(of: "./\(MalwareFixtures.fontPath)", with: "/etc/hosts.ttf")
        try root.write(tasks, to: "app/.vscode/tasks.json")
        let findings = await ThreatScanner.scan(root: root.url)
        let item = try XCTUnwrap(findings.first)
        XCTAssertTrue(item.relatedURLs.isEmpty)
        XCTAssertEqual(item.level, .high)
    }

    func testProjectNameIsTheNearestProjectFolder() throws {
        try root.makeDirectory("work/client/app/.git")
        let file = try root.write("x", to: "work/client/app/Resources/Assets.xcassets/x.colorset/public/fonts/a.ttf")
        XCTAssertEqual(ThreatScanner.projectName(for: file, root: root.url), "app")

        let loose = try root.write("x", to: "misc/stuff/a.ttf")
        XCTAssertEqual(ThreatScanner.projectName(for: loose, root: root.url), "misc")
    }

    func testScanOnlyReads() async throws {
        try root.makeInfectedProject("app")
        let before = try FileManager.default.subpathsOfDirectory(atPath: root.url.path).sorted()
        _ = await ThreatScanner.scan(root: root.url)
        let after = try FileManager.default.subpathsOfDirectory(atPath: root.url.path).sorted()
        XCTAssertEqual(before, after)
    }

    func testCancelledScanReturnsNothing() async throws {
        try root.makeInfectedProject("app")
        let task = Task { () -> [ThreatFinding] in
            withUnsafeCurrentTask { $0?.cancel() }
            return await ThreatScanner.scan(root: root.url)
        }
        let results = await task.value
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Removal goes through the normal safety model

    func testFindingsAreMarkedReviewAndMoveToTheTrash() async throws {
        try root.makeInfectedProject("app")
        let findings = await ThreatScanner.scan(root: root.url)
        let removable = findings.filter(\.isRemovable)
        XCTAssertFalse(removable.isEmpty)

        let entries = removable.map(\.deletionEntry)
        XCTAssertTrue(entries.allSatisfy { $0.safety == .review && !$0.forcePermanent && !$0.contentsOnly })

        let fileManager = RecordingFileManager(sandbox: root.url)
        let report = await DeletionService.perform(entries, mode: .initialChoice, home: root.url, fileManager: fileManager)

        XCTAssertEqual(report.mode, .trash)
        XCTAssertEqual(report.deletedIDs, Set(entries.map(\.id)))
        XCTAssertTrue(fileManager.removed.isEmpty, "Nothing is deleted permanently by default")
        XCTAssertFalse(root.exists("app/.vscode/tasks.json"))
        XCTAssertFalse(root.exists("app/\(MalwareFixtures.fontPath)"))
        XCTAssertTrue(root.exists("app/public/fonts/fa-solid-900.ttf"), "Unflagged files stay")
        XCTAssertTrue(root.exists("app/.gitignore"), "Manual-fix findings are never removed")
    }
}
