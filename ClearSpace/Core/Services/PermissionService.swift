import AppKit

enum PermissionService {
    /// Full Disk Access cannot be requested in code. It is detected by probing a file
    /// that only apps with the permission can open.
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probe = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        guard let handle = try? FileHandle(forReadingFrom: probe) else { return false }
        try? handle.close()
        return true
    }

    /// Touches Desktop, Documents and Downloads so macOS shows its consent prompts.
    /// Returns true when all three folders are readable afterwards.
    static func requestStandardFolderAccess() async -> Bool {
        let directories: [FileManager.SearchPathDirectory] = [
            .desktopDirectory, .documentDirectory, .downloadsDirectory
        ]
        var granted = true
        for directory in directories {
            guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else { continue }
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
            } catch {
                granted = false
            }
        }
        return granted
    }

    @MainActor
    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
