import Foundation

/// Cross-platform impact intensity for UI feedback.
/// Where UIKit impact feedback exists (iOS, Mac Catalyst, visionOS, watchOS, etc.), this maps to `UIImpactFeedbackGenerator.FeedbackStyle`.
/// On tvOS this type exists for API uniformity; `Haptics.impact` is a no-op until optional controller feedback is wired.
public enum HapticImpactStrength: Sendable {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

#if !os(tvOS)
import UIKit

extension HapticImpactStrength {
    /// Maps to UIKit feedback styles where available.
    var uiImpactFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        }
    }
}
#endif
