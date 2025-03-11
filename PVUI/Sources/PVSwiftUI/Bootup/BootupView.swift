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
            if #available(iOS 18.0, *) {
                ProvenanceAnimatedBackgroundView()
            } else {
                PVAnimatedGradient()
            }

            VStack {
                Text("Initializing...")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .backgroundStyle(.secondary)
                    .tag("Initializing")
                    .blendMode(.difference)

                ActivityIndicatorView(
                    isVisible: .constant(true),
                    type: .growingArc(currentPalette.defaultTintColor?.swiftUIColor ?? .secondary,
                                      lineWidth: 2))
                    .frame(width: 50.0, height: 50.0)

                Text(appState.bootupState.localizedDescription)
                    .foregroundColor(currentPalette.gameLibraryCellText.swiftUIColor)
            }
            .padding(20)
            .background(Color.black.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor, lineWidth: 4)
            )
            .cornerRadius(16)
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupState.localizedDescription)")
        }
    }
}

#if DEBUG
#Preview {
    BootupView()
}
#endif
