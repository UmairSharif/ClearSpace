import Foundation
import Observation

/// Shared application state: navigation, feature view models, permissions and the
/// single confirmation pipeline every deletion goes through.
@MainActor
@Observable
final class AppModel {
    let navigation = NavigationModel()
    let smartClean = SmartCleanViewModel()
    let largeFiles = LargeFilesViewModel()
    let projects = ProjectArtifactsViewModel()
    let threats = ThreatScanViewModel()

    var diskUsage: DiskUsage = .empty
    var hasFullDiskAccess = false

    /// Set to present the confirmation sheet. Nothing is deleted without it.
    var pendingDeletion: DeletionRequest?
    /// Set after a cleanup finishes to present the summary sheet.
    var report: DeletionReport?
    var isDeleting = false

    init() {
        UserDefaults.standard.removeObject(forKey: SettingsKey.legacyDeletionMode)
    }

    func refreshDiskUsage() {
        diskUsage = DiskUsageService.current()
    }

    func refreshPermissions() {
        hasFullDiskAccess = PermissionService.hasFullDiskAccess()
    }

    func requestDeletion(
        title: String,
        entries: [DeletionEntry],
        onComplete: @escaping @MainActor (DeletionReport) -> Void
    ) {
        guard !entries.isEmpty else { return }
        pendingDeletion = DeletionRequest(title: title, entries: entries, onComplete: onComplete)
    }

    func performDeletion(_ request: DeletionRequest, mode: DeletionMode) async {
        guard !isDeleting else { return }
        isDeleting = true
        let result = await DeletionService.perform(request.entries, mode: mode)
        isDeleting = false

        request.onComplete(result)
        pendingDeletion = nil
        refreshDiskUsage()

        // Let the confirmation sheet finish dismissing before presenting the summary.
        try? await Task.sleep(for: .milliseconds(450))
        report = result
    }
}
