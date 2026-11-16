import Foundation

enum CleanupCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case xcode
    case android
    case packageManagers
    case appCaches
    case logs
    case trash
    case virtualDisks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcode: "Xcode"
        case .android: "Android"
        case .packageManagers: "Package Managers"
        case .appCaches: "App Caches"
        case .logs: "Logs"
        case .trash: "Trash"
        case .virtualDisks: "Virtual Disks"
        }
    }

    var summary: String {
        switch self {
        case .xcode: "Build products, device support files and simulator data."
        case .android: "Emulator images, virtual devices and Gradle caches."
        case .packageManagers: "Downloaded packages kept by npm, Yarn, CocoaPods, pub and others."
        case .appCaches: "Temporary files apps keep to launch and load faster."
        case .logs: "Diagnostic logs and crash reports."
        case .trash: "Items you already moved to the Trash."
        case .virtualDisks: "Disk images managed by tools such as Docker and Simulator."
        }
    }

    var symbol: String {
        switch self {
        case .xcode: "hammer.fill"
        case .android: "apps.iphone"
        case .packageManagers: "shippingbox.fill"
        case .appCaches: "archivebox.fill"
        case .logs: "doc.text.fill"
        case .trash: "trash.fill"
        case .virtualDisks: "externaldrive.fill"
        }
    }
}
