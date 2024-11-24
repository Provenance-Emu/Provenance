//
//  ContentView.swift
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


/// View model for the main continues management view
public class ContinuesMagementViewModel: ObservableObject {
    /// Header view model
    @Published var headerViewModel: ContinuesManagementHeaderViewModel
    /// Controls view model
    @Published var controlsViewModel: ContinuesManagementListControlsViewModel
    @Published var saveStates: [SaveStateRowViewModel] {
        didSet {
            // Remove old observers
            cancellables.removeAll()
            // Setup new observers
            observeSaveStates()
        }
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    /// Setup publishers to trigger updates when filters change
    private var cancellables = Set<AnyCancellable>()

    /// Add driver
    private let driver: SaveStateDriver

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
        self.saveStates = []

        /// Observe changes to control settings
        Publishers.CombineLatest4(
            controlsViewModel.$filterFavoritesOnly,
            controlsViewModel.$sortAscending,
            controlsViewModel.$dateRange,
            controlsViewModel.$isAutoSavesEnabled
        )
        .sink { [weak self] _, _, _, _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }

    /// Computed property that returns filtered and sorted save states
    var filteredAndSortedSaveStates: [SaveStateRowViewModel] {
        var result = saveStates

        /// Apply date range filter if set
        if let dateRange = controlsViewModel.dateRange {
            result = result.filter { saveState in
                let date = saveState.saveDate
                let isAfterStart = date >= dateRange.start
                let isBeforeEnd = dateRange.end.map { date <= $0 } ?? true
                return isAfterStart && isBeforeEnd
            }
        }

        /// Apply favorites filter if enabled
        if controlsViewModel.filterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        /// Apply auto-save filter if enabled
        if !controlsViewModel.isAutoSavesEnabled {
            result = result.filter { !$0.isAutoSave }
        }

        /// Sort the results
        result.sort { first, second in
            /// If both items are pinned or unpinned, sort by date
            if first.isPinned == second.isPinned {
                return controlsViewModel.sortAscending ?
                    first.saveDate < second.saveDate :
                    first.saveDate > second.saveDate
            }
            /// Otherwise, pinned items always come first
            return first.isPinned
        }

        return result
    }

    /// Add new observation method
    private func observeSaveStates() {
        for saveState in saveStates {
            // Observe description changes
            saveState.$description
                .dropFirst()
                .sink { [weak self] newDescription in
                    self?.driver.updateDescription(saveStateId: saveState.id, description: newDescription)
                }
                .store(in: &cancellables)

            // Observe pin state changes
            saveState.$isPinned
                .dropFirst()
                .sink { [weak self] isPinned in
                    self?.driver.setPin(saveStateId: saveState.id, isPinned: isPinned)
                }
                .store(in: &cancellables)

            // Observe favorite state changes
            saveState.$isFavorite
                .dropFirst()
                .sink { [weak self] isFavorite in
                    self?.driver.setFavorite(saveStateId: saveState.id, isFavorite: isFavorite)
                }
                .store(in: &cancellables)
        }
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

            /// Set the save states from the mock driver
            viewModel.saveStates = mockDriver.getAllSaveStates()
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

            /// Set the save states from the driver
            viewModel.saveStates = driver.getSaveStates(forGameId: game.id)
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
            viewModel.saveStates = mockDriver.getAllSaveStates()
        }
}

#endif
