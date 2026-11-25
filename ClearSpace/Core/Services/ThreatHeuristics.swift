import Foundation

/// Static checks that recognise how developer-targeting malware hides inside projects.
///
/// Everything here only reads text that was already loaded. Nothing is executed,
/// evaluated or sent anywhere. The checks are modelled on the "fake font" campaign
/// that reached this repository: a VS Code task set to run on folder open executes
/// `node` on a `.ttf` file that is really obfuscated JavaScript.
enum ThreatHeuristics {
    /// Extensions for binary media. A file with one of these that is actually readable
    /// script text is the core trick of the campaign.
    static let mediaExtensions: Set<String> = [
        "ttf", "otf", "woff", "woff2", "eot", "orc",
        "png", "jpg", "jpeg", "gif", "ico", "icns", "webp", "bmp", "tif", "tiff",
        "pdf", "mp3", "mp4", "mov", "wav", "m4a"
    ]

    /// Source files checked for obfuscation and for code hidden after long runs of spaces.
    static let scriptExtensions: Set<String> = ["js", "cjs", "mjs", "jsx", "ts", "tsx"]

    /// Programs that run a script file given as an argument.
    static let interpreters: Set<String> = [
        "node", "nodejs", "deno", "bun", "npx",
        "python", "python2", "python3",
        "sh", "bash", "zsh", "perl", "ruby", "osascript",
        "pwsh", "powershell", "cmd", "wscript", "cscript"
    ]

    /// Strings that appear in published samples of this campaign (PolinRider and the
    /// fake-font loaders) and are rare in ordinary code. From static analysis of the
    /// payload removed from this repository and from public reports.
    static let knownMarkers: [String] = [
        "global['r']=require",
        "global['m']=module",
        "global['_V']",
        "global['!']",
        "x-payload-b64",
        "0x1eEf0849EDa15d87f64e51C73C8442Cf3c8bCEF3",
        "0x1eef0849eda15d87f64e51c73c8442cf3c8bcef3",
        "q4FZkxX{!h,Sr3=@",
        "y-p_>d$0B&@^1aQk",
        "NPM_WS_SHIM"
    ]

    /// Helper files this malware family writes into projects so it can commit and push
    /// itself, and lists in `.gitignore` so Git does not show them.
    static let propagationFileNames: Set<String> = [
        "temp_auto_push.bat", "temp_interactive_push.bat", "branch_structure.json", "config.bat"
    ]

    /// The `.gitignore` lines that hide those helper files.
    static func suspiciousIgnoreEntries(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { propagationFileNames.contains($0.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) }
    }

    // MARK: - Content

    /// Whether `data` looks like readable text rather than binary file data. Real fonts and
    /// images contain NUL bytes in their headers, so they fail this quickly.
    static func looksLikeText(_ data: Data) -> Bool {
        let sample = data.prefix(64 * 1024)
        guard sample.count >= 32 else { return false }
        var printable = 0
        for byte in sample {
            if byte == 0 { return false }
            if byte == 0x09 || byte == 0x0A || byte == 0x0D || (0x20...0x7E).contains(byte) || byte >= 0x80 {
                printable += 1
            }
        }
        return Double(printable) / Double(sample.count) >= 0.95
    }

    /// Git LFS stores large media as small text pointers, which must not be flagged.
    static func isLFSPointer(_ text: String) -> Bool {
        text.hasPrefix("version https://git-lfs.github.com/spec/")
    }

    /// The script language `text` appears to be written in, or nil if it reads as prose,
    /// markup or data.
    static func scriptLanguage(_ text: String) -> String? {
        let head = String(text.prefix(64 * 1024))
        if head.hasPrefix("#!") { return "shell script" }
        if head.hasPrefix("try{}catch") { return "JavaScript" }

        let jsTokens = [
            "function", "require(", "=>", "var ", "const ", "let ", "eval(", "module.exports",
            "process.", "child_process", "global[", "TextDecoder", "parseInt(", "Function(", "return "
        ]
        if jsTokens.filter({ head.contains($0) }).count >= 3 { return "JavaScript" }

        let pyTokens = ["import ", "def ", "exec(", "base64.b64decode", "__name__", "subprocess"]
        if pyTokens.filter({ head.contains($0) }).count >= 2 { return "Python" }
        return nil
    }

