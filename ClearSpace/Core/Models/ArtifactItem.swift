import Foundation

/// A regenerable build or dependency folder inside a project.
struct ArtifactItem: Identifiable, Hashable, Sendable {
    let url: URL
    let kind: ArtifactKind
    let project: String
    let size: Int64

    var id: String { url.path }
    var displayPath: String { url.path.abbreviatingHome }

    var deletionEntry: DeletionEntry {
        DeletionEntry(
            id: id,
            url: url,
            title: "\(project) / \(url.lastPathComponent)",
            size: size,
            safety: .safe,
            contentsOnly: false,
            forcePermanent: false
        )
    }
}

enum ArtifactKind: String, CaseIterable, Hashable, Sendable {
    case nodeModules
    case pods
    case dartTool
    case flutterBuild
    case gradle
    case derivedData
    case rustTarget
    case nextBuild
    case swiftBuild

    var title: String {
        switch self {
        case .nodeModules: "Node modules"
        case .pods: "CocoaPods"
        case .dartTool: "Dart tool cache"
        case .flutterBuild: "Build output"
        case .gradle: "Gradle cache"
        case .derivedData: "Derived data"
        case .rustTarget: "Cargo target"
        case .nextBuild: "Next.js build"
        case .swiftBuild: "SwiftPM build"
        }
    }

    var restoreHint: String {
        switch self {
        case .nodeModules: "Restore with npm, yarn or pnpm install."
        case .pods: "Restore with pod install."
        case .dartTool: "Restore with flutter pub get."
        case .flutterBuild: "Recreated by the next build."
        case .gradle: "Recreated by the next Gradle build."
        case .derivedData: "Recreated by the next Xcode build."
        case .rustTarget: "Recreated by cargo build."
        case .nextBuild: "Recreated by next build."
        case .swiftBuild: "Recreated by swift build."
        }
    }

    /// Returns the kind for a folder name, checking sibling marker files where the name alone is ambiguous.
    static func match(folderName: String, parent: URL) -> ArtifactKind? {
        func sibling(_ names: String...) -> Bool {
            names.contains { FileManager.default.fileExists(atPath: parent.appendingPathComponent($0).path) }
        }

        switch folderName {
        case "node_modules":
            return .nodeModules
        case ".dart_tool":
            return .dartTool
        case "DerivedData":
            return .derivedData
        case "Pods":
            return sibling("Podfile") ? .pods : nil
        case "build":
            return sibling("pubspec.yaml", "build.gradle", "build.gradle.kts") ? .flutterBuild : nil
        case ".gradle":
            return sibling("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts") ? .gradle : nil
        case "target":
            return sibling("Cargo.toml") ? .rustTarget : nil
        case ".next":
            return sibling("package.json") ? .nextBuild : nil
        case ".build":
            return sibling("Package.swift") ? .swiftBuild : nil
        default:
            return nil
        }
    }
}
