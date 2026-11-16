import Foundation

/// The curated list of places Smart Clean inspects. Every entry states why it is
/// safe (or not) so the user can make an informed choice.
enum CleanupCatalog {
    static let targets: [CleanupTarget] = xcode + android + packageManagers + appCaches + logs + trash + virtualDisks

    // MARK: Xcode

    private static let xcode: [CleanupTarget] = [
        CleanupTarget(
            title: "Derived Data",
            relativePath: "Library/Developer/Xcode/DerivedData",
            category: .xcode,
            safety: .safe,
            explanation: "Build products and indexes. Xcode rebuilds them on the next build.",
            mode: .contents
        ),
        CleanupTarget(
            title: "iOS Device Support",
            relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
            category: .xcode,
            safety: .safe,
            explanation: "Debug symbols copied from a connected device. Recreated when you connect it again.",
            mode: .eachChild
        ),
        CleanupTarget(
            title: "watchOS Device Support",
            relativePath: "Library/Developer/Xcode/watchOS DeviceSupport",
            category: .xcode,
            safety: .safe,
            explanation: "Debug symbols copied from a connected watch. Recreated when you connect it again.",
            mode: .eachChild
        ),
        CleanupTarget(
            title: "Simulator Caches",
            relativePath: "Library/Developer/CoreSimulator/Caches",
            category: .xcode,
            safety: .safe,
            explanation: "Shared simulator caches. Recreated when a simulator boots.",
            mode: .contents
        ),
        CleanupTarget(
            title: "Swift Package Cache",
            relativePath: "Library/Caches/org.swift.swiftpm",
            category: .xcode,
            safety: .safe,
            explanation: "Downloaded Swift packages. Xcode fetches them again when resolving packages."
        ),
        CleanupTarget(
            title: "Documentation Cache",
            relativePath: "Library/Developer/Xcode/DocumentationCache",
            category: .xcode,
            safety: .safe,
            explanation: "Cached developer documentation. Downloaded again on demand.",
            mode: .contents
        ),
        CleanupTarget(
            title: "Archive",
            relativePath: "Library/Developer/Xcode/Archives",
            category: .xcode,
            safety: .review,
            explanation: "Archived builds. Keep the ones you need to symbolicate crash logs of shipped versions.",
            mode: .eachChild
        )
    ]

    // MARK: Android

    private static let android: [CleanupTarget] = [
        CleanupTarget(
            title: "Emulator System Image",
            relativePath: "Library/Android/sdk/system-images",
            category: .android,
            safety: .review,
            explanation: "Required by emulators that use this API level. Reinstall from the SDK Manager.",
            mode: .eachChild
        ),
        CleanupTarget(
            title: "Virtual Device",
            relativePath: ".android/avd",
            category: .android,
            safety: .review,
            explanation: "An emulator and everything installed on it.",
            mode: .eachChild
        ),
        CleanupTarget(
            title: "Gradle Caches",
            relativePath: ".gradle/caches",
            category: .android,
            safety: .safe,
            explanation: "Downloaded dependencies and build caches. Gradle downloads them again on the next build."
        ),
        CleanupTarget(
            title: "Gradle Wrapper Distributions",
            relativePath: ".gradle/wrapper/dists",
            category: .android,
            safety: .safe,
            explanation: "Gradle versions downloaded by project wrappers. Fetched again when a project needs them."
        ),
        CleanupTarget(
            title: "Gradle Temporary Files",
            relativePath: ".gradle/.tmp",
            category: .android,
            safety: .safe,
            explanation: "Leftover temporary files."
        ),
        CleanupTarget(
            title: "Gradle Daemon Logs",
            relativePath: ".gradle/daemon",
            category: .android,
            safety: .safe,
            explanation: "Logs from past Gradle daemons."
        )
    ]

    // MARK: Package managers

