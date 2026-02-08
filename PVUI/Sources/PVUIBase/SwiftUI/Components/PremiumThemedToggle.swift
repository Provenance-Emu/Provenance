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
    #if !os(tvOS)
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(RetroTheme.RetroToggleStyle())
        } lockedView: {
            ZStack {
                Color(.clear)
                Toggle(isOn: $isOn) {
                    label
                }
                .toggleStyle(RetroTheme.RetroToggleStyle())
                .opacity(0.6)
                .disabled(true)
            }
        }
        .freemiumKitColorReset()
        #else
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(RetroTheme.RetroToggleStyle())
        } lockedView: {
            ZStack {
                Color(.clear)
                Toggle(isOn: $isOn) {
                    label
                }
                .toggleStyle(RetroTheme.RetroToggleStyle())
                .opacity(0.6)
                .disabled(true)
            }
        }
        .freemiumKitColorReset()
        #endif
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
