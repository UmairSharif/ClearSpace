import XCTest
@testable import ClearSpace

/// Runs the "This Mac" checks against a temporary fake home and a fake system root, so
/// the real home folder, /Applications and /opt are never read.
final class HostThreatScannerTests: XCTestCase {
    private var home: TemporaryDirectory!
    private var system: TemporaryDirectory!

    override func setUpWithError() throws {
        home = try TemporaryDirectory()
        system = try TemporaryDirectory()
    }

    override func tearDown() {
        home = nil
        system = nil
    }

    private func scan() -> [ThreatFinding] {
        HostThreatScanner.scanSync(home: home.url, systemRoot: system.url)
    }

    private func names(_ findings: [ThreatFinding]) -> Set<String> {
        Set(findings.map(\.url.lastPathComponent))
    }

    func testCleanHomeHasNoFindings() throws {
        try home.makeFile(".npm/_cacache/index-v5/aa/bb")
        try home.makeFile(".local/bin/swiftlint")
        try home.write("export PATH=\"$HOME/.local/bin:$PATH\"\nalias gs='git status'\n", to: ".zshrc")
        try home.makeFile(".node_modules/lodash/index.js")
        XCTAssertTrue(scan().isEmpty, "\(scan().map(\.displayPath))")
    }

    func testFindsKnownLeftovers() throws {
        try home.makeFile(".n2/way")
        try home.makeFile(".n3/tp0")
        try home.makeFile(".npm/vhost.ctl")
        try home.makeFile(".npm/scoped_dir6760_1736900000/main.js")
        try home.makeFile(".node_modules/.npm-ws.pid")

        let findings = scan()
        XCTAssertEqual(names(findings), [".n2", ".n3", "vhost.ctl", "scoped_dir6760_1736900000", ".node_modules"])
        XCTAssertTrue(findings.allSatisfy { $0.level == .high && $0.project == "This Mac" && $0.isRemovable })
        XCTAssertTrue(findings.allSatisfy { $0.kind.isHostLevel })
    }

    func testLaunchAgentRunningHiddenScriptIsFlagged() throws {
        let plist: [String: Any] = [
            "Label": "com.system.update",
            "ProgramArguments": ["/usr/bin/python3", home.path(".n2/way").path],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try home.write(data, to: "Library/LaunchAgents/com.system.update.plist")

        let item = try XCTUnwrap(scan().first { $0.kind == .launchAgent })
        XCTAssertEqual(item.level, .high, "It runs a file from a known malware folder")
        XCTAssertTrue(item.isRemovable)
    }

    func testOrdinaryLaunchAgentIsNotFlagged() throws {
        let plist: [String: Any] = [
            "Label": "com.example.updater",
            "ProgramArguments": ["/Applications/Example.app/Contents/MacOS/updater", "--background"]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try home.write(data, to: "Library/LaunchAgents/com.example.updater.plist")
        XCTAssertTrue(scan().isEmpty)
    }

    func testShellStartupLineIsAManualFix() throws {
        try home.write("alias ll='ls -l'\nnohup node ~/.node_modules/.npm-ws-runner.js >/dev/null 2>&1 & #ghc2\n", to: ".zshrc")

        let item = try XCTUnwrap(scan().first { $0.kind == .shellStartup })
        XCTAssertEqual(item.level, .high)
        XCTAssertFalse(item.isRemovable, "~/.zshrc holds the user's own settings and must not be deleted")
        XCTAssertTrue(item.manualFix?.contains("line 2") == true)
    }

    func testPatchedNpmIsAManualFix() throws {
        try system.write("// npm cli\nconst NPM_WS_SHIM = 1;\n", to: "opt/homebrew/lib/node_modules/npm/lib/cli.js")
        try system.write("// clean editor\n", to: "Applications/Visual Studio Code.app/Contents/Resources/app/out/main.js")

        let findings = scan()
        XCTAssertEqual(findings.count, 1)
        let item = try XCTUnwrap(findings.first)
        XCTAssertEqual(item.kind, .patchedTool)
        XCTAssertFalse(item.isRemovable)
        XCTAssertTrue(item.manualFix?.contains("Reinstall Node.js") == true)
    }

    @MainActor
    func testDuplicatesFromOverlappingScansAreMerged() throws {
        try home.makeFile(".npm/vhost.ctl")
        let host = scan()
        let merged = ThreatScanViewModel.deduplicated(host + host)
        XCTAssertEqual(merged.count, host.count)
    }
}
