//
//  ContinuesManagementStackView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVThemes

/// Class to hold edit state that won't cause view hierarchy changes
@MainActor
public class SaveStateEditState: ObservableObject {
    /// The text being edited
    @Published
    var text: String = ""
    /// The save state being edited
    @Published
    var saveState: SaveStateRowViewModel?
    /// The field being edited
    @Published
    var field: SaveStateEditField?

    /// Computed property to check if editing is active
    var isEditing: Bool {
        field != nil
    }

    /// Reset the edit state
    func reset() {
        text = ""
        saveState = nil
        field = nil
    }

    /// Start editing a field
    func startEditing(_ field: SaveStateEditField, saveState: SaveStateRowViewModel, initialValue: String?) {
        self.field = field
        self.saveState = saveState
        self.text = initialValue ?? ""
    }
}

public struct ContinuesManagementStackView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel
    @State private var currentUserInteractionCellID: String? = nil
    @State private var searchBarVisible = true

    /// Create a bindable wrapper for the edit state
    @StateObject private var bindableEditState = SaveStateEditState()

    private let searchBarHeight: CGFloat = 52

    /// Function to handle edit requests from save state rows
    private func handleEdit(_ field: SaveStateEditField, saveState: SaveStateRowViewModel, initialValue: String?) {
        Task { @MainActor in
            bindableEditState.startEditing(field, saveState: saveState, initialValue: initialValue)
        }
    }

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
                                currentUserInteractionCellID: $currentUserInteractionCellID,
                                onEdit: handleEdit)
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
        .alert("Edit Description", isPresented: Binding(
            get: {
                // Access the field property on the main actor
                let field = bindableEditState.field
                return field == .description
            },
            set: { isPresented in
                if !isPresented {
                    Task { @MainActor in
                        bindableEditState.field = nil
                    }
                }
            }
        )) {
            // Use a local state variable for the text field to avoid actor isolation issues
            let textBinding = Binding(
                get: { bindableEditState.text },
                set: { newValue in
                    Task { @MainActor in
                        bindableEditState.text = newValue
                    }
                }
            )

            TextField("Description", text: textBinding)
                #if !os(tvOS)
                .textInputAutocapitalization(.words)
                #endif
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {
                Task { @MainActor in
                    bindableEditState.reset()
                }
            }
            Button("Save") {
                Task { @MainActor in
                    if let saveState = bindableEditState.saveState {
                        saveState.description = bindableEditState.text
                        viewModel.updateSaveState(saveState)
                    }
                    bindableEditState.reset()
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
                    key: ScrollOffsetPointPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).origin
                )
            }
        )
        .onPreferenceChange(ScrollOffsetPointPreferenceKey.self) { offset in
            perform(offset)
        }
    }
}

private struct ScrollOffsetPointPreferenceKey: PreferenceKey {
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
