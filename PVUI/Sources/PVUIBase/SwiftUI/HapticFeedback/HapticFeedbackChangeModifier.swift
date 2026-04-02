import SwiftUI

extension View {
    /// Fires `Haptics.impact` when `value` changes (e.g. after a `Toggle` updates).
    /// tvOS is a no-op via `Haptics`; iOS uses the Taptic engine.
    public func hapticFeedbackOnChange<V: Equatable>(of value: V, strength: HapticImpactStrength = .light) -> some View {
        onChange(of: value) { _, _ in
            Haptics.impact(strength: strength)
        }
    }
}
