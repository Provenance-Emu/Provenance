//
//  HomeContinueSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import Combine

class ContinuesSectionViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var selectedItemId: String?
    @Published var hasFocus: Bool = false

    /// Filtered save states from parent
    private var saveStates: [PVSaveState] = []
    private var isLandscapePhone: Bool = false

    var itemsPerPage: Int {
        isLandscapePhone ? 2 : 1
    }

    func updateSaveStates(_ states: [PVSaveState], isLandscape: Bool) {
        saveStates = states
        isLandscapePhone = isLandscape
    }

    func handleHorizontalNavigation(_ value: Float) -> (nextItemId: String?, nextPage: Int)? {
        guard !saveStates.isEmpty else {
            DLOG("ContinuesSectionViewModel: No items available")
            return nil
        }

        let items = saveStates.map { $0.id }

        // Get current index
        let currentIndex: Int
        if let selectedId = selectedItemId,
           let index = items.firstIndex(of: selectedId) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        // Calculate next index
        let nextIndex: Int
        if value < 0 {
            nextIndex = currentIndex > 0 ? currentIndex - 1 : items.count - 1
        } else {
            nextIndex = currentIndex < items.count - 1 ? currentIndex + 1 : 0
        }

        guard nextIndex >= 0 && nextIndex < items.count else { return nil }

        let nextPage = nextIndex / itemsPerPage
        return (items[nextIndex], nextPage)
    }
}

@available(iOS 15, tvOS 15, *)
struct HomeContinueSection: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @ObservedResults(
        PVSaveState.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var allSaveStates

    weak var rootDelegate: PVRootDelegate?
    let defaultHeight: CGFloat = 260
    var consoleIdentifier: String?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    @StateObject private var viewModel = ContinuesSectionViewModel()

    var isLandscapePhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone &&
               verticalSizeClass == .compact
        #else
        return false
        #endif
    }

    var adjustedHeight: CGFloat {
        isLandscapePhone ? defaultHeight / 2 : defaultHeight
    }

    var columns: Int {
        isLandscapePhone ? 2 : 1
    }

    var filteredSaveStates: [PVSaveState] {
        let validSaveStates = allSaveStates.filter { !$0.isInvalidated }

        if let consoleIdentifier = consoleIdentifier {
            return validSaveStates.filter {
                !$0.game.isInvalidated &&
                $0.game.systemIdentifier == consoleIdentifier
            }
        } else {
            return validSaveStates.filter { !$0.game.isInvalidated }
        }
    }

    var gridColumns: [GridItem] {
        if isLandscapePhone {
            [GridItem(.flexible()), GridItem(.flexible())]
        } else {
            [GridItem(.flexible())]
        }
    }

    // Add properties for navigation
    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?
    @State private var gamepadCancellable: AnyCancellable?
    @State private var selectedPage = 0

    var body: some SwiftUI.View {
        TabView(selection: $viewModel.currentPage) {
            if filteredSaveStates.count > 0 {
                ForEach(0..<pageCount, id: \.self) { pageIndex in
                    SaveStatesGridView(
                        pageIndex: pageIndex,
                        filteredSaveStates: filteredSaveStates,
                        isLandscapePhone: isLandscapePhone,
                        gridColumns: gridColumns,
                        adjustedHeight: adjustedHeight,
                        hideSystemLabel: consoleIdentifier != nil,
                        rootDelegate: rootDelegate,
                        parentFocusedSection: $parentFocusedSection,
                        parentFocusedItem: $parentFocusedItem,
                        viewModel: viewModel
                    )
                    .padding(.horizontal)
                    .tag(pageIndex)
                }
            } else {
                EmptyContinuesView()
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(filteredSaveStates.count)
        .frame(height: adjustedHeight)
        .onAppear {
            setupGamepadHandling()
        }
        .onDisappear {
            gamepadCancellable?.cancel()
            delayTask?.cancel()
            continuousNavigationTask?.cancel()
        }
        .onChange(of: filteredSaveStates) { newValue in
            viewModel.updateSaveStates(newValue, isLandscape: isLandscapePhone)
        }
    }

    // Computed property for page count
    private var pageCount: Int {
        if isLandscapePhone {
            return (filteredSaveStates.count + 1) / 2
        } else {
            return filteredSaveStates.count
        }
    }

    private func setupGamepadHandling() {
        DLOG("HomeContinueSection: Setting up gamepad handling")
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] event in
                DLOG("HomeContinueSection: Received gamepad event: \(event)")
                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        DLOG("HomeContinueSection: Button pressed")
                        handleButtonPress()
                    }
                case .horizontalNavigation(let value, let isPressed):
                    if isPressed {
                        DLOG("HomeContinueSection: Horizontal navigation: \(value)")
                        handleHorizontalNavigation(value)
                    }
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        if let focused = parentFocusedItem,
           let saveState = filteredSaveStates.first(where: { $0.id == focused }) {
            Task.detached { @MainActor in
                await self.rootDelegate?.root_load(
                    saveState.game,
                    sender: self,
                    core: saveState.core,
                    saveState: saveState
                )
            }
        }
    }

    private func handleHorizontalNavigation(_ value: Float) {
        guard parentFocusedSection == .recentSaveStates else { return }

        if let (nextItemId, nextPage) = viewModel.handleHorizontalNavigation(value) {
            parentFocusedItem = nextItemId
            withAnimation {
                viewModel.currentPage = nextPage
            }
        }
    }
}

