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
    /// Maximum number of save states to load initially
    /// This can be adjusted or made into a user setting later
    static let initialSaveStateLimit: Int = 20

    /// Number of additional save states to load when approaching the end
    static let additionalSaveStateLoadCount: Int = 10

    /// Threshold for when to load more save states (when user is this many pages from the end)
    static let loadMoreThreshold: Int = 2

    @Published var currentPage: Int = 0
    @Published var selectedItemId: String?
    @Published var hasFocus: Bool = false
    @Published var isControllerConnected: Bool = GamepadManager.shared.isControllerConnected
    @Published var currentSaveState: PVSaveState?

    /// Total number of save states available (may be more than what's loaded)
    @Published var totalSaveStatesCount: Int = 0

    /// Current limit for how many save states to load
    @Published var currentLimit: Int = initialSaveStateLimit

    /// Flag to indicate if all save states have been loaded
    @Published var hasLoadedAllSaveStates: Bool = false

    /// Filtered save states from parent
    private var saveStates: [PVSaveState] = []
    private var isLandscapePhone: Bool = false

    var itemsPerPage: Int {
        isLandscapePhone ? 2 : 1
    }

    /// Calculate the number of pages based on currently loaded save states
    var pageCount: Int {
        max(1, Int(ceil(Double(saveStates.count) / Double(itemsPerPage))))
    }

    /// Check if we should load more save states based on current page
    var shouldLoadMoreSaveStates: Bool {
        guard !hasLoadedAllSaveStates else { return false }

        let pagesRemaining = pageCount - currentPage
        return pagesRemaining <= Self.loadMoreThreshold
    }

    func updateSaveStates(_ states: [PVSaveState], isLandscape: Bool, totalCount: Int) {
        saveStates = states
        isLandscapePhone = isLandscape
        totalSaveStatesCount = totalCount

        // Update hasLoadedAllSaveStates flag
        hasLoadedAllSaveStates = states.count >= totalCount

        // Update current save state if needed
        if currentSaveState == nil || !states.contains(currentSaveState!) {
            currentSaveState = states.first
        }
    }

    /// Increase the limit to load more save states
    func loadMoreSaveStates() {
        guard !hasLoadedAllSaveStates else {
            DLOG("ContinuesSectionViewModel: Already loaded all save states")
            return
        }

        let oldLimit = currentLimit
        let newLimit = min(currentLimit + Self.additionalSaveStateLoadCount, totalSaveStatesCount)

        if newLimit > currentLimit {
            currentLimit = newLimit
            DLOG("ContinuesSectionViewModel: Increasing save state limit from \(oldLimit) to \(newLimit) (total: \(totalSaveStatesCount))")
        } else {
            DLOG("ContinuesSectionViewModel: No need to increase limit, already at \(currentLimit) of \(totalSaveStatesCount)")
        }
    }

    func updateCurrentSaveState(forPage page: Int) {
        let startIndex = page * itemsPerPage
        guard startIndex < saveStates.count else { return }
        currentSaveState = saveStates[startIndex]
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

/// A floating footer view that displays metadata for the current save state
private struct ContinuesFooterView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let saveState: PVSaveState?
    let hideSystemLabel: Bool

    /// Constants for styling
    private enum Constants {
        static let overlayHeight: CGFloat = 60
        static let bottomPadding: CGFloat = 0 // Removed bottom padding
    }

    var body: some View {
        if let continueState = saveState, !continueState.isInvalidated {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let core = continueState.core {
                            // Retrowave-styled core name
                            Text("\(core.projectName): Continue...")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                            RetroTheme.retroBlue
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            // Retrowave-styled continue text
                            Text("Continue...")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                            RetroTheme.retroBlue
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        // Retrowave-styled game title
                        Text(continueState.game?.isInvalidated == true ? "Deleted" : (continueState.game?.title ?? "Deleted"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.5), radius: 1)
                    }
                    Spacer()
                    if !hideSystemLabel, let system = continueState.game?.system, !system.isInvalidated {
                        // Retrowave-styled system name
                        Text(system.name)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                RetroTheme.retroBlue,
                                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        RetroTheme.retroBlue,
                                        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
            }
            .frame(height: Constants.overlayHeight)
            .background(
                // Retrowave-style background with blur and grid
                ZStack {
                    // Blurred background
                    Color.black.opacity(0.7)
                        .blur(radius: 3)
                    
                    // Grid overlay for retrowave effect (subtle)
                    RetroTheme.RetroGridView()
                        .opacity(0.1)
                }
            )
            .overlay(
                // Top border glow
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .blur(radius: 0.5)
                    .opacity(0.7),
                alignment: .top
            )
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
    }
}

/// Custom page indicator with animated pills - retrowave styled
private struct CustomPageIndicator: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let numberOfPages: Int
    let currentPage: Int

    internal enum Constants {
        static let indicatorHeight: CGFloat = 4
        static let spacing: CGFloat = 8
        static let defaultWidth: CGFloat = 20
        static let selectedWidth: CGFloat = 32
        static let cornerRadius: CGFloat = 2
        static let bottomOffset: CGFloat = 100
        static let maxVisibleIndicators = 7 // Maximum number of indicators to show at once
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.spacing) {
                        ForEach(0..<numberOfPages, id: \.self) { index in
                            // Retrowave-styled indicator with glow effect
                            Capsule()
                                .fill(
                                    // Use AnyShapeStyle to handle different types
                                    currentPage == index ?
                                    AnyShapeStyle(LinearGradient(
                                        gradient: Gradient(colors: [
                                            themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                            RetroTheme.retroPurple
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )) :
                                    // Use solid color with opacity for non-selected indicators
                                    AnyShapeStyle((themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.5))
                                )
                                .frame(
                                    width: currentPage == index ? Constants.selectedWidth : Constants.defaultWidth,
                                    height: Constants.indicatorHeight
                                )
                                // Add glow effect to selected indicator
                                .shadow(color: currentPage == index ? 
                                        (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.8) : 
                                        Color.clear, 
                                        radius: 3)
                                .id(index)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .frame(minWidth: geometry.size.width)
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.indicatorHeight + 16) // Add padding for touch area
                }
                .onChange(of: currentPage) { newPage in
                    // Calculate visible range and scroll if needed
                    let halfVisible = Constants.maxVisibleIndicators / 2
                    if newPage >= halfVisible && newPage < numberOfPages - halfVisible {
                        withAnimation {
                            scrollProxy.scrollTo(newPage, anchor: .center)
                        }
                    } else if newPage < halfVisible {
                        withAnimation {
                            scrollProxy.scrollTo(0, anchor: .leading)
                        }
                    } else {
                        withAnimation {
                            scrollProxy.scrollTo(numberOfPages - 1, anchor: .trailing)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: Constants.indicatorHeight + 16)
    }
}

@available(iOS 15, tvOS 15, *)
struct HomeContinueSection: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Filtered save states based on console identifier
    @ObservedResults(
        PVSaveState.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) private var filteredSaveStates

    /// Total count of save states (without limit)
    @State private var totalSaveStatesCount: Int = 0

    /// Currently loaded save states (limited subset)
    @State private var limitedSaveStates: [PVSaveState] = []

    /// Flag to track if the view has appeared
    @State private var hasAppeared: Bool = false

    weak var rootDelegate: PVRootDelegate?
    let defaultHeight: CGFloat = 260
    var consoleIdentifier: String?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?

    @StateObject private var viewModel = ContinuesSectionViewModel()

    #if !os(tvOS)
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    /// Constants for styling
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 1.5
        static let containerPadding: CGFloat = 16
    }

    init(rootDelegate: PVRootDelegate?, consoleIdentifier: String?, parentFocusedSection: Binding<HomeSectionType?>, parentFocusedItem: Binding<String?>) {
        self.rootDelegate = rootDelegate
        self.consoleIdentifier = consoleIdentifier
        self._parentFocusedSection = parentFocusedSection
        self._parentFocusedItem = parentFocusedItem

        // Create the filter predicate based on console identifier
        let baseFilter = NSPredicate(format: "game != nil")
        let finalFilter: NSPredicate

        if let consoleId = consoleIdentifier {
            let consoleFilter = NSPredicate(format: "game.systemIdentifier == %@", consoleId)
            finalFilter = NSCompoundPredicate(andPredicateWithSubpredicates: [baseFilter, consoleFilter])
        } else {
            finalFilter = baseFilter
        }

        // Initialize with the filter but no limit
        _filteredSaveStates = ObservedResults(
            PVSaveState.self,
            filter: finalFilter,
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
        )

        // We'll set the total count when the view appears
        _totalSaveStatesCount = State(initialValue: 0)
    }

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

    /// Number of pages based on number of save states and items per page
    private var pageCount: Int {
        viewModel.pageCount
    }

    /// Grid columns configuration
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    // Add properties for navigation
    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?
    @State private var gamepadCancellable: AnyCancellable?
    @State private var selectedPage = 0

    var body: some SwiftUI.View {
        // Main container
        ZStack(alignment: .bottom) {
            // Container for all content with border
            ZStack(alignment: .bottom) {
                // Content layer
                VStack(spacing: 0) {
                    // TabView for continues
                    TabView(selection: $viewModel.currentPage) {
                        if !limitedSaveStates.isEmpty {
                            ForEach(0..<pageCount, id: \.self) { pageIndex in
                                SaveStatesGridView(
                                    pageIndex: pageIndex,
                                    filteredSaveStates: limitedSaveStates, // Use limited save states
                                    isLandscapePhone: isLandscapePhone,
                                    gridColumns: gridColumns,
                                    adjustedHeight: adjustedHeight,
                                    hideSystemLabel: consoleIdentifier != nil,
                                    rootDelegate: rootDelegate,
                                    parentFocusedSection: $parentFocusedSection,
                                    parentFocusedItem: $parentFocusedItem,
                                    viewModel: viewModel
                                )
                                .id(pageIndex)
                                .tag(pageIndex)
                            }
                        } else {
                            EmptyContinuesView()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .frame(height: adjustedHeight)

                // Footer and page indicator overlay
                ZStack {
                    // Footer at bottom
                    ContinuesFooterView(
                        saveState: viewModel.currentSaveState,
                        hideSystemLabel: consoleIdentifier != nil
                    )
                    .zIndex(0) // Ensure footer is behind

                    // Page Indicator floating over footer
                    if pageCount > 1 {
                        CustomPageIndicator(
                            numberOfPages: pageCount,
                            currentPage: viewModel.currentPage
                        )
                        .zIndex(1) // Ensure indicator is in front
                        .offset(y: -35) // Position it over the footer
                    }
                }
            }
            // Retrowave-style border with gradient and glow
            .background(
                // Retrowave-style background
                ZStack {
                    // Dark background
                    Color.black.opacity(0.8)
                    
                    // Grid overlay for retrowave effect
                    RetroTheme.RetroGridView()
                        .opacity(0.15)
                }
            )
            // Neon border with gradient
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: Constants.borderWidth
                    )
            )
            // Add subtle glow effect
            .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.6), radius: 5)
            //.padding(.top, 4) // Add top padding to the bordered container
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            setupGamepadHandling()
            #if !os(tvOS)
            hapticGenerator.prepare()
            #endif

            // Only update the limit when the view first appears
            if !hasAppeared {
                hasAppeared = true

                // Set the total count from the filtered save states
                totalSaveStatesCount = filteredSaveStates.count
                DLOG("HomeContinueSection: Total save states count: \(totalSaveStatesCount)")

                // Initialize with the initial limit
                updateSaveStateLimit(ContinuesSectionViewModel.initialSaveStateLimit)
            }
        }
        .onDisappear {
            // Cancel all tasks and subscriptions
            gamepadCancellable?.cancel()
            delayTask?.cancel()
            continuousNavigationTask?.cancel()
        }
        .onChange(of: filteredSaveStates) { newValue in
            // Use weak self to prevent retain cycles
            Task {
                await MainActor.run {
                    // Update total count
                    self.totalSaveStatesCount = newValue.count
                    DLOG("HomeContinueSection: Total save states changed to \(self.totalSaveStatesCount)")

                    // Update limited save states with current limit
                    self.updateSaveStateLimit(self.viewModel.currentLimit)
                }
            }
        }
        .onChange(of: viewModel.currentPage) { newPage in
            handlePageChange(newPage)
            viewModel.updateCurrentSaveState(forPage: newPage)

            // Check if we need to load more save states
            if viewModel.shouldLoadMoreSaveStates {
                viewModel.loadMoreSaveStates()
                updateSaveStateLimit(viewModel.currentLimit)
            }

            #if !os(tvOS)
            hapticGenerator.impactOccurred()
            #endif
        }
    }

    /// Updates the limit on the save states by manually filtering the results
    private func updateSaveStateLimit(_ newLimit: Int) {
        DLOG("HomeContinueSection: Updating save state limit to \(newLimit) (total available: \(totalSaveStatesCount))")

        // Take only the first newLimit items from filteredSaveStates
        let allSaveStates = Array(filteredSaveStates)
        let limitedCount = min(newLimit, allSaveStates.count)

        // Update the limited save states
        limitedSaveStates = Array(allSaveStates.prefix(limitedCount))

        // Update the view model with the limited save states
        viewModel.updateSaveStates(limitedSaveStates, isLandscape: isLandscapePhone, totalCount: totalSaveStatesCount)
    }

    private func setupGamepadHandling() {
        // Cancel existing handler if it exists
        gamepadCancellable?.cancel()

        // Use weak self to prevent retain cycles
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                // Only handle events if this view is currently visible
                guard !viewModel.isControllerConnected else { return }

                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        handleButtonPress()
                    }
                case .horizontalNavigation(let value, let isPressed):
                    if isPressed {
                        handleHorizontalNavigation(value)
                    }
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        if let focused = parentFocusedItem,
           let saveState = limitedSaveStates.first(where: { $0.id == focused }) {
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

        let items = limitedSaveStates.map { $0.id }
        DLOG("HomeContinueSection: Navigation - Total items: \(items.count)")

        guard !items.isEmpty else {
            DLOG("HomeContinueSection: No items available")
            return
        }

        // Get current index
        let currentIndex: Int
        if let currentItem = parentFocusedItem,
           let index = items.firstIndex(of: currentItem) {
            currentIndex = index
            DLOG("HomeContinueSection: Current index: \(currentIndex)")
        } else {
            currentIndex = 0
            DLOG("HomeContinueSection: No current selection, starting at 0")
        }

        // Calculate next index
        let nextIndex: Int
        if value < 0 {
            nextIndex = currentIndex > 0 ? currentIndex - 1 : items.count - 1
            DLOG("HomeContinueSection: Moving left to index: \(nextIndex)")
        } else {
            nextIndex = currentIndex < items.count - 1 ? currentIndex + 1 : 0
            DLOG("HomeContinueSection: Moving right to index: \(nextIndex)")
        }

        // Update selection
        parentFocusedItem = items[nextIndex]

        // Calculate and update page based on items per page
        let itemsPerPage = isLandscapePhone ? 2 : 1
        let newPage = nextIndex / itemsPerPage

        DLOG("HomeContinueSection: Items per page: \(itemsPerPage), New page: \(newPage)")

        // Ensure TabView updates with animation
        withAnimation {
            viewModel.currentPage = newPage
        }

        // Check if we need to load more save states
        if newPage >= viewModel.pageCount - ContinuesSectionViewModel.loadMoreThreshold && !viewModel.hasLoadedAllSaveStates {
            viewModel.loadMoreSaveStates()
            updateSaveStateLimit(viewModel.currentLimit)
        }

        DLOG("HomeContinueSection: Final state - Page: \(newPage), Item: \(items[nextIndex]), Items per page: \(itemsPerPage)")
    }

    private func handlePageChange(_ newPage: Int) {
        let itemsPerPage = isLandscapePhone ? 2 : 1
        let items = limitedSaveStates.map { $0.id }

        DLOG("HomeContinueSection: Page changed to \(newPage)")

        // Calculate the first item index for this page
        let firstItemIndex = newPage * itemsPerPage
        guard firstItemIndex < items.count else {
            DLOG("HomeContinueSection: Invalid page index")
            return
        }

        // If we're not already focused on an item on this page, update focus
        if let currentItem = parentFocusedItem,
           let currentIndex = items.firstIndex(of: currentItem) {
            let currentPage = currentIndex / itemsPerPage
            if currentPage != newPage {
                DLOG("HomeContinueSection: Updating focus to match new page")
                parentFocusedSection = .recentSaveStates
                parentFocusedItem = items[firstItemIndex]
            }
        } else {
            // No current focus, set it to first item on page
            DLOG("HomeContinueSection: No current focus, setting to first item on page")
            parentFocusedSection = .recentSaveStates
            parentFocusedItem = items[firstItemIndex]
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

    private var saveStatesForPage: [PVSaveState] {
        let startIndex = pageIndex * viewModel.itemsPerPage
        let endIndex = min(startIndex + viewModel.itemsPerPage, filteredSaveStates.count)

        // Safety check to prevent out of bounds
        guard startIndex < filteredSaveStates.count, endIndex <= filteredSaveStates.count else {
            return []
        }

        return Array(filteredSaveStates[startIndex..<endIndex])
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(saveStatesForPage, id: \.id) { saveState in
                HomeContinueItemView(
                    continueState: saveState,
                    height: adjustedHeight,
                    hideSystemLabel: hideSystemLabel,
                    action: {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(
                                saveState.game,
                                sender: self,
                                core: saveState.core,
                                saveState: saveState
                            )
                        }
                    },
                    isFocused: (parentFocusedSection == .recentSaveStates && parentFocusedItem == saveState.id) && viewModel.isControllerConnected,
                    rootDelegate: rootDelegate
                )
                .focusableIfAvailable()
                .onChange(of: parentFocusedItem) { newValue in
                    if newValue == saveState.id {
                        parentFocusedSection = .recentSaveStates
                    }
                }
            }
        }
        .padding(.horizontal) // Add padding inside the container
        .onAppear {
            // Check if we need to load more save states when this page appears
            if pageIndex >= viewModel.pageCount - ContinuesSectionViewModel.loadMoreThreshold && !viewModel.hasLoadedAllSaveStates {
                viewModel.loadMoreSaveStates()
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
