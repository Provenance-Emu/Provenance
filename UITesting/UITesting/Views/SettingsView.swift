//
//  SettingsView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import PVUIBase
import PVLibrary
import RealmSwift

/// A wrapper view that uses the existing PVSettingsView from the main app
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var mockImportStatusDriverData = MockImportStatusDriverData()
    
    var body: some View {
        NavigationView {
            // Use the existing PVSettingsView from the main app
            PVSettingsView(
                conflictsController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                menuDelegate: MockPVMenuDelegate()) {
                    // Dismiss action (not needed in this context)
                }
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}
