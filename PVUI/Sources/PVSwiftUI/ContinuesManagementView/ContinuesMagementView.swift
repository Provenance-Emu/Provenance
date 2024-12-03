//
//  ContinuesMagementView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import AnimatedGradient
import PVThemes
import Combine
import RealmSwift
import OpenDateInterval

extension Publishers {
    struct CombineLatest5Data<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher>: Publisher
    where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)
        typealias Failure = A.Failure

        private let a: A
        private let b: B
        private let c: C
        private let d: D
        private let e: E

        init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }

        func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            Publishers.CombineLatest(
                Publishers.CombineLatest4(a, b, c, d),
                e
            )
            .map { ($0.0, $0.1, $0.2, $0.3, $1) }
            .receive(subscriber: subscriber)
        }
    }
}

extension Publishers {
    static func CombineLatest5<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher>(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E
    ) -> Publishers.CombineLatest5Data<A, B, C, D, E> where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        return Publishers.CombineLatest5Data(a, b, c, d, e)
    }
}

/// View model for the main continues management view
public class ContinuesMagementViewModel: ObservableObject {
    /// Header view model
    @Published var headerViewModel: ContinuesManagementHeaderViewModel
    /// Controls view model
    @Published var controlsViewModel: ContinuesManagementListControlsViewModel
    @Published private(set) var saveStates: [SaveStateRowViewModel] = []

    /// Game image that can be updated
    @Published var gameUIImage: UIImage? {
        didSet {
            headerViewModel.gameUIImage = gameUIImage
        }
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    private let driver: any SaveStateDriver
    private var cancellables = Set<AnyCancellable>()

    /// Search text for filtering saves
    @Published var searchText: String = ""

    /// Computed property for filtered and sorted states
    @Published private(set) var filteredAndSortedSaveStates: [SaveStateRowViewModel] = [] {
        didSet {
            headerViewModel.numberOfSaves = filteredAndSortedSaveStates.count
        }
    }

    private func setupObservers() {
        /// Observe editing state changes
        controlsViewModel.$isEditing
            .sink { [weak self] isEditing in
                self?.saveStates.forEach { $0.isEditing = isEditing }
                if !isEditing {
                    self?.clearAllSelections()
                }
            }
            .store(in: &cancellables)

        // Set up the driver's save states publisher
        driver.saveStatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                guard let self = self else { return }
                // Update each state with the load and delete callbacks before storing
                let updatedStates = states.map { state -> SaveStateRowViewModel in
                    // Set the onLoad callback directly to the parent's onLoadSave
                    state.onLoad = { [weak self] in
                        self?.onLoadSave?(state.id)
                    }
                    // Set the onDelete callback
                    state.onDelete = { [weak self] in
                        self?.deleteSaveState(state)
                    }
                    // Set editing state
                    state.isEditing = self.controlsViewModel.isEditing
                    return state
                }
                self.saveStates = updatedStates
                // Setup observers for each row view model
                updatedStates.forEach { self.observeRowViewModel($0) }
                self.refilterStates()
            }
            .store(in: &cancellables)

        /// Create a publisher that combines all filter criteria
        let filterPublisher = Publishers.CombineLatest5(
            controlsViewModel.$filterFavoritesOnly,
            controlsViewModel.$isAutoSavesEnabled,
            controlsViewModel.$dateRange,
            controlsViewModel.$sortAscending,
            $searchText
        )

        /// Combine save states with filter criteria
        Publishers.CombineLatest(
            $saveStates,
            filterPublisher
        )
        .map { [weak self] states, filterCriteria in
            let (favoritesOnly, autoSavesEnabled, dateRange, sortAscending, searchText) = filterCriteria
            var filtered = states

            // Apply search filter
            if !searchText.isEmpty {
                filtered = filtered.filter {
                    guard let description = $0.description else { return false }
                    return description.localizedCaseInsensitiveContains(searchText)
                }
            }

            // Apply other filters
            return self?.applyFilters(
                to: filtered,
                favoritesOnly: favoritesOnly,
                autoSavesEnabled: autoSavesEnabled,
                dateRange: dateRange,
                sortAscending: sortAscending
            ) ?? []
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$filteredAndSortedSaveStates)

        // Observe save states size
        driver.savesSizePublisher
            .map { Int($0) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.savesTotalSize, on: headerViewModel)
            .store(in: &cancellables)

        // Observe number of saves
        driver.numberOfSavesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.numberOfSaves, on: headerViewModel)
            .store(in: &cancellables)
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

    /// Optional callback when a save state is selected to be loaded
    var onLoadSave: ((String) -> Void)?

