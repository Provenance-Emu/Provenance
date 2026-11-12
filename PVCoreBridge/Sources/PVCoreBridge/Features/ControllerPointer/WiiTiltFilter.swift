import CoreGraphics
import Foundation
import simd

/// How the physical pad's axes map to the emulated Wii Remote.
public enum WiiTiltMode: String, Codable, CaseIterable, Sendable {
    case off
    case upright
    case sideways
}

/// Estimates normalized pitch and roll from gravity. A face-up pad is neutral.
public struct WiiTiltFilter {
    private var filtered = SIMD3<Double>(0, 0, -1)

    public init() {}

    public mutating func update(gravity: SIMD3<Double>, mode: WiiTiltMode) -> CGPoint {
        guard mode != .off else { return .zero }
        let magnitude = simd_length(gravity)
        guard magnitude.isFinite, (0.65...1.35).contains(magnitude) else { return axes(mode: mode) }
        filtered += (gravity / magnitude - filtered) * 0.15
        return axes(mode: mode)
    }

    private func axes(mode: WiiTiltMode) -> CGPoint {
        let pitch = normalized(filtered.y)
        let roll = normalized(filtered.x)
        return mode == .sideways ? CGPoint(x: pitch, y: -roll) : CGPoint(x: roll, y: pitch)
    }

    private func normalized(_ component: Double) -> Double {
        let value = min(1, max(0, (abs(component) - 0.06) / (0.707 - 0.06)))
        return component < 0 ? -value : value
    }
}
