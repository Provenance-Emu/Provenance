//
//  ContinuesManagementStackView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes

public struct ContinuesManagementStackView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel
    @State private var currentUserInteractionCellID: String? = nil

    public var body: some View {
        VStack(spacing: 8) {
            SearchBar(text: $viewModel.searchText)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredAndSortedSaveStates, id: \.id) { saveState in
                        SaveStateRowView(
                            viewModel: saveState,
                            currentUserInteractionCellID: $currentUserInteractionCellID
                        )
                        .onReceive(viewModel.controlsViewModel.$isEditing) { isEditing in
                            withAnimation {
                                saveState.isEditing = isEditing
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.filteredAndSortedSaveStates)
            }
            .foregroundStyle(viewModel.scrollViewScrollIndicatorColor)
        }
    }
}

public struct ContinuesManagementContentView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel

    public var body: some View {
        VStack {
            ContinuesManagementListControlsView(viewModel: viewModel.controlsViewModel)
            ContinuesManagementStackView(viewModel: viewModel)
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

    VStack {
        /// Normal state
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)
            .onAppear {
                mockDriver.loadSaveStates(forGameId: "1")
            }

        /// Edit mode
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)
            .onAppear {
                mockDriver.loadSaveStates(forGameId: "1")
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

    ContinuesManagementContentView(viewModel: viewModel)
        .frame(height: 400)
        .padding()
        .onAppear {
            mockDriver.loadSaveStates(forGameId: "1")
        }
}