    public init(
        driver: any SaveStateDriver,
        gameTitle: String,
        systemTitle: String,
        numberOfSaves: Int,
        gameUIImage: UIImage? = nil,
        onLoadSave: ((String) -> Void)? = nil
    ) {
        self.driver = driver
        self.gameUIImage = gameUIImage
        self.onLoadSave = onLoadSave

        // Initialize header with initial values
        self.headerViewModel = ContinuesManagementHeaderViewModel(
            gameTitle: gameTitle,
            systemTitle: systemTitle,
            numberOfSaves: numberOfSaves,
            savesTotalSize: 0, // Will be updated by publisher
            gameUIImage: gameUIImage
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

    /// Delete a single save state
    private func deleteSaveState(_ saveState: SaveStateRowViewModel) {
        driver.delete(saveStates: [saveState])
    }

    /// Delete selected save states
    private func deleteSelectedSaveStates() {
        let selectedStates = saveStates.filter { $0.isSelected }
        driver.delete(saveStates: selectedStates)
    }

    /// Subscribe to driver's save states publisher
    func subscribeToDriverPublisher() {
        // This method is now deprecated as its functionality has been moved to setupObservers
        // to avoid duplicate subscriptions and potential stack overflow
    }
}

public struct ContinuesMagementView: View {
    /// Main view model
    @StateObject private var viewModel: ContinuesMagementViewModel

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
                        viewModel.currentPalette.settingsCellBackground!.swiftUIColor,
                        viewModel.currentPalette.gameLibraryBackground.swiftUIColor,
                        viewModel.currentPalette.settingsCellBackground!.swiftUIColor])
                    .numberOfSimultaneousColors(2)
                    .setAnimation(.bouncy(duration: 10))
                    .gradientPoints(start: .bottomLeading, end: .topTrailing)
                    .ignoresSafeArea(.all)
//                    .padding(.bottom, 10)
//                    .opacity(0.25)
//                    ProvenanceAnimatedBackgroundView()
//                    .ignoresSafeArea(.all)
//                    .padding(.bottom, 10)
//                    .opacity(0.25)

                    ContinuesManagementHeaderView(viewModel: viewModel.headerViewModel)
                }
                .frame(height: 160)
                .shadow(radius: 5)
            }
            .clipShape(RoundedCorners(radius: 20, corners: [.bottomLeft, .bottomRight]))
            .padding(.bottom, 10)

            /// List view
            ZStack {
                AnimatedLinearGradient(colors: [
                    .Provenance.blue,
                    viewModel.currentPalette.settingsCellBackground!.swiftUIColor,
                    viewModel.currentPalette.gameLibraryBackground.swiftUIColor,
                    viewModel.currentPalette.settingsCellBackground!.swiftUIColor])
                .numberOfSimultaneousColors(2)
                .setAnimation(.bouncy(duration: 10))
                .gradientPoints(start: .topTrailing, end: .bottomLeading)
                .ignoresSafeArea(.all)
                .opacity(0.5)

                if viewModel.saveStates.isEmpty {
                    EmptyStateView()
                } else {
                    ContinuesManagementContentView(viewModel: viewModel)
                }
            }
            .background(viewModel.currentPalette.settingsCellBackground!.swiftUIColor)
            .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
            .ignoresSafeArea(.all)
        }
        .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
//        .background(viewModel.currentPalette.settingsCellBackground!.swiftUIColor)
        .onAppear {
            viewModel.subscribeToDriverPublisher()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Save States")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Save states for this game will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Swift UI Previews

#if DEBUG
@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
#Preview("Continues Management") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    /// Create view model with mock driver
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
        gameUIImage: UIImage(systemName: "gamecontroller"),
        onLoadSave: { id in
            print("load save \(id)")
        }
    )

    ContinuesMagementView(viewModel: viewModel)
        .onAppear {
            let theme = CGAThemes.purple
            ThemeManager.shared.setCurrentPalette(theme.palette)

            /// Load states through the publisher
            driver.loadSaveStates(forGameId: game.id)
        }
}

@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
#Preview("Continues Management with Mock Driver") {
    /// Create mock driver with sample data
    let mockDriver = MockSaveStateDriver(mockData: true)

    /// Create view model using mock driver's metadata
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

    ContinuesMagementView(viewModel: viewModel)
        .onAppear {
            let theme = CGAThemes.purple
            ThemeManager.shared.setCurrentPalette(theme.palette)

            /// Set the save states from the mock driver
            mockDriver.saveStatesSubject.send(mockDriver.getAllSaveStates())
        }
}

#endif