    private static let packageManagers: [CleanupTarget] = [
        CleanupTarget(
            title: "npm Cache",
            relativePath: ".npm/_cacache",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded npm packages. Fetched again on the next install."
        ),
        CleanupTarget(
            title: "Yarn Cache",
            relativePath: "Library/Caches/Yarn",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded Yarn packages. Fetched again on the next install."
        ),
        CleanupTarget(
            title: "pnpm Store",
            relativePath: "Library/pnpm/store",
            category: .packageManagers,
            safety: .safe,
            explanation: "Shared pnpm package store. Fetched again on the next install."
        ),
        CleanupTarget(
            title: "CocoaPods Cache",
            relativePath: "Library/Caches/CocoaPods",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded pods. Fetched again by pod install."
        ),
        CleanupTarget(
            title: "CocoaPods Spec Repos",
            relativePath: ".cocoapods/repos",
            category: .packageManagers,
            safety: .safe,
            explanation: "Local copies of spec repositories. Recreated by pod install or pod repo update."
        ),
        CleanupTarget(
            title: "Dart Pub Cache",
            relativePath: ".pub-cache/hosted",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded Dart and Flutter packages. Fetched again by flutter pub get."
        ),
        CleanupTarget(
            title: "Dart Analysis Cache",
            relativePath: ".dartServer/.analysis-driver",
            category: .packageManagers,
            safety: .safe,
            explanation: "Analysis results kept by the Dart language server. Rebuilt when you open a project."
        ),
        CleanupTarget(
            title: "Homebrew Downloads",
            relativePath: "Library/Caches/Homebrew",
            category: .packageManagers,
            safety: .safe,
            explanation: "Installers of formulae you already installed."
        ),
        CleanupTarget(
            title: "uv Cache",
            relativePath: ".cache/uv",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded Python packages. Fetched again when needed."
        ),
        CleanupTarget(
            title: "pip Cache",
            relativePath: "Library/Caches/pip",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded Python packages. Fetched again when needed."
        ),
        CleanupTarget(
            title: "Cargo Registry",
            relativePath: ".cargo/registry",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded Rust crates. Fetched again by cargo build."
        ),
        CleanupTarget(
            title: "NuGet Packages",
            relativePath: ".nuget/packages",
            category: .packageManagers,
            safety: .safe,
            explanation: "Downloaded .NET packages. Restored by dotnet restore."
        ),
        CleanupTarget(
            title: "Go Build Cache",
            relativePath: "Library/Caches/go-build",
            category: .packageManagers,
            safety: .safe,
            explanation: "Compiled Go packages. Rebuilt on the next build."
        ),
        CleanupTarget(
            title: "Playwright Browsers",
            relativePath: "Library/Caches/ms-playwright",
            category: .packageManagers,
            safety: .safe,
            explanation: "Browser builds downloaded for tests. Reinstall with playwright install."
        )
    ]

    // MARK: App caches

    private static let appCaches: [CleanupTarget] = [
        CleanupTarget(
            title: "Cache",
            relativePath: "Library/Caches",
            category: .appCaches,
            safety: .safe,
            explanation: "Temporary files this app can recreate. It may launch a little slower the first time.",
            mode: .eachChild,
            excludedChildPrefixes: ["com.apple.", "CloudKit", "FamilyCircle", "GeoServices"]
        )
    ]

    // MARK: Logs

    private static let logs: [CleanupTarget] = [
        CleanupTarget(
            title: "User Logs",
            relativePath: "Library/Logs",
            category: .logs,
            safety: .safe,
            explanation: "Diagnostic logs and crash reports written by apps.",
            mode: .contents
        )
    ]

    // MARK: Trash

    private static let trash: [CleanupTarget] = [
        CleanupTarget(
            title: "Trash",
            relativePath: ".Trash",
            category: .trash,
            safety: .review,
            explanation: "Emptying the Trash removes these items for good. Requires Full Disk Access.",
            mode: .contents,
            forcePermanent: true
        )
    ]

    // MARK: Virtual disks

    private static let virtualDisks: [CleanupTarget] = [
        CleanupTarget(
            title: "Docker Disk Image",
            relativePath: "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
            category: .virtualDisks,
            safety: .manual,
            explanation: "Holds every Docker image, container and volume.",
            hint: "docker system prune -a --volumes"
        ),
        CleanupTarget(
            title: "Simulator Devices",
            relativePath: "Library/Developer/CoreSimulator/Devices",
            category: .virtualDisks,
            safety: .manual,
            explanation: "Apps and data installed on your simulators.",
            hint: "xcrun simctl delete unavailable"
        )
    ]
}
