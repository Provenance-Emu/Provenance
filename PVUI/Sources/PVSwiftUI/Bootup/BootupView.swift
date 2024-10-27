//
//  BootupView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import Foundation
import PVLogging
import PVUIBase
import PVThemes

public struct BootupView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState

    public init() {
        ILOG("ContentView: App is not initialized, showing BootupView")
    }

    public var body: some View {
        ZStack {
            themeManager.currentPalette.gameLibraryBackground.swiftUIColor
                .ignoresSafeArea()

            VStack {
                Text("Initializing...")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                Text(appState.bootupState.localizedDescription)
                    .foregroundColor(themeManager.currentPalette.gameLibraryCellText.swiftUIColor)
            }
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupState.localizedDescription)")
        }
    }
}
