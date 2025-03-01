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
    @State private var searchBarVisible = true

    private let searchBarHeight: CGFloat = 52

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ContinuesSearchBar(text: $viewModel.searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.clear)
                        .opacity(searchBarVisible && !viewModel.controlsViewModel.isEditing ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: searchBarVisible)

                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.filteredAndSortedSaveStates) { saveState in
                            SaveStateRowView(
                                viewModel: saveState,
                                currentUserInteractionCellID: $currentUserInteractionCellID)
                                .id(saveState.id)
                        }
                    }
                    .padding(.top, 1)
                }
            }
            .coordinateSpace(name: "scroll")
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: viewModel.controlsViewModel.isEditing) { isEditing in
                if isEditing {
                    withAnimation {
                        searchBarVisible = false
                        viewModel.searchText = ""
                    }
                }
            }
            .onScroll { offset in
                let scrollThreshold: CGFloat = 10
                withAnimation(.easeInOut(duration: 0.2)) {
                    if offset.y < -scrollThreshold && searchBarVisible {
                        searchBarVisible = false
                    } else if offset.y > scrollThreshold && !searchBarVisible {
                        searchBarVisible = true
                    }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func onScroll(perform: @escaping (CGPoint) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).origin
                )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            perform(offset)
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
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
@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
#Preview("Content View States") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    let viewModel = ContinuesMagementViewModel(
        driver: mockDriver,
        gameTitle: mockDriver.gameTitle,
        systemTitle: mockDriver.systemTitle,
        numberOfSaves: mockDriver.getAllSaveStates().count,
        gameUIImage: mockDriver.gameUIImage,
        onLoadSave: { id in
            print("load save \(id)")
        }
    )

    VStack {
        /// Normal state
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)
            .onAppear {
                mockDriver.gameId = "1"  // Set the game ID filter
            }

        /// Edit mode
        ContinuesManagementContentView(viewModel: viewModel)
            .frame(height: 400)
            .onAppear {
                mockDriver.gameId = "1"  // Set the game ID filter
                viewModel.controlsViewModel.isEditing = true
            }
    }
    .padding()
}

@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
#Preview("Dark Mode") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    let viewModel = ContinuesMagementViewModel(
        driver: mockDriver,
        gameTitle: mockDriver.gameTitle,
        systemTitle: mockDriver.systemTitle,
        numberOfSaves: mockDriver.getAllSaveStates().count,
        gameUIImage: mockDriver.gameUIImage,
        onLoadSave: { id in
            print("load save \(id)")
        })

    ContinuesManagementContentView(viewModel: viewModel)
        .frame(height: 400)
        .padding()
        .onAppear {
            mockDriver.gameId = "1"  // Set the game ID filter
        }
}

#endif
