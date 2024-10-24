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
    @ObservedObject private var themeManager = ThemeManager.shared

    var currentPalette: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(currentPalette)
            .opacity(0.1)
    }
}
#endif
