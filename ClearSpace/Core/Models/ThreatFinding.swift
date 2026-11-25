import Foundation

/// How strongly a finding points at malware. Findings come from heuristics, so even
/// `high` means "looks like known attacks", never "proven malicious".
enum ThreatLevel: Int, Comparable, CaseIterable, Hashable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var explanation: String {
        switch self {
        case .low: "Unusual, but often harmless. Worth a look."
        case .medium: "Matches part of a known attack pattern. Check it before you open the project in an editor."
        case .high: "Matches how known developer-targeting malware hides and runs itself. Do not open the project in an editor until it is removed."
        }
    }
}

/// What kind of indicator a finding is.
enum ThreatKind: String, CaseIterable, Hashable, Sendable {
    /// An editor task that runs by itself when the folder is opened.
    case autoRunTask
    /// Editor settings that let tasks run unattended or hide what they do.
    case editorSettings
    /// A script stored under a font, image or other media extension.
    case disguisedScript
    /// A script written to be unreadable (hex-encoded strings, runtime decoding).
    case obfuscatedScript
    /// Code pushed far to the right of a line so an editor does not show it.
    case hiddenCode
    /// A package install hook that runs a disguised file or downloads code.
    case installScript
    /// A helper script this malware family uses to commit and push itself into repositories.
    case propagationScript
    /// `.gitignore` lines that hide this malware family's helper files from Git.
    case gitignoreEntries
    /// A file or folder in the home folder that a known malware family creates.
    case hostArtifact
    /// A shell startup file (such as `~/.zshrc`) with a line that starts the malware.
    case shellStartup
    /// A developer tool whose own code was modified to start the malware.
    case patchedTool
    /// A login item that starts a script interpreter from a hidden folder.
    case launchAgent

    var title: String {
        switch self {
        case .autoRunTask: "Auto-run editor task"
        case .editorSettings: "Risky editor settings"
        case .disguisedScript: "Script disguised as media"
        case .obfuscatedScript: "Obfuscated script"
        case .hiddenCode: "Hidden code"
        case .installScript: "Install script"
        case .propagationScript: "Auto-push script"
        case .gitignoreEntries: "Suspicious .gitignore"
        case .hostArtifact: "Malware leftover"
        case .shellStartup: "Shell startup line"
        case .patchedTool: "Modified tool"
        case .launchAgent: "Login item"
        }
    }

    var symbol: String {
        switch self {
        case .autoRunTask: "play.circle"
        case .editorSettings: "gearshape"
        case .disguisedScript: "theatermasks"
        case .obfuscatedScript: "eye.slash"
        case .hiddenCode: "text.badge.xmark"
        case .installScript: "shippingbox"
        case .propagationScript: "arrow.triangle.branch"
        case .gitignoreEntries: "eye.trianglebadge.exclamationmark"
        case .hostArtifact: "ladybug"
        case .shellStartup: "terminal"
        case .patchedTool: "wrench.adjustable"
        case .launchAgent: "power"
        }
    }

    /// Findings on the Mac itself rather than inside a project.
    var isHostLevel: Bool {
        switch self {
        case .hostArtifact, .launchAgent, .shellStartup, .patchedTool: true
        default: false
        }
    }
}

/// One suspicious file or folder, with the reasons it was flagged.
struct ThreatFinding: Identifiable, Hashable, Sendable {
    let url: URL
    let kind: ThreatKind
    let level: ThreatLevel
    /// The project the file belongs to, or "This Mac" for host-level findings.
    let project: String
    /// Plain-language reasons, most important first. Never empty.
    let reasons: [String]
    /// A short excerpt of the content that triggered the finding, if useful.
    let evidence: String?
    /// Files this one points at, such as the file an auto-run task executes.
    let relatedURLs: [URL]
    let size: Int64
    /// Set when the item must not be removed as a whole, for example a `.gitignore` or
    /// `~/.zshrc` with one bad line. The finding is then shown with these steps instead
    /// of a checkbox.
    var manualFix: String? = nil

    var isRemovable: Bool { manualFix == nil }
    var id: String { url.path }
    var displayPath: String { url.path.abbreviatingHome }

    /// Always `review`: a heuristic can be wrong, so removal is a deliberate choice that
    /// goes through the confirmation sheet and defaults to the Trash.
    var deletionEntry: DeletionEntry {
        DeletionEntry(
            id: id,
            url: url,
            title: "\(project) / \(url.lastPathComponent)",
            size: size,
            safety: .review,
            contentsOnly: false,
            forcePermanent: false
        )
    }
}
