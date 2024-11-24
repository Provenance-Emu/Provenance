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
    let viewModel = ContinuesMagementViewModel(
        gameTitle: "Bomber Man",
        systemTitle: "Game Boy",
        numberOfSaves: 34,
        gameSize: 15,
        gameImage: Image(systemName: "gamecontroller")
    )

    /// Add some sample save states
    viewModel.saveStates = [
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Final Boss"
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-3600),
            thumbnailImage: Image(systemName: "gamecontroller")
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-7200),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Power Up Location"
        )
    ]

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
    let viewModel = ContinuesMagementViewModel(
        gameTitle: "Bomber Man",
        systemTitle: "Game Boy",
        numberOfSaves: 34,
        gameSize: 15,
        gameImage: Image(systemName: "gamecontroller")
    )

    return ContinuesManagementContentView(viewModel: viewModel)
        .frame(height: 400)
        .padding()
}
