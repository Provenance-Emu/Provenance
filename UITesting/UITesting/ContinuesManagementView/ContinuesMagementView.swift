//
//  ContinuesMagementView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PopupView
import ScalingHeaderScrollView
import AnimatedGradient
import PVThemes
import Combine
import RealmSwift
import OpenDateInterval

/// View model for the main continues management view
public class ContinuesMagementViewModel: ObservableObject {
    /// Header view model
    @Published var headerViewModel: ContinuesManagementHeaderViewModel
    /// Controls view model
    @Published var controlsViewModel: ContinuesManagementListControlsViewModel
    @Published private(set) var saveStates: [SaveStateRowViewModel] = []

    private let driver: SaveStateDriver
    private var cancellables = Set<AnyCancellable>()

    /// Computed property for filtered and sorted states
    @Published private(set) var filteredAndSortedSaveStates: [SaveStateRowViewModel] = [] {
        didSet {
            headerViewModel.numberOfSaves = filteredAndSortedSaveStates.count
        }
    }

    private func setupObservers() {
        /// Create a publisher that combines all filter criteria
        let filterPublisher = Publishers.CombineLatest4(
            controlsViewModel.$filterFavoritesOnly,
            controlsViewModel.$isAutoSavesEnabled,
            controlsViewModel.$dateRange,
            controlsViewModel.$sortAscending
        )

        /// Combine save states with filter criteria
        Publishers.CombineLatest(
            $saveStates,
            filterPublisher
        )
        .map { [weak self] states, filterCriteria in
            let (favoritesOnly, autoSavesEnabled, dateRange, sortAscending) = filterCriteria
            return self?.applyFilters(
                to: states,
                favoritesOnly: favoritesOnly,
                autoSavesEnabled: autoSavesEnabled,
                dateRange: dateRange,
                sortAscending: sortAscending
            ) ?? []
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$filteredAndSortedSaveStates)
    }

    private func applyFilters(
        to states: [SaveStateRowViewModel],
        favoritesOnly: Bool,
        autoSavesEnabled: Bool,
        dateRange: OpenDateInterval?,
        sortAscending: Bool
    ) -> [SaveStateRowViewModel] {
        states
            .filter { state in
                /// Apply date range filter
                if let dateRange = dateRange {
                    let isAfterStart = state.saveDate >= dateRange.start
                    let isBeforeEnd = dateRange.end.map { state.saveDate <= $0 } ?? true
                    if !isAfterStart || !isBeforeEnd { return false }
                }

                /// Apply favorites filter
                if favoritesOnly && !state.isFavorite { return false }

                /// Apply auto-save filter
                if !autoSavesEnabled && state.isAutoSave { return false }

                return true
            }
            .sorted { first, second in
                /// Sort by pin status first
                if first.isPinned != second.isPinned {
                    return first.isPinned
                }
                /// Then by date
                return sortAscending ? first.saveDate < second.saveDate : first.saveDate > second.saveDate
            }
    }

    private func observeRowViewModel(_ viewModel: SaveStateRowViewModel) {
        /// Observe pin changes
        viewModel.$isPinned
            .dropFirst()
            .sink { [weak self] isPinned in
                self?.driver.setPin(saveStateId: viewModel.id, isPinned: isPinned)
                self?.refilterStates()
            }
            .store(in: &cancellables)

        /// Observe favorite changes
        viewModel.$isFavorite
            .dropFirst()
            .sink { [weak self] isFavorite in
                self?.driver.setFavorite(saveStateId: viewModel.id, isFavorite: isFavorite)
                self?.refilterStates()
            }
            .store(in: &cancellables)

        /// Observe description changes
        viewModel.$description
            .dropFirst()
            .sink { [weak self] description in
                self?.driver.updateDescription(saveStateId: viewModel.id, description: description)
            }
            .store(in: &cancellables)
    }

    private func refilterStates() {
        objectWillChange.send()
        let states = saveStates
        saveStates = states // Trigger filter update
    }

    public init(
        driver: SaveStateDriver,
        gameTitle: String,
        systemTitle: String,
        numberOfSaves: Int,
        gameSize: Int,
        gameImage: Image
    ) {
        self.driver = driver
        self.headerViewModel = ContinuesManagementHeaderViewModel(
            gameTitle: gameTitle,
            systemTitle: systemTitle,
            numberOfSaves: numberOfSaves,
            gameSize: gameSize,
            gameImage: gameImage
        )
        self.controlsViewModel = ContinuesManagementListControlsViewModel()

        
        self.controlsViewModel = ContinuesManagementListControlsViewModel(
            onDeleteSelected: { [weak self] in
                self?.deleteSelectedSaveStates()
            },
            onSelectAll: { [weak self] in
                self?.selectAllSaveStates()
            },
            onClearAll: { [weak self] in
                self?.clearAllSelections()
            }
        )
        
        setupObservers()
    }

    /// Select all save states
    private func selectAllSaveStates() {
        saveStates.forEach { $0.isSelected = true }
    }

