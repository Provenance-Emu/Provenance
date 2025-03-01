//
//  ContentView.swift
//  EmuSkins
//
//  Created by Joseph Mattiello on 2/26/25.
//

import SwiftUI
import PVUIBase

/// A view that displays a list of Delta emulator skins
struct ContentView: View {
    var body: some View {
        NavigationView {
            DeltaSkinListView(manager: DeltaSkinManager.shared)
        }
    }
}

#Preview {
    ContentView()
}
