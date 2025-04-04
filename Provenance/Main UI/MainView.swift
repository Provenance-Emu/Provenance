//
//  MainView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLogging
import PVUIBase
import PVSwiftUI
import PVThemes
import Perception

struct MainView: View {
    /// Use EnvironmentObject for app state
    @EnvironmentObject private var appState: AppState
    /// Use EnvironmentObject for app delegate
    @EnvironmentObject private var appDelegate: PVAppDelegate

    /// Remove init since we're using environment objects now

    var body: some View {
        WithPerceptionTracking {
            Group {
                switch appState.mainUIMode {
                case .paged:
                    SwiftUIHostedProvenanceMainView()
                        .environmentObject(appDelegate)
                        .edgesIgnoringSafeArea(.all)
                case .singlePage:
                    RetroMainView()
                        .environmentObject(appDelegate)
                        .environmentObject(ThemeManager.shared)
                        .edgesIgnoringSafeArea(.all)
                case .uikit:
                    RetroMainView()
                        .environmentObject(appDelegate)
                        .environmentObject(ThemeManager.shared)
                        .edgesIgnoringSafeArea(.all)

//                    UIKitHostedProvenanceMainView(appDelegate: appDelegate)
//                        .environmentObject(appDelegate)
//                        .edgesIgnoringSafeArea(.all)
                }
            }
            .onAppear {
                ILOG("MainView: Appeared")
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}