// Create a new struct for the grid view
private struct SaveStatesGridView: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let isLandscapePhone: Bool
    let gridColumns: [GridItem]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    @ObservedObject var viewModel: ContinuesSectionViewModel

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            if isLandscapePhone {
                LandscapeGridContent(
                    pageIndex: pageIndex,
                    filteredSaveStates: filteredSaveStates,
                    adjustedHeight: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            } else {
                PortraitGridContent(
                    pageIndex: pageIndex,
                    filteredSaveStates: filteredSaveStates,
                    adjustedHeight: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            }
        }
    }
}

// Create separate views for landscape and portrait content
private struct LandscapeGridContent: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        let startIndex = pageIndex * 2
        let endIndex = min(startIndex + 2, filteredSaveStates.count)

        ForEach(startIndex..<endIndex, id: \.self) { index in
            if index < filteredSaveStates.count {
                ContinueItemWrapper(
                    saveState: filteredSaveStates[index],
                    height: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    rootDelegate: rootDelegate,
                    parentFocusedSection: $parentFocusedSection,
                    parentFocusedItem: $parentFocusedItem
                )
            }
        }
    }
}

private struct PortraitGridContent: View {
    let pageIndex: Int
    let filteredSaveStates: [PVSaveState]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        if pageIndex < filteredSaveStates.count {
            ContinueItemWrapper(
                saveState: filteredSaveStates[pageIndex],
                height: adjustedHeight,
                hideSystemLabel: hideSystemLabel,
                rootDelegate: rootDelegate,
                parentFocusedSection: $parentFocusedSection,
                parentFocusedItem: $parentFocusedItem
            )
        }
    }
}

private struct ContinueItemWrapper: View {
    let saveState: PVSaveState
    let height: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    var body: some View {
        HomeContinueItemView(
            continueState: saveState,
            height: height,
            hideSystemLabel: hideSystemLabel,
            action: {
                DLOG("ContinueItemWrapper: Action triggered for save state: \(saveState.id)")
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(
                        saveState.game,
                        sender: self,
                        core: saveState.core,
                        saveState: saveState
                    )
                }
            },
            isFocused: {
                let isFocused = parentFocusedSection == .recentSaveStates && parentFocusedItem == saveState.id
                DLOG("ContinueItemWrapper: Checking focus for \(saveState.id) - Section: \(String(describing: parentFocusedSection)), Item: \(String(describing: parentFocusedItem)) = \(isFocused)")
                return isFocused
            }()
        )
        .focusableIfAvailable()
        .onChange(of: parentFocusedItem) { newValue in
            DLOG("ContinueItemWrapper: Parent focused item changed to: \(String(describing: newValue))")
            if newValue == saveState.id {
                DLOG("ContinueItemWrapper: Setting section to recentSaveStates")
                parentFocusedSection = .recentSaveStates
            }
        }
    }
}

private struct EmptyContinuesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Text("No Continues")
            .tag("no continues")
            .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
    }
}

#endif
