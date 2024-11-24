//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI

struct ContentView: View {
    var body: some View {
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

        return ContinuesMagementView(viewModel: viewModel)
            .onAppear {
                /// Set the save states from the mock driver
                mockDriver.saveStatesSubject.send(mockDriver.getAllSaveStates())
            }
    }
}

#Preview {
    ContentView()
}
