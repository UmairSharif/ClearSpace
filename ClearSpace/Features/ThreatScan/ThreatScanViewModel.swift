import Foundation
import Observation

@MainActor
@Observable
final class ThreatScanViewModel {
    private(set) var phase: ScanPhase = .idle
    private(set) var findings: [ThreatFinding] = []
    var selection = Set<String>()
    private(set) var root: URL? = nil
    /// Also check the home folder for files the malware leaves after it has run.
    var includeThisMac = true

    private var scanTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        for key in [SettingsKey.threatScanRootPath, SettingsKey.projectsRootPath] {
            if let path = defaults.string(forKey: key), FileManager.default.fileExists(atPath: path) {
                root = URL(fileURLWithPath: path)
                break
            }
        }
    }

    var projectFindings: [ThreatFinding] { findings.filter { !$0.kind.isHostLevel } }
    var hostFindings: [ThreatFinding] { findings.filter { $0.kind.isHostLevel } }

    /// Project names in the order their worst finding appears.
    var projects: [String] {
        var seen = Set<String>()
        return projectFindings.compactMap { seen.insert($0.project).inserted ? $0.project : nil }
    }

    func findings(in project: String) -> [ThreatFinding] {
        projectFindings.filter { $0.project == project }
    }

    var highCount: Int { findings.filter { $0.level == .high }.count }
    var removableHighCount: Int { findings.filter { $0.level == .high && $0.isRemovable }.count }

    var selectedFindings: [ThreatFinding] {
        findings.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedFindings.reduce(0) { $0 + $1.size }
    }

    func setRoot(_ url: URL) {
        root = url
        UserDefaults.standard.set(url.path, forKey: SettingsKey.threatScanRootPath)
        scan()
    }

    func scan() {
        guard root != nil || includeThisMac else { return }
        let root = root
        let includeThisMac = includeThisMac
        scanTask?.cancel()
        phase = .scanning
        findings = []
        selection = []

        scanTask = Task {
            var found: [ThreatFinding] = []
            if let root {
                found += await ThreatScanner.scan(root: root)
            }
            if includeThisMac, !Task.isCancelled {
                found += await HostThreatScanner.scan()
            }
            guard !Task.isCancelled else { return }
            findings = Self.deduplicated(found)
            phase = .finished
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        phase = findings.isEmpty ? .idle : .finished
    }

    func isSelected(_ finding: ThreatFinding) -> Bool {
        selection.contains(finding.id)
    }

    /// Selecting a task or install script also selects the files it runs, when those were
    /// flagged too, so the payload is not left behind by accident. Deselecting is per item.
    func setSelected(_ selected: Bool, for finding: ThreatFinding) {
        guard selected else {
            selection.remove(finding.id)
            return
        }
        guard finding.isRemovable else { return }
        selection.insert(finding.id)
        let relatedPaths = Set(finding.relatedURLs.map(\.standardizedFileURL.path))
        for other in findings where other.isRemovable && relatedPaths.contains(other.url.standardizedFileURL.path) {
            selection.insert(other.id)
        }
    }

    func selectAllHighRisk() {
        selection.formUnion(findings.filter { $0.level == .high && $0.isRemovable }.map(\.id))
    }

    func deselectAll() {
        selection = []
    }

    func apply(_ report: DeletionReport) {
        findings.removeAll { report.deletedIDs.contains($0.id) }
        selection.subtract(report.deletedIDs)
    }

    /// A home-folder scan can reach the same file twice (for example `~/.npm` items when
    /// the projects folder is the home folder). Keep the first, highest-level copy.
    static func deduplicated(_ findings: [ThreatFinding]) -> [ThreatFinding] {
        var seen = Set<String>()
        return ThreatScanner.sorted(findings).filter { seen.insert($0.id).inserted }
    }
}
