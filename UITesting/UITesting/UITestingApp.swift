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
            let mockDriver = MockSaveStateDriver(mockData: true)

            /// Create view model with mock driver
            let viewModel = ContinuesMagementViewModel(
                driver: mockDriver,
                gameTitle: mockDriver.gameTitle,
                systemTitle: mockDriver.systemTitle,
                numberOfSaves: mockDriver.getAllSaveStates().count,
                gameSize: mockDriver.gameSize,
                gameImage: mockDriver.gameImage
            )

            ContinuesMagementView(viewModel: viewModel)
                .onAppear {
                    /// Set the save states from the mock driver
                    viewModel.saveStates = mockDriver.getAllSaveStates()
                }
        }
    }
}