    /// Clear all selections
    private func clearAllSelections() {
        saveStates.forEach { $0.isSelected = false }
    }

    /// Select a save state
    private func selectSaveState(id: String) {
        if let index = saveStates.firstIndex(where: { $0.id == id }) {
            saveStates[index].isSelected = true
        }
    }

    /// Deselect a save state
    private func deselectSaveState(id: String) {
        if let index = saveStates.firstIndex(where: { $0.id == id }) {
            saveStates[index].isSelected = false
        }
    }

    /// Delete selected save states
    private func deleteSelectedSaveStates() {
        // Implement delete functionality
    }

    /// Subscribe to driver's save states publisher
    func subscribeToDriverPublisher() {
        driver.saveStatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                self?.saveStates = states
                /// Setup observers for each row view model
                states.forEach { self?.observeRowViewModel($0) }
            }
            .store(in: &cancellables)
    }
}

public struct ContinuesMagementView: View {
    /// Main view model
    @StateObject private var viewModel: ContinuesMagementViewModel
    @State var showingPopup = false
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(viewModel: ContinuesMagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            /// Header view
            VStack {
                ZStack {
                    AnimatedLinearGradient(colors: [
                        .Provenance.blue,
                        currentPalette.settingsCellBackground!.swiftUIColor,
                        currentPalette.gameLibraryBackground.swiftUIColor,
                        currentPalette.settingsCellBackground!.swiftUIColor])
                    .numberOfSimultaneousColors(2)
                    .setAnimation(.bouncy(duration: 10))
                    .gradientPoints(start: .bottomLeading, end: .topTrailing)
                    .padding(.bottom, 10)
                    .opacity(0.25)

                    ContinuesManagementHeaderView(viewModel: viewModel.headerViewModel)
                }
                .frame(height: 160)
                .shadow(radius: 5)
            }
            .clipShape(RoundedCorners(radius: 20, corners: [.bottomLeft, .bottomRight]))

            /// List view
            ZStack {
                AnimatedLinearGradient(colors: [
                    .Provenance.blue,
                    currentPalette.settingsCellBackground!.swiftUIColor,
                    currentPalette.gameLibraryBackground.swiftUIColor,
                    currentPalette.settingsCellBackground!.swiftUIColor])
                .numberOfSimultaneousColors(2)
                .setAnimation(.bouncy(duration: 10))
                .gradientPoints(start: .topTrailing, end: .bottomLeading)
                .padding(.bottom, 10)
                .opacity(0.25)
                ContinuesManagementContentView(viewModel: viewModel)
            }
            .background(currentPalette.settingsCellBackground!.swiftUIColor)
            .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))

        }
        .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
//        .background(currentPalette.settingsCellBackground!.swiftUIColor)
        .padding()
        .onAppear {
            viewModel.subscribeToDriverPublisher()
        }
    }
}

/// Custom shape for top-only rounded corners
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Swift UI Previews

#if DEBUG

#Preview("Continues Management") {
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

    ContinuesMagementView(viewModel: viewModel)
        .onAppear {
            let theme = CGAThemes.purple
            ThemeManager.shared.setCurrentPalette(theme.palette)

            /// Initial states will be set through the publisher
            mockDriver.saveStatesSubject.send(mockDriver.getAllSaveStates())
        }
}

#Preview("Continues Management with Realm") {
    /// Create in-memory test realm and driver
    let testRealm = try! RealmSaveStateTestFactory.createInMemoryRealm()
    let driver = try! RealmSaveStateDriver(realm: testRealm)

    /// Get the first game from realm for the view model
    let game = testRealm.objects(PVGame.self).first!

    /// Create view model with game data
    let viewModel = ContinuesMagementViewModel(
        driver: driver,
        gameTitle: game.title,
        systemTitle: "Game Boy",
        numberOfSaves: game.saveStates.count,
        gameSize: Int(game.file.size / 1024), // Convert to KB
        gameImage: Image(systemName: "gamecontroller")
    )

    ContinuesMagementView(viewModel: viewModel)
        .onAppear {
            let theme = CGAThemes.purple
            ThemeManager.shared.setCurrentPalette(theme.palette)

            /// Load states through the publisher
            driver.loadSaveStates(forGameId: game.id)
        }
}

#Preview("Continues Management with Mock Driver") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    /// Create view model using mock driver's metadata
    let viewModel = ContinuesMagementViewModel(
        driver: mockDriver,
        gameTitle: mockDriver.gameTitle,
        systemTitle: mockDriver.systemTitle,
        numberOfSaves: mockDriver.getAllSaveStates().count,
        gameSize: mockDriver.gameSize,
        gameImage: mockDriver.gameImage
    )

    ContinuesMagementView(viewModel: viewModel)
        .onAppear {
            let theme = CGAThemes.purple
            ThemeManager.shared.setCurrentPalette(theme.palette)

            /// Set the save states from the mock driver
            mockDriver.saveStatesSubject.send(mockDriver.getAllSaveStates())
        }
}

#endif
