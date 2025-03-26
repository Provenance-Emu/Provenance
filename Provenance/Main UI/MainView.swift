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
                if appState.useUIKit {
                    UIKitHostedProvenanceMainView()
                        .environmentObject(appDelegate)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    SwiftUIHostedProvenanceMainView()
                        .environmentObject(appDelegate)
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .onAppear {
                ILOG("MainView: Appeared")
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}
