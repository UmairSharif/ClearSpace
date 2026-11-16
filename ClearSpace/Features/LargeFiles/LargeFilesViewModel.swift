import Foundation
import Observation

@MainActor
@Observable
final class LargeFilesViewModel {
    enum SizeThreshold: Int64, CaseIterable, Identifiable {
        case mb50 = 52_428_800
        case mb100 = 104_857_600
        case mb500 = 524_288_000
        case gb1 = 1_073_741_824

        var id: Int64 { rawValue }

        var title: String {
            switch self {
            case .mb50: "50 MB"
            case .mb100: "100 MB"
            case .mb500: "500 MB"
            case .gb1: "1 GB"
            }
        }
    }

    private(set) var phase: ScanPhase = .idle
    var files: [FileEntry] = []
    var selection = Set<FileEntry.ID>()
    var sortOrder = [KeyPathComparator(\FileEntry.size, order: .reverse)]

    var root: URL = FileManager.default.homeDirectoryForCurrentUser
    var threshold: SizeThreshold = .mb100
    var includeLibrary = false

    private var scanTask: Task<Void, Never>?

    var rootName: String {
        root.standardizedFileURL.path == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
            ? "Home"
            : root.lastPathComponent
    }

    var selectedFiles: [FileEntry] {
        files.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    func scan() {
        scanTask?.cancel()
        phase = .scanning
        files = []
        selection = []

        let root = root
        let minimumSize = threshold.rawValue
        let includeLibrary = includeLibrary
        let order = sortOrder

        scanTask = Task {
            let found = await LargeFileScanner.scan(root: root, minimumSize: minimumSize, includeLibrary: includeLibrary)
            guard !Task.isCancelled else { return }
            files = found.sorted(using: order)
            phase = .finished
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        phase = files.isEmpty ? .idle : .finished
    }

    func sort() {
        files.sort(using: sortOrder)
    }

    func apply(_ report: DeletionReport) {
        files.removeAll { report.deletedIDs.contains($0.id) }
        selection.subtract(report.deletedIDs)
    }
}
