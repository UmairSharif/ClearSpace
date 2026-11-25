import Foundation

/// Looks in the home folder for files that the "Contagious Interview" malware family
/// leaves behind after it has run, and for login items that start a script interpreter
/// from a hidden folder. Read-only.
enum HostThreatScanner {
    struct KnownArtifact: Sendable {
        let relativePath: String
        let level: ThreatLevel
        let reason: String
    }

    /// Paths published in public analyses of this campaign (Security Alliance, January 2026,
    /// and earlier BeaverTail and InvisibleFerret reports).
    static let knownArtifacts: [KnownArtifact] = [
        KnownArtifact(relativePath: ".n2", level: .high,
                      reason: "This hidden folder is where the Python remote-access tool of this malware family is stored (files named way, pow or flist)."),
        KnownArtifact(relativePath: ".n3", level: .high,
                      reason: "This hidden folder is where this malware family stages stolen wallet and browser files (tp0, tp1 and so on)."),
        KnownArtifact(relativePath: ".nlp", level: .high,
                      reason: "This file is the Python stager this malware family downloads."),
        KnownArtifact(relativePath: ".npl", level: .medium,
                      reason: "Earlier versions of this malware family saved their Python backdoor under this name."),
        KnownArtifact(relativePath: ".pyp", level: .medium,
                      reason: "Earlier versions of this malware family downloaded a private copy of Python into this folder."),
        KnownArtifact(relativePath: ".npm/vhost.ctl", level: .high,
                      reason: "This lock file is written by the Node.js part of this malware family while it runs. It is not created by npm."),
        KnownArtifact(relativePath: ".npm/npm-compiler.log", level: .high,
                      reason: "This file is written by the Node.js part of this malware family. It is not created by npm."),
        KnownArtifact(relativePath: ".npm/npm-compiler.main", level: .high,
                      reason: "This file is written by the Node.js part of this malware family. It is not created by npm."),
        KnownArtifact(relativePath: ".local/bin/py", level: .medium,
                      reason: "Later stages of the PolinRider malware install a Python launcher here. Remove it unless you put it there yourself.")
    ]

    /// Files the PolinRider "npm-ws" stage keeps in a hidden `~/.node_modules` folder.
    static let npmWorkspaceFiles = [".npm-ws.json", ".npm-ws-runner.js", ".npm-ws.pid", ".npm-ws.log"]

    /// Shell startup files that run in every new terminal.
    static let shellStartupFiles = [".zshrc", ".zprofile", ".zshenv", ".zlogin", ".bashrc", ".bash_profile", ".profile"]

    /// Strings in a shell startup line that point at this malware family.
    static let shellMarkers = ["/.n2/", "/.n3/", "/.nlp", "/.npl", "/.pyp/", "scoped_dir", ".npm-ws", "#ghc2", "npm-compiler"]

    /// Prefix of the folders the Node.js stage unpacks into, such as `~/.npm/scoped_dir6760_1736...`.
    static let scopedDirPrefix = "scoped_dir"

