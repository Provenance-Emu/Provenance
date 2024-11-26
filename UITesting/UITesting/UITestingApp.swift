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
    @State private var showingRealmSheet = true
    @State private var showingMockSheet = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Button("Show Realm Driver") {
                        showingRealmSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Show Mock Driver") {
                        showingMockSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showingRealmSheet) {
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

                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                        /// Load initial states through the publisher
                        mockDriver.loadSaveStates(forGameId: "1")

                        let theme = CGAThemes.purple
                        ThemeManager.shared.setCurrentPalette(theme.palette)
                    }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingMockSheet) {
                /// Create mock driver with sample data
                let mockDriver = MockSaveStateDriver(mockData: true)

                /// Create view model with mock driver
                let viewModel = ContinuesMagementViewModel(
                    driver: mockDriver,
                    gameTitle: mockDriver.gameTitle,
                    systemTitle: mockDriver.systemTitle,
                    numberOfSaves: mockDriver.getAllSaveStates().count,
                    gameImage: mockDriver.gameImage
                )

                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                        let theme = CGAThemes.purple
                        ThemeManager.shared.setCurrentPalette(theme.palette)
                    }
                    .presentationBackground(.clear)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Button("Show Realm Driver") { }
                    .buttonStyle(.borderedProminent)

                Button("Show Mock Driver") { }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
