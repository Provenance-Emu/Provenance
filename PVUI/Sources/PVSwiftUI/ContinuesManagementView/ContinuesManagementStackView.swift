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
    @State private var lastScrollPosition: CGFloat = 0
    @State private var showSearchBar = false
    
    private let searchBarHeight: CGFloat = 52 // Height of search bar + padding
    
    public var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ContinuesSearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .opacity(showSearchBar && !viewModel.controlsViewModel.isEditing ? 1 : 0)
                    .frame(height: showSearchBar && !viewModel.controlsViewModel.isEditing ? searchBarHeight : 0, alignment: .top)
                    .clipped()
                    .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: showSearchBar)
                    .onChange(of: viewModel.controlsViewModel.isEditing) { isEditing in
                        if isEditing {
                            withAnimation {
                                showSearchBar = false
                                viewModel.searchText = ""
                            }
                        }
                    }
                
                ScrollView {
                    GeometryReader { geometry in
                        Color.clear.onChange(of: geometry.frame(in: .named("scroll")).minY) { position in
                            let scrollDelta = position - lastScrollPosition
                            if abs(scrollDelta) > 3 {  
                                withAnimation {
                                    showSearchBar = scrollDelta > 0 || position > -3
                                }
                            }
                            lastScrollPosition = position
                        }
                    }
                    .frame(height: 0)
                    
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
                .coordinateSpace(name: "scroll")
                .foregroundStyle(viewModel.scrollViewScrollIndicatorColor)
            }
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
#if DEBUG

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

#Preview("Dark Mode") {
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

#endif
