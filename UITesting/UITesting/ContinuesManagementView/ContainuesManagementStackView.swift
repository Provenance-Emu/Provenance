//
//  ContainuesManagementStackView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes

public struct ContainuesManagementStackView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel
    /// Add state for tracking current swipe interaction
    @State private var currentUserInteractionCellID: String? = nil

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredAndSortedSaveStates) { saveState in
                    SaveStateRowView(
                        viewModel: saveState,
                        currentUserInteractionCellID: $currentUserInteractionCellID
                    )
                    .onReceive(viewModel.controlsViewModel.$isEditing) { isEditing in
                        withAnimation {
                            saveState.isEditing = isEditing
                        }
                    }
                }
            }
        }
    }
}

public struct ContinuesManagementContentView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel

    public var body: some View {
        VStack {
            ContinuesManagementListControlsView(viewModel: viewModel.controlsViewModel)
            ContainuesManagementStackView(viewModel: viewModel)
        }
    }
}

// MARK: - Previews

#Preview("Content View States") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    let viewModel = ContinuesMagementViewModel(
        driver: mockDriver,
        gameTitle: mockDriver.gameTitle,
        systemTitle: mockDriver.systemTitle,
        numberOfSaves: mockDriver.getAllSaveStates().count,
        gameSize: mockDriver.gameSize,
        gameImage: mockDriver.gameImage
    )

    /// Set the save states from the mock driver
    viewModel.saveStates = mockDriver.getAllSaveStates()

    return VStack {
        /// Normal state
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)

        /// Edit mode
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)
            .onAppear {
                viewModel.controlsViewModel.isEditing = true
            }
    }
    .padding()
}

#Preview("Dark Mode", traits: .defaultLayout) {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    let viewModel = ContinuesMagementViewModel(
        driver: mockDriver,
        gameTitle: mockDriver.gameTitle,
        systemTitle: mockDriver.systemTitle,
        numberOfSaves: mockDriver.getAllSaveStates().count,
        gameSize: mockDriver.gameSize,
        gameImage: mockDriver.gameImage
    )

    /// Set the save states from the mock driver
    viewModel.saveStates = mockDriver.getAllSaveStates()

    return ContinuesManagementContentView(viewModel: viewModel)
        .frame(height: 400)
        .padding()
}