    /// Signs that a script was written to be unreadable. `strong` signs are rare in
    /// hand-written or merely minified code. `weak` ones only add context.
    static func obfuscationSignals(_ text: String) -> (strong: [String], weak: [String]) {
        var strong: [String] = []
        var weak: [String] = []
        let length = max(text.utf16.count, 1)

        let hexNames = count(#"_0x[0-9a-fA-F]{4,}"#, in: text)
        if hexNames >= 30 {
            strong.append("Uses \(hexNames) machine-generated names such as _0x5dfb, which is what JavaScript obfuscators produce.")
        }

        let hexLiterals = count(#"\b0x[0-9a-fA-F]+\b"#, in: text)
        let hexParses = count(#"parseInt\(\s*-?0x"#, in: text)
        if hexParses >= 20 || (hexLiterals >= 100 && hexLiterals * 200 >= length) {
            strong.append("Hides its numbers and strings behind \(hexLiterals) hex calculations, a common way to stop people from reading the code.")
        }

        let escapes = count(#"\\x[0-9a-fA-F]{2}"#, in: text)
        if escapes >= 200 {
            strong.append("Contains \(escapes) escaped characters that hide readable text.")
        }

        let runsCode = count(#"\b(eval|Function)\s*\("#, in: text) > 0 || text.contains("Function.constructor")
        let decodes = ["atob(", "Buffer.from(", "fromCharCode", "TextDecoder", "base64"].contains { text.contains($0) }
        if text.contains("Function.constructor") || (runsCode && decodes) {
            strong.append("Decodes hidden text and runs it as code while the program runs.")
        }

        let markers = knownMarkers.filter { text.contains($0) }
        if !markers.isEmpty {
            strong.append("Contains \(markers.prefix(3).joined(separator: ", ")), \(markers.count == 1 ? "a string" : "strings") found in known samples of this malware family.")
        }

        let longest = text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.utf16.count }.max() ?? 0
        let whitespace = text.unicodeScalars.filter { CharacterSet.whitespacesAndNewlines.contains($0) }.count
        if longest >= 5000, Double(whitespace) / Double(length) < 0.02 {
            weak.append("Almost all of the code is on one line of \(longest) characters with almost no spaces.")
        }

        return (strong, weak)
    }

    /// Finds code placed after a long run of spaces, which pushes it past the right edge
    /// of the editor so a reviewer does not see it. Returns the start of the hidden code.
    static func hiddenCode(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"[ \t]{150,}(\S[^\n]{0,79})"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    // MARK: - Commands

    /// What a shell command does that is suspicious. `strong` reasons describe behaviour
    /// typical of malware loaders. `referencedFiles` are the paths the command runs.
    struct CommandAnalysis: Equatable {
        var strong: [String] = []
        var weak: [String] = []
        var referencedFiles: [String] = []
    }

    static func analyzeCommand(_ command: String) -> CommandAnalysis {
        var result = CommandAnalysis()
        let tokens = tokenize(command)
        let interpreter = tokens.first { interpreters.contains(programName($0)) }.map(programName)

        for token in tokens {
            let ext = (token as NSString).pathExtension.lowercased()
            if mediaExtensions.contains(ext) {
                result.referencedFiles.append(token)
                if let interpreter {
                    result.strong.append("Runs \(token) with \(interpreter), but the file is named like a .\(ext) file, not a script.")
                }
            } else if scriptExtensions.contains(ext) || ["py", "sh"].contains(ext) {
                result.referencedFiles.append(token)
            }
        }

        let lower = command.lowercased()
        let downloads = ["curl ", "wget ", "invoke-webrequest", "iwr ", "irm "].contains { lower.contains($0) }
        let pipesToShell = count(#"\|\s*(sudo\s+)?(ba|z)?sh\b|\|\s*node\b|\|\s*python3?\b|\|\s*iex\b|invoke-expression"#, in: lower) > 0
        if downloads && pipesToShell {
            result.strong.append("Downloads code from the internet and runs it straight away.")
        } else if downloads {
            result.weak.append("Downloads something from the internet.")
        }

        if let inline = inlineCode(tokens), inline.count >= 150 {
            result.weak.append("Runs \(inline.count) characters of code written directly in the command.")
        }
        if lower.contains("base64") {
            result.weak.append("Decodes base64 data, which can hide what is being run.")
        }
        return result
    }

    /// Splits a command line into words, keeping quoted parts together.
    static func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        for character in command {
            if let open = quote {
                if character == open { quote = nil } else { current.append(character) }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace || character == ";" || character == "&" || character == "|" {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func programName(_ token: String) -> String {
        var name = (token as NSString).lastPathComponent.lowercased()
        if name.hasSuffix(".exe") { name = String(name.dropLast(4)) }
        return name
    }

    private static func inlineCode(_ tokens: [String]) -> String? {
        for (index, token) in tokens.enumerated() where ["-e", "-c", "--eval", "-p"].contains(token) {
            guard index > 0, interpreters.contains(programName(tokens[index - 1])), index + 1 < tokens.count else { continue }
            return tokens[index + 1]
        }
        return nil
    }

    // MARK: - VS Code files

    struct Verdict: Equatable {
        var level: ThreatLevel
        var reasons: [String]
        var referencedFiles: [String] = []
        var evidence: String?
    }

    /// Checks the tasks in a `tasks.json`, or the `tasks` key of a settings or workspace file.
    static func analyzeTasks(in object: [String: Any]) -> Verdict? {
        let tasks: [[String: Any]]
        if let list = object["tasks"] as? [[String: Any]] {
            tasks = list
        } else if let single = object["tasks"] as? [String: Any] {
            tasks = (single["tasks"] as? [[String: Any]]) ?? [single]
        } else {
            return nil
        }

        var level: ThreatLevel?
        var reasons: [String] = []
        var files: [String] = []
        var evidence: String?

        for task in tasks {
            let label = (task["label"] as? String) ?? (task["taskName"] as? String) ?? "Unnamed task"
            let runOn = ((task["runOptions"] as? [String: Any])?["runOn"] as? String) ?? (task["runOn"] as? String)
            let autoRun = runOn?.lowercased() == "folderopen"
            let presentation = task["presentation"] as? [String: Any]
            let hidden = (task["hide"] as? Bool) == true
                || (presentation?["reveal"] as? String)?.lowercased() == "never"
                || (presentation?["echo"] as? Bool) == false

            let command = commandLine(of: task)
            let analysis = analyzeCommand(command)
            files += analysis.referencedFiles

            var taskReasons: [String] = []
            if autoRun {
                taskReasons.append("The task \"\(label)\" runs by itself as soon as the folder is opened in VS Code or Cursor.")
            }
            taskReasons += analysis.strong
            if hidden && (autoRun || !analysis.strong.isEmpty) {
                taskReasons.append("It is set to stay hidden: no terminal is shown and the command is not echoed.")
            }
            if autoRun || !analysis.strong.isEmpty {
                taskReasons += analysis.weak
            }

            let taskLevel: ThreatLevel?
            if autoRun && (!analysis.strong.isEmpty || hidden) {
                taskLevel = .high
            } else if autoRun || !analysis.strong.isEmpty {
                taskLevel = .medium
            } else {
                taskLevel = nil
            }

            if let taskLevel {
                level = max(level ?? taskLevel, taskLevel)
                reasons += taskReasons
                if evidence == nil, !command.isEmpty {
                    evidence = String(command.prefix(200))
                }
            }
        }

        guard let level, !reasons.isEmpty else { return nil }
        return Verdict(level: level, reasons: reasons, referencedFiles: files, evidence: evidence)
    }

    /// Checks editor settings that let tasks run unattended or hide them.
    static func analyzeSettings(_ object: [String: Any]) -> Verdict? {
        let settings = (object["settings"] as? [String: Any]) ?? object
        var reasons: [String] = []
        var level: ThreatLevel = .low

        let automatic = settings["task.allowAutomaticTasks"]
        let allowsAutomatic = (automatic as? Bool) == true || (automatic as? String)?.lowercased() == "on"
        if allowsAutomatic {
            reasons.append("Allows tasks to run automatically when the folder opens, without asking you first.")
            level = .medium
        }

        let hidesTerminal = (settings["terminal.integrated.hideOnStartup"] as? String)?.lowercased() == "always"
        if hidesTerminal {
            reasons.append("Hides the terminal when the editor starts, so a running task is easy to miss.")
        }

        if (settings["security.workspace.trust.enabled"] as? Bool) == false {
            reasons.append("Tries to turn off Workspace Trust, which normally stops tasks in folders you have not trusted.")
            level = max(level, .medium)
        }

        if allowsAutomatic && hidesTerminal {
            level = .high
        }

        if let tasks = analyzeTasks(in: settings) {
            reasons += tasks.reasons
            level = max(level, tasks.level)
            return Verdict(level: level, reasons: reasons, referencedFiles: tasks.referencedFiles, evidence: tasks.evidence)
        }

        guard !reasons.isEmpty else { return nil }
        return Verdict(level: level, reasons: reasons)
    }

    /// Checks npm lifecycle scripts, which run on `npm install` without being asked.
    static func analyzePackageScripts(_ object: [String: Any]) -> Verdict? {
        guard let scripts = object["scripts"] as? [String: Any] else { return nil }
        let lifecycle = ["preinstall", "install", "postinstall", "prepare", "preprepare", "postprepare", "prepublish"]

        var level: ThreatLevel?
        var reasons: [String] = []
        var files: [String] = []
        var evidence: String?

        for key in lifecycle {
            guard let command = scripts[key] as? String else { continue }
            let analysis = analyzeCommand(command)
            files += analysis.referencedFiles
            let scriptLevel: ThreatLevel? = !analysis.strong.isEmpty ? .high : (!analysis.weak.isEmpty ? .medium : nil)
            guard let scriptLevel else { continue }
            level = max(level ?? scriptLevel, scriptLevel)
            reasons.append("The \"\(key)\" script runs automatically during npm install.")
            reasons += analysis.strong + analysis.weak
            if evidence == nil { evidence = String(command.prefix(200)) }
        }

        guard let level else { return nil }
        return Verdict(level: level, reasons: reasons, referencedFiles: files, evidence: evidence)
    }

    /// The full command a task runs, including platform-specific overrides.
    static func commandLine(of task: [String: Any]) -> String {
        func text(_ value: Any?) -> [String] {
            if let string = value as? String { return [string] }
            if let dict = value as? [String: Any], let string = dict["value"] as? String { return [string] }
            if let list = value as? [Any] { return list.flatMap { text($0) } }
            return []
        }

        var parts = text(task["command"]) + text(task["args"])
        for platform in ["osx", "linux", "windows"] {
            if let override = task[platform] as? [String: Any] {
                parts += text(override["command"]) + text(override["args"])
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    static func count(_ pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
