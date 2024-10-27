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

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    let appDelegate: PVAppDelegate

    init(appDelegate: PVAppDelegate) {
        ILOG("ContentView: App is initialized, showing MainView")
        self.appDelegate = appDelegate
    }

    var body: some View {
        Group {
            if appState.useUIKit {
                UIKitHostedProvenanceMainView(appDelegate: appDelegate)
                .edgesIgnoringSafeArea(.all)
            } else {
                SwiftUIHostedProvenanceMainView(appDelegate: appDelegate)
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            ILOG("MainView: Appeared")
        }
        .edgesIgnoringSafeArea(.all)
    }
}
