import Foundation
#if !os(tvOS)
import UIKit
#endif

#if !os(tvOS)
public enum Haptics {
    /// Selection-style impact; prefer this from cross-platform UI so tvOS call sites compile (see tvOS `Haptics` below).
    public static func impact(strength: HapticImpactStrength = .medium) {
        let generator = UIImpactFeedbackGenerator(style: strength.uiImpactFeedbackStyle)
        generator.impactOccurred()
    }

    public static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    public static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
#else
public enum Haptics {
    /// tvOS has no system Taptic engine; no-op here so UI code stays unconditional. Optional `GCDeviceHaptics` UI ticks can be added later.
    public static func impact(strength: HapticImpactStrength = .medium) {}
}
#endif
