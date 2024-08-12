//
//  HomeDividerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct HomeDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
            .opacity(0.1)
            .padding(.horizontal, 10)
    }
}
