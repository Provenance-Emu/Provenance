import Foundation
#if canImport(UIKit)
import UIKit
import PVSettings
#endif

/// Haptic feedback configuration for a skin button
public struct DeltaSkinHaptic: Codable, Equatable {
    /// UIImpactFeedbackGenerator style name (light, medium, heavy, soft, rigid)
    public let style: String
    /// Intensity 0.0–1.0
    public let intensity: Double

    public init(style: String = "medium", intensity: Double = 1.0) {
        self.style = style
        self.intensity = intensity
    }

    #if canImport(UIKit)
    /// Map style string to UIImpactFeedbackGenerator.FeedbackStyle
    public var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch style.lowercased() {
        case "light":  return .light
        case "heavy":  return .heavy
        case "soft":   return .soft
        case "rigid":  return .rigid
        default:       return .medium
        }
    }

    /// Play this haptic, respecting user preferences (buttonVibration setting)
    public func play() {
        guard Defaults[.buttonVibration] else { return }
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(max(0.0, min(1.0, intensity))))
    }
    #endif
}
