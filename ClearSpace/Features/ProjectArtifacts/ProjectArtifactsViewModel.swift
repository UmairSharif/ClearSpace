import Foundation
import Observation

@MainActor
@Observable
final class ProjectArtifactsViewModel {
    private(set) var phase: ScanPhase = .idle
    private(set) var items: [ArtifactItem] = []
    var selection = Set<String>()
    private(set) var root: URL? = nil

    private var scanTask: Task<Void, Never>?

    init() {
        if let path = UserDefaults.standard.string(forKey: SettingsKey.projectsRootPath),
           FileManager.default.fileExists(atPath: path) {
            root = URL(fileURLWithPath: path)
        }
    }

    var selectedItems: [ArtifactItem] {
        items.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var allSelected: Bool {
        !items.isEmpty && selection.count == items.count
    }

    func setRoot(_ url: URL) {
        root = url
        UserDefaults.standard.set(url.path, forKey: SettingsKey.projectsRootPath)
        scan()
    }

    func scan() {
        guard let root else { return }
        scanTask?.cancel()
        phase = .scanning
        items = []
        selection = []

        scanTask = Task {
            let found = await ProjectArtifactScanner.scan(root: root)
            guard !Task.isCancelled else { return }
            items = found
            phase = .finished
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        phase = items.isEmpty ? .idle : .finished
    }

    func isSelected(_ item: ArtifactItem) -> Bool {
        selection.contains(item.id)
    }

    func setSelected(_ selected: Bool, for item: ArtifactItem) {
        if selected {
            selection.insert(item.id)
        } else {
            selection.remove(item.id)
        }
    }

    func toggleSelectAll() {
        selection = allSelected ? [] : Set(items.map(\.id))
    }

    func apply(_ report: DeletionReport) {
        items.removeAll { report.deletedIDs.contains($0.id) }
        selection.subtract(report.deletedIDs)
    }
}
