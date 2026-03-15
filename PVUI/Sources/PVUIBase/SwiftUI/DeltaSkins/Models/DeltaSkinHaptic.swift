import UIKit
import PVSettings

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

    #if !os(tvOS)
    /// Play this haptic, respecting user preferences (buttonVibration setting)
    public func play() {
        guard Defaults[.buttonVibration] else { return }
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.impactOccurred(intensity: intensity)
    }
    #endif
}
