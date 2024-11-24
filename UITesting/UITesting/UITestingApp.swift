//
//  UITestingApp.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI

@main
struct UITestingApp: App {
    var body: some Scene {
        WindowGroup {
            /// Create mock driver with sample data
//            let mockDriver = MockSaveStateDriver(mockData: true)
            
            /// Create view model with mock driver
//            let viewModel = ContinuesMagementViewModel(
//                driver: mockDriver,
//                gameTitle: mockDriver.gameTitle,
//                systemTitle: mockDriver.systemTitle,
//                numberOfSaves: mockDriver.getAllSaveStates().count,
//                gameSize: mockDriver.gameSize,
//                gameImage: mockDriver.gameImage
//            )

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
                gameSize: Int(game.file.size / 1024), // Convert to KB
                gameImage: Image(systemName: "gamecontroller")
            )


            ContinuesMagementView(viewModel: viewModel)
                .onAppear {
                    /// Load initial states through the publisher
                    mockDriver.loadSaveStates(forGameId: "1")
                }
        }
    }
}
