import Foundation

/// How confident the app is that removing an item has no lasting effect.
enum SafetyLevel: String, Hashable, Sendable {
    /// Regenerated automatically by the owning tool. Safe to remove.
    case safe
    /// User data or something that takes effort to restore. Needs a deliberate choice.
    case review
    /// Shown for awareness only. Must be cleaned with the owning tool.
    case manual

    var title: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .manual: "Manual"
        }
    }

    var explanation: String {
        switch self {
        case .safe: "Rebuilt automatically when needed."
        case .review: "Check before removing. This may not come back on its own."
        case .manual: "Clean this with the tool that owns it."
        }
    }
}
