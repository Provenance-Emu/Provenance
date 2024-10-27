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

struct BootupView: View {
    @EnvironmentObject private var appState: AppState

    init() {
        ILOG("ContentView: App is not initialized, showing BootupView")
    }

    var body: some View {
        VStack {
            Text("Initializing...")
            Text(appState.bootupState.localizedDescription)
        }
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(appState.bootupState.localizedDescription)")
        }
    }
}