    static func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        systemRoot: URL = URL(fileURLWithPath: "/")
    ) async -> [ThreatFinding] {
        scanSync(home: home, systemRoot: systemRoot)
    }

    /// `systemRoot` is where `/Applications` and `/opt/homebrew` are looked up. Tests pass
    /// a temporary folder.
    static func scanSync(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        systemRoot: URL = URL(fileURLWithPath: "/")
    ) -> [ThreatFinding] {
        let fileManager = FileManager.default
        var findings: [ThreatFinding] = []

        for artifact in knownArtifacts {
            let url = home.appendingPathComponent(artifact.relativePath)
            guard fileManager.fileExists(atPath: url.path) || SafetyGuard.isSymbolicLink(url) else { continue }
            findings.append(finding(url, kind: .hostArtifact, level: artifact.level, reasons: [artifact.reason, nextSteps]))
        }

        let npm = home.appendingPathComponent(".npm", isDirectory: true)
        if let children = try? fileManager.contentsOfDirectory(at: npm, includingPropertiesForKeys: nil) {
            for child in children where child.lastPathComponent.hasPrefix(scopedDirPrefix) {
                findings.append(finding(child, kind: .hostArtifact, level: .high, reasons: [
                    "Folders named scoped_dir… inside ~/.npm are where this malware family unpacks its Node.js stage (main.js and its own node_modules). npm does not create them.",
                    nextSteps
                ]))
            }
        }

        let hiddenModules = home.appendingPathComponent(".node_modules", isDirectory: true)
        let workspaceFiles = npmWorkspaceFiles.filter {
            fileManager.fileExists(atPath: hiddenModules.appendingPathComponent($0).path)
        }
        if !workspaceFiles.isEmpty {
            findings.append(finding(hiddenModules, kind: .hostArtifact, level: .high, reasons: [
                "This hidden folder holds \(workspaceFiles.joined(separator: ", ")), the files of the PolinRider \"npm-ws\" stage that keeps the malware running.",
                nextSteps
            ]))
        }

        if Task.isCancelled { return [] }
        findings += launchAgentFindings(home: home)
        findings += shellStartupFindings(home: home)
        findings += patchedToolFindings(home: home, systemRoot: systemRoot)
        return ThreatScanner.sorted(findings)
    }

    /// Login items in `~/Library/LaunchAgents` that run an interpreter on a file in a
    /// hidden folder of the home folder, or run inline code.
    static func launchAgentFindings(home: URL) -> [ThreatFinding] {
        let folder = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        guard let plists = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }

        var findings: [ThreatFinding] = []
        for plist in plists where plist.pathExtension == "plist" {
            guard let data = ThreatScanner.read(plist, limit: 256 * 1024),
                  let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { continue }

            var arguments = (object["ProgramArguments"] as? [String]) ?? []
            if let program = object["Program"] as? String, arguments.first != program {
                arguments.insert(program, at: 0)
            }
            guard let first = arguments.first,
                  ThreatHeuristics.interpreters.contains((first as NSString).lastPathComponent.lowercased())
            else { continue }

            // The same home can be spelled with or without /private (in temporary folders)
            // or through a link, so compare against every spelling.
            let homePaths = Set([home.path, home.standardizedFileURL.path, home.resolvingSymlinksInPath().path])
            let hiddenScript = arguments.dropFirst().first { argument in
                homePaths.contains { homePath in
                    guard argument.hasPrefix(homePath + "/") else { return false }
                    let relative = argument.dropFirst(homePath.count + 1)
                    return relative.split(separator: "/").contains { $0.hasPrefix(".") }
                }
            }
            let inline = arguments.contains { ["-e", "-c", "--eval"].contains($0) }
            guard hiddenScript != nil || inline else { continue }

            let known = arguments.contains { argument in
                knownArtifacts.contains { argument.hasPrefix(home.appendingPathComponent($0.relativePath).path) }
                    || argument.contains("/.npm/\(scopedDirPrefix)")
            }

            var reasons: [String] = []
            if let hiddenScript {
                reasons.append("Starts \((first as NSString).lastPathComponent) at every login and runs \(hiddenScript.abbreviatingHome), which is inside a hidden folder.")
            } else {
                reasons.append("Starts \((first as NSString).lastPathComponent) at every login with code written directly in the login item.")
            }
            if known {
                reasons.append("The file it runs matches a path used by known malware.")
            }
            reasons.append("Removing this file stops it from starting again. Log out or restart afterwards to stop a copy that is already running.")

            findings.append(finding(
                plist,
                kind: .launchAgent,
                level: known ? .high : .medium,
                reasons: reasons,
                evidence: arguments.joined(separator: " ").prefix(200).description
            ))
        }
        return findings
    }

    /// Lines in shell startup files that start this malware. The file itself is kept:
    /// it holds the user's own settings, so the fix is to delete the line.
    static func shellStartupFindings(home: URL) -> [ThreatFinding] {
        var findings: [ThreatFinding] = []
        for name in shellStartupFiles {
            let url = home.appendingPathComponent(name)
            guard let data = ThreatScanner.read(url, limit: 1024 * 1024),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }

            let lines = text.components(separatedBy: .newlines)
            let matches = lines.enumerated().filter { _, line in
                shellMarkers.contains { line.contains($0) } || ThreatHeuristics.knownMarkers.contains { line.contains($0) }
            }
            guard !matches.isEmpty else { continue }

            let numbers = matches.map { String($0.offset + 1) }.joined(separator: ", ")
            findings.append(finding(
                url,
                kind: .shellStartup,
                level: .high,
                reasons: [
                    "\(name) has \(matches.count == 1 ? "a line" : "lines") that \(matches.count == 1 ? "points" : "point") at files used by this malware family, so it would start again in every new terminal.",
                    nextSteps
                ],
                evidence: matches.map { $0.element }.joined(separator: "\n").prefix(400).description,
                manualFix: "Open ~/\(name) in a text editor and delete line \(numbers). Keep the rest of the file, then open a new terminal."
            ))
        }
        return findings
    }

    /// npm and editors whose own JavaScript was changed to load the malware at start-up.
    /// They are replaced by reinstalling, never by deleting files inside them.
    static func patchedToolFindings(home: URL, systemRoot: URL) -> [ThreatFinding] {
        let fileManager = FileManager.default
        var candidates: [(url: URL, tool: String, fix: String)] = []

        let npmFix = "Reinstall Node.js so npm is replaced with a clean copy, for example with brew reinstall node, or by reinstalling the version in nvm or Volta."
        for prefix in ["opt/homebrew", "usr/local"] {
            candidates.append((systemRoot.appendingPathComponent("\(prefix)/lib/node_modules/npm/lib/cli.js"), "npm", npmFix))
        }
        for manager in [".nvm/versions/node", ".volta/tools/image/node"] {
            let base = home.appendingPathComponent(manager, isDirectory: true)
            for version in (try? fileManager.contentsOfDirectory(atPath: base.path)) ?? [] {
                candidates.append((base.appendingPathComponent("\(version)/lib/node_modules/npm/lib/cli.js"), "npm \(version)", npmFix))
            }
        }
        for app in ["Visual Studio Code", "Cursor"] {
            candidates.append((
                systemRoot.appendingPathComponent("Applications/\(app).app/Contents/Resources/app/out/main.js"),
                app,
                "Delete \(app) and download a fresh copy from its official website."
            ))
        }

        let markers = ThreatHeuristics.knownMarkers + ["M260630A"]
        var findings: [ThreatFinding] = []
        for candidate in candidates {
            guard let data = ThreatScanner.read(candidate.url, limit: 16 * 1024 * 1024),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }
            let found = markers.filter { text.contains($0) }
            guard !found.isEmpty else { continue }

            findings.append(ThreatFinding(
                url: candidate.url,
                kind: .patchedTool,
                level: .high,
                project: "This Mac",
                reasons: [
                    "\(candidate.tool) was modified to load malware every time it starts. It contains \(found.joined(separator: ", ")).",
                    nextSteps
                ],
                evidence: nil,
                relatedURLs: [],
                size: 0,
                manualFix: candidate.fix
            ))
        }
        return findings
    }

    private static let nextSteps = "If this is on your Mac, the malware has probably run. After removing it, restart, and change passwords, tokens and keys from a clean device. See the cleanup guide for the full list."

    private static func finding(
        _ url: URL,
        kind: ThreatKind,
        level: ThreatLevel,
        reasons: [String],
        evidence: String? = nil,
        manualFix: String? = nil
    ) -> ThreatFinding {
        ThreatFinding(
            url: url,
            kind: kind,
            level: level,
            project: "This Mac",
            reasons: reasons,
            evidence: evidence,
            relatedURLs: [],
            size: manualFix == nil ? SizeCalculator.allocatedSize(of: url) : 0,
            manualFix: manualFix
        )
    }
}
