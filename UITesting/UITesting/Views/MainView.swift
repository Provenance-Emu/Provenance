//
//  MainView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Game Library Tab
            GameLibraryView()
                .tabItem {
                    Label("Games", systemImage: "gamecontroller")
                }
                .tag(0)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
            
            // Debug Tab
            DebugView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
                .tag(2)
        }
        .accentColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
        .onAppear {
            ILOG("MainView: Appeared")
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
