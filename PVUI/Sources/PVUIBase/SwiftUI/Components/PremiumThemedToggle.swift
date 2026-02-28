//
//  PremiumThemedToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import UIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif
import PVThemes

// MARK: - FreemiumKit Color Reset

#if canImport(FreemiumKit)
/// Resets inherited theme colors so FreemiumKit views (banners, paywalls)
/// use their own configured styling instead of the app's PVThemes palette.
/// The app sets `.foregroundColor()` and `UIView.appearance().tintColor`
/// globally, which leaks into FreemiumKit sheets and causes readability issues.
public struct FreemiumKitColorResetModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .tint(.blue)
            .accentColor(.blue)
    }
}

public extension View {
    /// Resets SwiftUI color environment so FreemiumKit uses its own styling
    func freemiumKitColorReset() -> some View {
        self.modifier(FreemiumKitColorResetModifier())
    }
}
#endif

public struct PremiumThemedToggle<Label: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var isOn: Bool
    let label: Label

    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }

#if canImport(FreemiumKit)
    public var body: some View {
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(RetroTheme.RetroToggleStyle())
        } lockedView: {
            ZStack {
                Color(.clear)
                HStack {
                    Toggle(isOn: $isOn) {
                        label
                    }
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                    .disabled(true)

                    Spacer().frame(width: 6)

                    // Lock icon + PLUS badge
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("PLUS")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.retroPink.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
                .opacity(0.7)
            }
        }
        .freemiumKitColorReset()
    }
#else
    public var body: some View {
        Toggle(isOn: $isOn) {
            label
        }
        .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
        .onAppear {
            UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
        }
    }
#endif
}
