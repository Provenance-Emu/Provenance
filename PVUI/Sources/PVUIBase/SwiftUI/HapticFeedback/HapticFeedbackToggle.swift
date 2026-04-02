import SwiftUI

/// A `Toggle` that triggers `Haptics.impact` when `isOn` changes (no-op on tvOS until optional controller feedback is added).
public struct HapticFeedbackToggle<Label: View>: View {
    @Binding private var isOn: Bool
    private let strength: HapticImpactStrength
    private let label: () -> Label

    public init(isOn: Binding<Bool>, strength: HapticImpactStrength = .light, @ViewBuilder label: @escaping () -> Label) {
        _isOn = isOn
        self.strength = strength
        self.label = label
    }

    public var body: some View {
        Toggle(isOn: $isOn, label: label)
            .hapticFeedbackOnChange(of: isOn, strength: strength)
    }
}
