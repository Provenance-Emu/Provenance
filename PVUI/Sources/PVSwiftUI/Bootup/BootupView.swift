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
import ActivityIndicatorView
import AnimatedGradient

public struct BootupView: View {
    @EnvironmentObject private var appState: AppState

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init() {
        ILOG("ContentView: App is not initialized, showing BootupView")
    }

    public var body: some View {
        ZStack {
            AnimatedLinearGradient(colors: [
                .Provenance.blue,
                currentPalette.settingsCellBackground!.swiftUIColor,
                currentPalette.gameLibraryBackground.swiftUIColor,
                currentPalette.settingsCellBackground!.swiftUIColor])
            .numberOfSimultaneousColors(3)
            .setAnimation(.bouncy(duration: 5))
            .gradientPoints(start: .topTrailing, end: .bottomLeading)
            .ignoresSafeArea()

            VStack {
                Text("Initializing...")
                    .foregroundColor(currentPalette.gameLibraryText.swiftUIColor)
                
                ActivityIndicatorView(
                    isVisible: .constant(true),
                    type: .growingArc(currentPalette.defaultTintColor?.swiftUIColor ?? .secondary,
                                      lineWidth: 2))
                    .frame(width: 50.0, height: 50.0)

                Text(appState.bootupState.localizedDescription)
                    .foregroundColor(currentPalette.gameLibraryCellText.swiftUIColor)
            }
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupState.localizedDescription)")
        }
    }
}

#Preview {
    BootupView()
}
