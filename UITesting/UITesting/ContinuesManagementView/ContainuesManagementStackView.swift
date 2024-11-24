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
    @State private var currentUserInteractionCellID: String? = nil
    @Binding var scrollOffset: CGFloat
    @State private var contentOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0

    public var body: some View {
        GeometryReader { outerGeometry in
            ScrollView(.vertical, showsIndicators: true) {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollViewOffsetPreferenceKey.self,
                        value: geometry.frame(in: .global).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 0) {
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
            .onAppear {
                scrollViewHeight = outerGeometry.size.height
                print("ScrollView height: \(scrollViewHeight)")
            }
            .onChange(of: outerGeometry.size.height) { newHeight in
                scrollViewHeight = newHeight
                print("ScrollView height changed to: \(newHeight)")
            }
        }
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            let newOffset = contentOffset - value
            if abs(newOffset - scrollOffset) > 1 {
                print("Content offset: \(value), calculated offset: \(newOffset)")
                scrollOffset = newOffset
            }
            contentOffset = value
        }
    }
}

public struct ContinuesManagementContentView: View {
    @ObservedObject var viewModel: ContinuesMagementViewModel
    @Binding var scrollOffset: CGFloat

    public var body: some View {
        VStack(spacing: 0) {
            ContinuesManagementListControlsView(viewModel: viewModel.controlsViewModel)
            ContainuesManagementStackView(viewModel: viewModel, scrollOffset: $scrollOffset)
        }
    }
}

// MARK: - Previews

//#Preview("Content View States") {
//    /// Create mock driver with sample data
//    let mockDriver = MockSaveStateDriver(mockData: true)
//
//    let viewModel = ContinuesMagementViewModel(
//        driver: mockDriver,
//        gameTitle: mockDriver.gameTitle,
//        systemTitle: mockDriver.systemTitle,
//        numberOfSaves: mockDriver.getAllSaveStates().count,
//        gameSize: mockDriver.gameSize,
//        gameImage: mockDriver.gameImage
//    )
//
//    struct PreviewWrapper: View {
//        @State private var scrollOffset: CGFloat = 0
//        let viewModel: ContinuesMagementViewModel
//        
//        var body: some View {
//            VStack {
//                /// Normal state
//                ContinuesManagementContentView(viewModel: viewModel, scrollOffset: $scrollOffset)
//                    .frame(height: 400)
//                    .onAppear {
//                        mockDriver.loadSaveStates(forGameId: "1")
//                    }
//
//                /// Edit mode
//                ContinuesManagementContentView(viewModel: viewModel, scrollOffset: $scrollOffset)
//                    .frame(height: 400)
//                    .onAppear {
//                        mockDriver.loadSaveStates(forGameId: "1")
//                        viewModel.controlsViewModel.isEditing = true
//                    }
//            }
//            .padding()
//        }
//    }
//    
//    PreviewWrapper(viewModel: viewModel)
//}
//
//#Preview("Dark Mode", traits: .defaultLayout) {
//    /// Create mock driver with sample data
//    let mockDriver = MockSaveStateDriver(mockData: true)
//
//    let viewModel = ContinuesMagementViewModel(
//        driver: mockDriver,
//        gameTitle: mockDriver.gameTitle,
//        systemTitle: mockDriver.systemTitle,
//        numberOfSaves: mockDriver.getAllSaveStates().count,
//        gameSize: mockDriver.gameSize,
//        gameImage: mockDriver.gameImage
//    )
//
//    struct PreviewWrapper: View {
//        @State private var scrollOffset: CGFloat = 0
//        let viewModel: ContinuesMagementViewModel
//        
//        var body: some View {
//            ContinuesManagementContentView(viewModel: viewModel, scrollOffset: $scrollOffset)
//                .frame(height: 400)
//                .padding()
//                .onAppear {
//                    mockDriver.loadSaveStates(forGameId: "1")
//                }
//        }
//    }
//    
//    PreviewWrapper(viewModel: viewModel)
//}
