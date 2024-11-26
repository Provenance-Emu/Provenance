//
//  UITestingApp.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes

@main
struct UITestingApp: App {
    @State private var showingContinuesSheet = true

    var body: some Scene {
        WindowGroup {
            MainView(showingContinuesSheet: $showingContinuesSheet)
        }
    }
}

struct MainView: View {
    @Binding var showingContinuesSheet: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    var body: some View {
        ZStack {
            currentPalette.gameLibraryBackground.swiftUIColor.ignoresSafeArea()

            VStack {
                Button("Show Continues Management") {
                    showingContinuesSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingContinuesSheet) {
            #if false
            /// Create mock driver with sample data
            let mockDriver = MockSaveStateDriver(mockData: true)

            /// Create view model with mock driver
            let viewModel = ContinuesMagementViewModel(
                driver: mockDriver,
                gameTitle: mockDriver.gameTitle,
                systemTitle: mockDriver.systemTitle,
                numberOfSaves: mockDriver.getAllSaveStates().count,
                savesTotalSize: mockDriver.savesTotalSize,
                gameImage: mockDriver.gameImage
            )
            #else
            let testRealm = try! RealmSaveStateTestFactory.createInMemoryRealm()
            let mockDriver = try! RealmSaveStateDriver(realm: testRealm)

            /// Get the first game from realm for the view model
            let game = testRealm.objects(PVGame.self).first!

            /// Create view model with game data
            let viewModel = ContinuesMagementViewModel(
                driver: mockDriver,
                gameTitle: game.title,
                systemTitle: "Game Boy",
                numberOfSaves: game.saveStates.count,
                gameImage: Image(systemName: "gamecontroller")
            )
            #endif

            ContinuesMagementView(viewModel: viewModel)
                .onAppear {
                    /// Load initial states through the publisher
                    mockDriver.loadSaveStates(forGameId: "1")

                    let theme = CGAThemes.purple
                    ThemeManager.shared.setCurrentPalette(theme.palette)
                }
                .presentationBackground(.clear)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(showingContinuesSheet: .constant(false))
    }
}
