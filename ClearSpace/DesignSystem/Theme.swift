import SwiftUI

enum Theme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 12
        static let icon: CGFloat = 8
    }

    /// Reading width for scrolling content, so text does not stretch across wide windows.
    static let contentMaxWidth: CGFloat = 880
}

extension CleanupCategory {
    var tint: Color {
        switch self {
        case .xcode: .blue
        case .android: .green
        case .packageManagers: .orange
        case .appCaches: .purple
        case .logs: .gray
        case .trash: .red
        case .virtualDisks: .teal
        }
    }
}

extension SafetyLevel {
    var tint: Color {
        switch self {
        case .safe: .green
        case .review: .orange
        case .manual: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .review: "exclamationmark.triangle.fill"
        case .manual: "wrench.and.screwdriver.fill"
        }
    }
}

extension ArtifactKind {
    var tint: Color {
        switch self {
        case .nodeModules, .nextBuild: .green
        case .pods, .derivedData, .swiftBuild: .blue
        case .dartTool, .flutterBuild: .cyan
        case .gradle: .teal
        case .rustTarget: .orange
        }
    }
}
