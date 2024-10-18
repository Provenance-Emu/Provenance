//
//  GamesDividerView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GamesDividerView: SwiftUI.View {
    var currentTheme: Color {ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor}
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(currentTheme)
            .opacity(0.1)
    }
}
#endif
