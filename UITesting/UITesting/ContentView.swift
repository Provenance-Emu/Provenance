//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVLookup
import PVLookupTypes
import PVSystems
import PVUIBase
import PVThemes
import PVLogging

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    init() {
        ILOG("ContentView: init() called, current bootup state: \(AppState.shared.bootupStateManager.currentState.localizedDescription)")
    }
    
    var body: some View {
        Group {
            switch appState.bootupStateManager.currentState {
            case .completed:
                ZStack {
                    MainView()
                }
                .onAppear {
                    ILOG("ContentView: MainView appeared")
                }
            case .error(let error):
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
            default:
                BootupView()
                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            ILOG("ContentView: Appeared")
            ILOG("ContentView: onAppear - Set currentBootupState to \(appState.bootupStateManager.currentState.localizedDescription)")
        }
        .onChange(of: appState.bootupStateManager.currentState) { state in
            ILOG("ContentView: Bootup state changed to \(state.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
