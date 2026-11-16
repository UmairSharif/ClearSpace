import Foundation
import Observation

enum ScanPhase: Equatable {
    case idle
    case scanning
    case finished
}

@MainActor
@Observable
final class SmartCleanViewModel {
    private(set) var phase: ScanPhase = .idle
    private(set) var items: [CleanupItem] = []
    private(set) var scannedTargets = 0
    private(set) var totalTargets = CleanupCatalog.targets.count
    var selection = Set<String>()

    // MARK: Scanning

    func scan() async {
        guard phase != .scanning else { return }
        phase = .scanning
        items = []
        selection = []
        scannedTargets = 0

        let targets = CleanupCatalog.targets
        let reserved = SmartScanService.reservedPaths()
        totalTargets = targets.count

        await withTaskGroup(of: [CleanupItem].self) { group in
            for target in targets {
                group.addTask(priority: .userInitiated) {
                    SmartScanService.resolve(target, reservedPaths: reserved)
                }
            }
            for await found in group {
                scannedTargets += 1
                items.append(contentsOf: found)
                items.sort { $0.size > $1.size }
            }
        }

        phase = .finished
    }

    var progress: Double {
        guard totalTargets > 0 else { return 0 }
        return Double(scannedTargets) / Double(totalTargets)
    }

    // MARK: Derived data

    var categories: [CleanupCategory] {
        CleanupCategory.allCases.filter { category in
            items.contains { $0.category == category }
        }
    }

    func items(in category: CleanupCategory) -> [CleanupItem] {
        items.filter { $0.category == category }
    }

    func totalSize(in category: CleanupCategory) -> Int64 {
        items(in: category).reduce(0) { $0 + $1.size }
    }

    func selectedSize(in category: CleanupCategory) -> Int64 {
        items(in: category).filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    /// Everything the app could remove itself.
    var reclaimableSize: Int64 {
        items.filter(\.isSelectable).reduce(0) { $0 + $1.size }
    }

    /// Only items that regenerate automatically.
    var safeSize: Int64 {
        items.filter { $0.safety == .safe }.reduce(0) { $0 + $1.size }
    }

    var selectedItems: [CleanupItem] {
        items.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    // MARK: Selection

    func isSelected(_ item: CleanupItem) -> Bool {
        selection.contains(item.id)
    }

    func setSelected(_ selected: Bool, for item: CleanupItem) {
        guard item.isSelectable else { return }
        if selected {
            selection.insert(item.id)
        } else {
            selection.remove(item.id)
        }
    }

    func selectAllSafe() {
        selection = Set(items.filter { $0.safety == .safe }.map(\.id))
    }

    func selectAll(in category: CleanupCategory) {
        selection.formUnion(items(in: category).filter(\.isSelectable).map(\.id))
    }

    func deselectAll(in category: CleanupCategory) {
        selection.subtract(items(in: category).map(\.id))
    }

    func clearSelection() {
        selection = []
    }

    // MARK: Results

    func apply(_ report: DeletionReport) {
        items.removeAll { report.deletedIDs.contains($0.id) }
        selection.subtract(report.deletedIDs)
    }
}
