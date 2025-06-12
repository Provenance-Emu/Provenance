//
//  RetroDividerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/8/25.
//

import SwiftUI
import PVThemes

/// Retrowave-styled divider
public struct RetroDividerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(themeManager: ThemeManager = ThemeManager.shared) {
        self.themeManager = themeManager
    }
    
    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .opacity(0.7)
    }
}
