//
//  RetroOptionButton.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/3/25.
//

import SwiftUI
import PVThemes

/// A retrowave-styled button for option selection
public struct RetroOptionButton<T: CustomStringConvertible>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    public let option: T
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(option: T, isSelected: Bool, action: @escaping () -> Void) {
        self.option = option
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(option.description)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(
                    isSelected ?
                    AnyShapeStyle(LinearGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                            RetroTheme.retroPurple
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )) :
                    AnyShapeStyle(Color.gray)
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ?
                            AnyShapeStyle(LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                    RetroTheme.retroPurple,
                                    RetroTheme.retroBlue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )) :
                            AnyShapeStyle(Color.gray.opacity(0.5)),
                            lineWidth: 2
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .shadow(
                    color: isSelected ?
                    (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.6) :
                    Color.clear,
                    radius: 3
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
