//
//  MenuItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/4/24.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
@_exported import PVUIBase

@available(iOS 14, tvOS 14, *)
struct MenuItemView: SwiftUI.View {

    var icon: SettingsIcon
    var rowTitle: String
    var isFocused: Bool

    var action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared

    /// Gap between the menu's edge and a row's highlight.
    static let highlightInset: CGFloat = 6
    /// Opacity of the tint that fills the active or focused row.
    private static let highlightFillOpacity: Double = 0.12

    private var shouldShowFocus: Bool {
        (isFocused && navigationInputAvailable) || !navigationInputAvailable
    }

    private var navigationInputAvailable: Bool {
        gamepadManager.isNavigationInputAvailable
    }

    private var shouldStroke: Bool {
        shouldShowFocus && navigationInputAvailable
    }

    private var highlightShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RetroPauseChrome.menuCellCornerRadius())
    }

    private var iconTint: Color {
        shouldShowFocus ? themeManager.currentPalette.menuIconTint.swiftUIColor : themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(navigationInputAvailable ? 0.6 : 1.0)
    }

    private var textTint: Color {
        shouldShowFocus ? themeManager.currentPalette.menuText.swiftUIColor : themeManager.currentPalette.menuText.swiftUIColor.opacity(navigationInputAvailable ? 0.6 : 1.0)
    }

    /// Whether this row represents the currently active console/tab
    var isActive: Bool = false

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(iconTint)
                    .frame(width: 3, height: 24)
                    .shadow(color: iconTint.opacity(0.5), radius: 4)
                    .opacity(isActive ? 1 : 0)
                    .padding(.trailing, 8)
                /// Icon
                icon.image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(iconTint)
                /// Text
                Text(rowTitle)
                    .font(.callout.weight(isActive ? .semibold : .medium))
                    .tracking(0.3)
                    .foregroundColor(textTint)
                /// Space
                Spacer()
            }
            .frame(minHeight: LibraryLayout.controlHeight)
            .padding(.horizontal, LibraryLayout.chromeHorizontalInset - Self.highlightInset)
            // The active or focused row gets a tinted, inset highlight with a hairline, not a full-width box.
            .background {
                if isActive || shouldStroke {
                    highlightShape.fill(themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(Self.highlightFillOpacity))
                }
            }
            .overlay {
                if shouldStroke {
                    highlightShape.strokeBorder(themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(RetroPauseChrome.menuCellStrokeOpacityFocused))
                }
            }
            .padding(.horizontal, Self.highlightInset)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
#endif
