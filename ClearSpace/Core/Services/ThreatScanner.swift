import Foundation

/// Walks a projects folder looking for hidden malware such as auto-run editor tasks and
/// scripts disguised as fonts. Read-only: files are opened for reading, size-capped, and
/// never executed.
enum ThreatScanner {
    /// Large dependency and build folders. Skipping them keeps the scan fast. Malware
    /// in this campaign is committed into project source, not into these folders.
    private static let skippedFolders: Set<String> = [
        ".git", "node_modules", ".Trash", "Library", "Applications",
        "DerivedData", "Pods", ".build", ".gradle", ".dart_tool", ".next",
        ".cache", ".npm", ".yarn", ".pnpm-store", ".cargo", ".rustup"
    ]
    private static let skippedFolderExtensions: Set<String> = [
        "app", "photoslibrary", "musiclibrary", "tvlibrary", "xcarchive", "sparsebundle"
    ]

    private static let maximumScriptBytes = 4 * 1024 * 1024
    private static let maximumMediaBytes: Int64 = 20 * 1024 * 1024
    private static let maximumJSONBytes = 1024 * 1024

    static func scan(root: URL) async -> [ThreatFinding] {
        scanSync(root: root)
    }

    static func scanSync(root: URL) -> [ThreatFinding] {
        let root = root.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var findings: [ThreatFinding] = []
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]) else { continue }

            if values.isDirectory == true {
                let name = url.lastPathComponent
                if skippedFolders.contains(name) || skippedFolderExtensions.contains(url.pathExtension.lowercased()) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }

            if let finding = inspect(file: url, size: Int64(values.fileSize ?? 0), root: root) {
                findings.append(finding)
            }
        }

        return sorted(findings)
    }

    /// Highest level first, then by project and path, so the worst items lead the list.
    static func sorted(_ findings: [ThreatFinding]) -> [ThreatFinding] {
        findings.sorted {
            if $0.level != $1.level { return $0.level > $1.level }
            if $0.project != $1.project { return $0.project.localizedStandardCompare($1.project) == .orderedAscending }
            return $0.url.path < $1.url.path
        }
    }

    /// Checks one file. Exposed for tests.
    static func inspect(file url: URL, size: Int64, root: URL) -> ThreatFinding? {
        let name = url.lastPathComponent
        let parentName = url.deletingLastPathComponent().lastPathComponent
        let ext = url.pathExtension.lowercased()

        if parentName == ".vscode", name == "tasks.json" {
            return jsonFinding(url, size: size, root: root, kind: .autoRunTask) { ThreatHeuristics.analyzeTasks(in: $0) }
        }
        if parentName == ".vscode", name == "settings.json" {
            return jsonFinding(url, size: size, root: root, kind: .editorSettings) { ThreatHeuristics.analyzeSettings($0) }
        }
        if ext == "code-workspace" {
            return jsonFinding(url, size: size, root: root, kind: .autoRunTask) { object in
                let tasks = ThreatHeuristics.analyzeTasks(in: object)
                // Workspace settings live under "settings"; tasks were already checked above.
                let settings = (object["settings"] as? [String: Any]).flatMap { ThreatHeuristics.analyzeSettings(["settings": $0]) }
                switch (tasks, settings) {
                case let (tasks?, settings?):
                    return ThreatHeuristics.Verdict(
                        level: max(tasks.level, settings.level),
                        reasons: tasks.reasons + settings.reasons,
                        referencedFiles: tasks.referencedFiles + settings.referencedFiles,
                        evidence: tasks.evidence ?? settings.evidence
                    )
                default:
                    return tasks ?? settings
                }
            }
        }
        if name == "package.json" {
            return jsonFinding(url, size: size, root: root, kind: .installScript) { ThreatHeuristics.analyzePackageScripts($0) }
        }
        if name == ".gitignore" {
            return gitignoreFinding(url, size: size, root: root)
        }
        if ThreatHeuristics.propagationFileNames.contains(name) {
            return propagationFinding(url, size: size, root: root)
        }
        if ThreatHeuristics.mediaExtensions.contains(ext) {
            return disguisedScriptFinding(url, size: size, root: root)
        }
        if ThreatHeuristics.scriptExtensions.contains(ext) {
            return scriptFinding(url, size: size, root: root)
        }
        return nil
    }

    // MARK: - Checks

    private static func jsonFinding(
        _ url: URL,
        size: Int64,
        root: URL,
        kind: ThreatKind,
        analyze: ([String: Any]) -> ThreatHeuristics.Verdict?
    ) -> ThreatFinding? {
        guard size <= maximumJSONBytes,
              let data = read(url, limit: maximumJSONBytes),
              let object = JSONC.object(from: data),
              let verdict = analyze(object)
        else { return nil }

        // Paths in tasks are relative to the project folder, the parent of `.vscode`.
        let base = url.deletingLastPathComponent().lastPathComponent == ".vscode"
            ? url.deletingLastPathComponent().deletingLastPathComponent()
            : url.deletingLastPathComponent()
        let related = verdict.referencedFiles.compactMap { resolve($0, base: base, root: root) }

        var reasons = verdict.reasons
        if !related.isEmpty {
            let basePath = base.standardizedFileURL.path + "/"
            let names = related.map { $0.path.replacingOccurrences(of: basePath, with: "") }
            reasons.append("Points at \(names.joined(separator: ", ")). Review that file too.")
        }

        return ThreatFinding(
            url: url,
            kind: kind,
            level: verdict.level,
            project: projectName(for: url, root: root),
            reasons: reasons,
            evidence: verdict.evidence,
            relatedURLs: related,
            size: size
        )
    }

    private static func disguisedScriptFinding(_ url: URL, size: Int64, root: URL) -> ThreatFinding? {
        guard size > 0, size <= maximumMediaBytes,
              let head = read(url, limit: 64 * 1024),
              ThreatHeuristics.looksLikeText(head),
              let headText = String(data: head, encoding: .utf8) ?? String(data: head, encoding: .isoLatin1),
              !ThreatHeuristics.isLFSPointer(headText),
              let language = ThreatHeuristics.scriptLanguage(headText)
        else { return nil }

        let ext = url.pathExtension.lowercased()
        var reasons = [
            "Named like a .\(ext) file, but it contains \(language) code instead of \(mediaNoun(ext)) data.",
            "Known attacks hide their payload this way and start it from an editor task or install script."
        ]
        if let full = read(url, limit: maximumScriptBytes),
           let text = String(data: full, encoding: .utf8) ?? String(data: full, encoding: .isoLatin1) {
            let signals = ThreatHeuristics.obfuscationSignals(text)
            reasons += signals.strong + signals.weak
        }

        return ThreatFinding(
            url: url,
            kind: .disguisedScript,
            level: .high,
            project: projectName(for: url, root: root),
            reasons: reasons,
            evidence: excerpt(headText),
            relatedURLs: [],
            size: size
        )
    }

    private static func scriptFinding(_ url: URL, size: Int64, root: URL) -> ThreatFinding? {
        guard size > 0, size <= Int64(maximumScriptBytes),
              let data = read(url, limit: maximumScriptBytes),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }

        let signals = ThreatHeuristics.obfuscationSignals(text)
        let hidden = ThreatHeuristics.hiddenCode(in: text)

        if let hidden {
            var reasons = ["Code is pushed far to the right after a long run of spaces, so an editor shows the line as empty or ends it early."]
            reasons += signals.strong + signals.weak
            let dangerous = !signals.strong.isEmpty
                || ["eval", "Function", "require", "global[", "child_process", "atob"].contains { hidden.contains($0) }
            return ThreatFinding(
                url: url,
                kind: .hiddenCode,
                level: dangerous ? .high : .medium,
                project: projectName(for: url, root: root),
                reasons: reasons,
                evidence: hidden,
                relatedURLs: [],
                size: size
            )
        }

        guard !signals.strong.isEmpty else { return nil }
        return ThreatFinding(
            url: url,
            kind: .obfuscatedScript,
            level: signals.strong.count >= 2 ? .high : .medium,
            project: projectName(for: url, root: root),
            reasons: signals.strong + signals.weak
                + ["Some libraries ship obfuscated on purpose. If you did not add this file, treat it as suspicious."],
            evidence: excerpt(text),
            relatedURLs: [],
            size: size
        )
    }

    private static func gitignoreFinding(_ url: URL, size: Int64, root: URL) -> ThreatFinding? {
        guard size <= maximumJSONBytes,
              let data = read(url, limit: maximumJSONBytes),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        let entries = ThreatHeuristics.suspiciousIgnoreEntries(text)
        guard !entries.isEmpty else { return nil }

        let pushScripts = entries.contains { $0.contains("push") }
        return ThreatFinding(
            url: url,
            kind: .gitignoreEntries,
            level: pushScripts ? .medium : .low,
            project: projectName(for: url, root: root),
            reasons: [
                "Ignores \(entries.joined(separator: ", ")). This malware family adds these lines so Git does not show the helper files it uses to commit and push itself.",
                "If you did not add these lines yourself, the project was probably modified by malware on a computer that had it checked out."
            ],
            evidence: entries.joined(separator: "\n"),
            relatedURLs: [],
            size: size,
            manualFix: "Open .gitignore and delete the lines \(entries.joined(separator: ", ")). Keep the rest of the file."
        )
    }

    private static func propagationFinding(_ url: URL, size: Int64, root: URL) -> ThreatFinding? {
        let name = url.lastPathComponent
        let pushScript = name.contains("push")
        return ThreatFinding(
            url: url,
            kind: .propagationScript,
            level: pushScript ? .high : .medium,
            project: projectName(for: url, root: root),
            reasons: [
                pushScript
                    ? "\(name) is a helper script this malware family writes into projects to commit and push itself to the remote repository."
                    : "\(name) is a file name this malware family uses for its helper files. It may be harmless if you created it.",
                "Check the project's recent commits and pushes for changes you did not make."
            ],
            evidence: nil,
            relatedURLs: [],
            size: size
        )
    }

    // MARK: - Helpers

    /// Reads at most `limit` bytes without loading huge files into memory.
    static func read(_ url: URL, limit: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: limit)
    }

    /// Resolves a path from a task or script, keeping only files that exist inside `root`.
    static func resolve(_ reference: String, base: URL, root: URL) -> URL? {
        var path = reference
        for variable in ["${workspaceFolder}", "${workspaceRoot}", "${fileWorkspaceFolder}"] {
            path = path.replacingOccurrences(of: variable, with: base.path)
        }
        guard !path.contains("${") else { return nil }
        let url = path.hasPrefix("/")
            ? URL(fileURLWithPath: path).standardizedFileURL
            : base.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/"),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    /// The nearest folder above `url` that looks like a project, or the top folder inside `root`.
    static func projectName(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        var folder = url.deletingLastPathComponent().standardizedFileURL
        if folder.lastPathComponent == ".vscode" { folder.deleteLastPathComponent() }

        var candidate = folder
        while candidate.path.hasPrefix(rootPath), candidate.path.count >= rootPath.count {
            for marker in [".git", "package.json", "Package.swift", "pubspec.yaml"] where
                FileManager.default.fileExists(atPath: candidate.appendingPathComponent(marker).path) {
                return candidate.lastPathComponent
            }
            if candidate.path == rootPath { break }
            candidate.deleteLastPathComponent()
        }

        let relative = folder.path.dropFirst(rootPath.count).split(separator: "/")
        return relative.first.map(String.init) ?? root.lastPathComponent
    }

    private static func excerpt(_ text: String) -> String {
        let trimmed = text.prefix(160).replacingOccurrences(of: "\n", with: " ")
        return text.count > 160 ? trimmed + "…" : trimmed
    }

    private static func mediaNoun(_ ext: String) -> String {
        switch ext {
        case "ttf", "otf", "woff", "woff2", "eot": "font"
        case "pdf": "PDF"
        case "mp3", "wav", "m4a": "audio"
        case "mp4", "mov": "video"
        case "orc": "binary"
        default: "image"
        }
    }
}
