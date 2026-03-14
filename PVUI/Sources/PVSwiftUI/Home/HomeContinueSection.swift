//
//  HomeContinueSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif
import RealmSwift
import PVLibrary
import PVThemes
import Combine
import Perception
import PVRealm

/// Snapshot used by HomeContinueSection, decoupled from Realm types.
struct ContinueItemModel: Identifiable, Hashable {
    let id: String
    let gameTitle: String?
    let imageURL: URL?
    let date: Date
    let systemIdentifier: String?
    /// Whether this save was created automatically (timed/session autosave).
    let isAutosave: Bool
    /// Other autosaves from the same gaming session collapsed behind this representative.
    /// Sorted newest → oldest. Empty for non-autosaves or when showAllAutosaves is on.
    var stackedSaves: [ContinueItemModel]
    let resolver: () -> PVSaveState?

    /// Total number of saves represented by this card (1 + stacked).
    var stackDepth: Int { 1 + stackedSaves.count }
    /// True when there are hidden autosaves stacked behind this card.
    var isStacked: Bool { !stackedSaves.isEmpty }

    init(id: String,
         gameTitle: String?,
         imageURL: URL?,
         date: Date,
         systemIdentifier: String?,
         isAutosave: Bool = false,
         stackedSaves: [ContinueItemModel] = [],
         resolver: @escaping () -> PVSaveState?) {
        self.id = id
        self.gameTitle = gameTitle
        self.imageURL = imageURL
        self.date = date
        self.systemIdentifier = systemIdentifier
        self.isAutosave = isAutosave
        self.stackedSaves = stackedSaves
        self.resolver = resolver
    }

    init(saveState: PVSaveState, stackedSaves: [ContinueItemModel] = []) {
        // Freeze for thread safety but keep resolver for context actions.
        let snapshot = saveState.isFrozen ? saveState : saveState.freeze()
        self.id = snapshot.id
        self.gameTitle = snapshot.game?.title
        self.imageURL = snapshot.image?.url
        self.date = snapshot.date
        self.systemIdentifier = snapshot.game?.systemIdentifier
        self.isAutosave = snapshot.isAutosave
        self.stackedSaves = stackedSaves
        let primaryKey = snapshot.id
        self.resolver = {
            RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: primaryKey)
        }
    }

    static func == (lhs: ContinueItemModel, rhs: ContinueItemModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Abstraction for driving continues data into the UI without hard-wiring Realm to the view.
protocol ContinuesDataDriver {
    func stream(consoleIdentifier: String?) -> AsyncStream<[ContinueItemModel]>
}

/// Realm-backed implementation.
final class RealmContinuesDataDriver: ContinuesDataDriver {
    private let queue = DispatchQueue(label: "org.provenance.realm.continues.driver", qos: .userInitiated)

    /// Autosaves within this interval of each other (newest → older) belong to the same session.
    /// A gap larger than this creates a new session stack entry for that game.
    static let sessionBoundaryInterval: TimeInterval = 2 * 3600  // 2 hours

    func stream(consoleIdentifier: String?) -> AsyncStream<[ContinueItemModel]> {
        // Capture setting at stream-start time. The view will restart the stream on change.
        let showAllAutosaves = Defaults[.showAutoSavesInRecents]
        return AsyncStream { continuation in
            queue.async { [weak self] in
                guard let self else { return }
                do {
                    let realm = try Realm()
                    var results = realm.objects(PVSaveState.self)
                        .sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
                    if let consoleIdentifier {
                        results = results.filter("game.systemIdentifier == %@", consoleIdentifier)
                    } else {
                        results = results.filter("game != nil")
                    }

                    let token = results.observe(on: queue) { change in
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let models = Self.buildModels(
                                from: collection,
                                showAllAutosaves: showAllAutosaves
                            )
                            continuation.yield(models)
                        case .error(let error):
                            ELOG("RealmContinuesDataDriver observe error: \(error.localizedDescription)")
                        }
                    }

                    continuation.onTermination = { _ in
                        token.invalidate()
                    }
                } catch {
                    ELOG("RealmContinuesDataDriver failed to open Realm: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Converts a Realm collection into display models.
    ///
    /// When `showAllAutosaves` is false (default):
    /// - At most **one** autosave card is shown per game (the most-recent one).
    /// - Older autosaves for that game — whether from the same session or an older one —
    ///   are appended to that representative's `stackedSaves` filmstrip.
    ///   Within a session (gap ≤ `sessionBoundaryInterval`) they go into the normal stack;
    ///   cross-session autosaves are also folded into the same card rather than creating a
    ///   second top-level card, keeping the carousel free of per-game duplicates.
    /// - Manual saves are never grouped.
    ///
    /// When `showAllAutosaves` is true every save is included individually.
    static func buildModels<C: Collection>(
        from collection: C,
        showAllAutosaves: Bool
    ) -> [ContinueItemModel] where C.Element == PVSaveState {
        // (gameID) -> index into resultModels for that game's autosave representative.
        // Only the *first* (newest) autosave per game gets its own card; all subsequent
        // autosaves for that game are appended to the representative's filmstrip stack.
        var gameRepIndex: [String: Int] = [:]
        var resultModels: [ContinueItemModel] = []

        for state in collection.prefix(500) {
            guard !state.isInvalidated else { continue }

            if !showAllAutosaves, state.isAutosave {
                let gameID = state.game?.id ?? ""
                guard !gameID.isEmpty else { continue }

                if let existingIndex = gameRepIndex[gameID] {
                    // A representative already exists for this game — fold this older autosave
                    // into its filmstrip regardless of session boundary. This enforces the
                    // "at most one autosave card per game" policy.
                    resultModels[existingIndex].stackedSaves.append(ContinueItemModel(saveState: state))
                } else {
                    // First autosave for this game: it becomes the representative card.
                    let newIndex = resultModels.count
                    resultModels.append(ContinueItemModel(saveState: state))
                    gameRepIndex[gameID] = newIndex
                }
            } else {
                // Manual save (or showAllAutosaves=true): always include individually.
                resultModels.append(ContinueItemModel(saveState: state))
            }
        }

        // Re-sort by date descending so manual saves and autosave representatives interleave correctly.
        return resultModels.sorted { $0.date > $1.date }
    }
}

/// Optimized view model with reduced @Published properties to minimize re-renders
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

    // Reduce @Published properties to minimize re-renders
    var currentItem: ContinueItemModel?
    var totalSaveStatesCount: Int = 0
    var currentLimit: Int = initialSaveStateLimit
    var hasLoadedAllSaveStates: Bool = false

    /// Filtered save states from parent
    private var items: [ContinueItemModel] = []
    private var isLandscapePhone: Bool = false

    var itemsPerPage: Int {
        isLandscapePhone ? 2 : 1
    }

    /// Calculate the number of pages based on currently loaded save states
    var pageCount: Int {
        max(1, Int(ceil(Double(items.count) / Double(itemsPerPage))))
    }

    /// Check if we should load more save states based on current page
    var shouldLoadMoreSaveStates: Bool {
        guard !hasLoadedAllSaveStates else { return false }

        let pagesRemaining = pageCount - currentPage
        return pagesRemaining <= Self.loadMoreThreshold
    }

    func updateItems(_ models: [ContinueItemModel], isLandscape: Bool, totalCount: Int) {
        items = models
        isLandscapePhone = isLandscape
        totalSaveStatesCount = totalCount

        hasLoadedAllSaveStates = models.count >= totalCount

        updateCurrentSaveState(selectedItemId: selectedItemId, page: currentPage)
    }

    /// Syncs `currentSaveState` to the focused item when possible, otherwise the page-start item.
    func updateCurrentSaveState(selectedItemId: String?, page: Int) {
        // Avoid redundant assignments; even non-@Published mutations can still trigger SwiftUI work
        // when they cause other state writes or feed layout computations.
        func setIfNeeded(_ newItem: ContinueItemModel?) {
            let newId = newItem?.id
            if currentItem?.id == newId { return }
            currentItem = newItem
        }

        if let selectedItemId,
           let focused = items.first(where: { $0.id == selectedItemId }) {
            setIfNeeded(focused)
            return
        }

        let startIndex = page * itemsPerPage
        if startIndex >= 0, startIndex < items.count {
            setIfNeeded(items[startIndex])
        } else {
            setIfNeeded(items.first)
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
        guard startIndex < items.count else { return }
        currentItem = items[startIndex]
    }

    func handleHorizontalNavigation(_ value: Float) -> (nextItemId: String?, nextPage: Int)? {
        guard !items.isEmpty else {
            DLOG("ContinuesSectionViewModel: No items available")
            return nil
        }

        let currentIndex: Int
        if let selectedId = selectedItemId,
           let index = items.firstIndex(where: { $0.id == selectedId }) {
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
        return (items[nextIndex].id, nextPage)
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

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.65))
                            Text(continueState.date, style: .relative)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.65))
                        }
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
                // Theme-aware retrowave-style background with blur and grid
                ZStack {
                    // Blurred background adapts to theme
                    Color(themeManager.currentPalette.dark
                        ? UIColor.black.withAlphaComponent(0.7)
                        : UIColor.white.withAlphaComponent(0.9)
                    )
                    .blur(radius: 3)

                    // Grid overlay for retrowave effect (subtle)
                    RetroTheme.RetroGridView()
                        .opacity(themeManager.currentPalette.dark ? 0.1 : 0.05)
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

    @Default(.showAutoSavesInRecents) private var showAutoSavesInRecents

    /// Filtered save states based on console identifier
    /// Data driver to allow different persistence backends.
    var dataDriver: ContinuesDataDriver = RealmContinuesDataDriver()

    /// Total count of save states (without limit)
    @State private var totalSaveStatesCount: Int = 0

    /// All items provided by the driver, ordered by date desc.
    @State private var allItems: [ContinueItemModel] = []
    /// Currently loaded save states (limited subset)
    @State private var limitedItems: [ContinueItemModel] = []
    /// Pre-chunked pages to avoid recomputing slices during layout
    @State private var pagedItems: [[ContinueItemModel]] = []

    /// Coalesce change storms (e.g. CloudKit metadata updates) to avoid repeated recomputation on main.
    @State private var filteredSaveStatesUpdateTask: Task<Void, Never>? = nil
    @State private var lastAppliedFilteredSignature: Int = 0
    @State private var lastAppliedTotalCount: Int = 0

    /// Flag to track if the view has appeared
    @State private var hasAppeared: Bool = false
    @State private var driverTask: Task<Void, Never>? = nil

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

    init(rootDelegate: PVRootDelegate?, consoleIdentifier: String?, parentFocusedSection: Binding<HomeSectionType?>, parentFocusedItem: Binding<String?>, dataDriver: ContinuesDataDriver = RealmContinuesDataDriver()) {
        self.rootDelegate = rootDelegate
        self.consoleIdentifier = consoleIdentifier
        self._parentFocusedSection = parentFocusedSection
        self._parentFocusedItem = parentFocusedItem
        self.dataDriver = dataDriver

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
        // Data driver handles filtering; keep consoleIdentifier for the stream.

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
        max(1, pagedItems.count)
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

    /// Keeps `viewModel.selectedItemId` and the footer selection in sync with focus and paging.
    private func syncSelectionState() {
        if viewModel.selectedItemId != parentFocusedItem {
            viewModel.selectedItemId = parentFocusedItem
        }
        viewModel.updateCurrentSaveState(selectedItemId: parentFocusedItem, page: viewModel.currentPage)
    }

    var body: some SwiftUI.View {
        // Main container
        ZStack(alignment: .bottom) {
            // Container for all content with border
            ZStack(alignment: .bottom) {
                // Content layer
                VStack(spacing: 0) {
                    // TabView for continues
                    TabView(selection: $viewModel.currentPage) {
                        if !limitedItems.isEmpty {
                            ForEach(Array(pagedItems.enumerated()), id: \.0) { pageIndex, pageStates in
                                SaveStatesGridView(
                                    pageIndex: pageIndex,
                                    pageSaveStates: pageStates,
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
                        saveState: resolveCurrentSaveState(),
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
            // Theme-aware retrowave-style border with gradient and glow
            .background(
                // Theme-aware retrowave-style background
                ZStack {
                    // Background adapts to theme
                    Color(themeManager.currentPalette.dark
                        ? UIColor.black.withAlphaComponent(0.8)
                        : UIColor.white.withAlphaComponent(0.9)
                    )

                    // Grid overlay for retrowave effect
                    RetroTheme.RetroGridView()
                        .opacity(themeManager.currentPalette.dark ? 0.15 : 0.1)
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
            driverTask?.cancel()
            driverTask = Task.detached(priority: .utility) { [consoleIdentifier] in
                for await items in dataDriver.stream(consoleIdentifier: consoleIdentifier) {
                    await MainActor.run {
                        allItems = items
                        totalSaveStatesCount = items.count
                        lastAppliedFilteredSignature = 0
                        updateSaveStateLimit(viewModel.currentLimit)
                        syncSelectionState()
                    }
                }
            }

            // Only update the limit when the view first appears
            if !hasAppeared {
                hasAppeared = true

                // Set the total count from initial driver state (may be empty until stream arrives)
                totalSaveStatesCount = allItems.count
                DLOG("HomeContinueSection: Total save states count: \(totalSaveStatesCount)")

                // Initialize with the initial limit
                updateSaveStateLimit(ContinuesSectionViewModel.initialSaveStateLimit)
                syncSelectionState()
            }
        }
        .onDisappear {
            // Cancel all tasks and subscriptions
            gamepadCancellable?.cancel()
            delayTask?.cancel()
            continuousNavigationTask?.cancel()
            filteredSaveStatesUpdateTask?.cancel()
            driverTask?.cancel()
        }
        .onChange(of: showAutoSavesInRecents) { _ in
            // Restart the driver so it re-queries with the updated autosave display policy.
            driverTask?.cancel()
            driverTask = Task.detached(priority: .utility) { [consoleIdentifier] in
                for await items in dataDriver.stream(consoleIdentifier: consoleIdentifier) {
                    await MainActor.run {
                        allItems = items
                        totalSaveStatesCount = items.count
                        lastAppliedFilteredSignature = 0
                        updateSaveStateLimit(viewModel.currentLimit)
                        syncSelectionState()
                    }
                }
            }
        }
        .onChange(of: parentFocusedItem) { _ in
            syncSelectionState()
        }
        .onChange(of: isLandscapePhone) { _ in
            viewModel.updateItems(limitedItems, isLandscape: isLandscapePhone, totalCount: totalSaveStatesCount)
            rebuildPagedItems()
            syncSelectionState()
        }
        .onChange(of: viewModel.currentPage) { newPage in
            if viewModel.isControllerConnected {
                handlePageChange(newPage)
            }
            syncSelectionState()

            // Check if we need to load more save states
            if viewModel.shouldLoadMoreSaveStates {
                viewModel.loadMoreSaveStates()
                updateSaveStateLimit(viewModel.currentLimit)
                syncSelectionState()
            }

            #if !os(tvOS)
            hapticGenerator.impactOccurred()
            #endif
        }
        // Coalesce Results changes via task to avoid multi-writes per frame
        .task(id: filteredItemsSignature(limit: viewModel.currentLimit)) {
            await applyFilteredItemsIfNeeded()
        }
    }

    /// Updates the limit on the save states by manually filtering the results
    private func updateSaveStateLimit(_ newLimit: Int) {
        // Avoid work if we have no items.
        guard totalSaveStatesCount > 0 else {
            if !limitedItems.isEmpty {
                limitedItems = []
                viewModel.updateItems([], isLandscape: isLandscapePhone, totalCount: 0)
            }
            return
        }

        let limitedCount = min(newLimit, allItems.count)

        // Only materialize a small window from Realm to keep this cheap for large libraries.
        // Add a cushion to keep stable ordering correct when many items share the same date.
        let window = min(allItems.count, limitedCount + 50)
        let candidates = Array(allItems.prefix(window)).sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id > rhs.id
        }

        // Update the limited save states
        let nextLimited = Array(candidates.prefix(limitedCount))

        // If the visible IDs didn't change, don't churn the view model / selection state.
        let currentIDs = limitedItems.map { $0.id }
        let nextIDs = nextLimited.map { $0.id }
        guard currentIDs != nextIDs else { return }

        limitedItems = nextLimited

        // Update the view model with the limited save states
        viewModel.updateItems(limitedItems, isLandscape: isLandscapePhone, totalCount: totalSaveStatesCount)
        rebuildPagedItems()
        syncSelectionState()
    }

    @MainActor
    private func applyFilteredItemsIfNeeded() async {
        filteredSaveStatesUpdateTask?.cancel()
        filteredSaveStatesUpdateTask = Task { @MainActor in
            // Debounce to coalesce CloudKit write storms.
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

            let count = allItems.count
            let signature = filteredItemsSignature(limit: viewModel.currentLimit)

            // Skip if nothing relevant to ordering/display changed.
            if count == lastAppliedTotalCount && signature == lastAppliedFilteredSignature {
                return
            }

            if count != totalSaveStatesCount {
                totalSaveStatesCount = count
            }

            lastAppliedTotalCount = count
            lastAppliedFilteredSignature = signature

            updateSaveStateLimit(viewModel.currentLimit)
            syncSelectionState()
        }
    }

    /// A lightweight signature representing what this view actually cares about:
    /// count + (id, date, stackDepth) for the first N items in the current sort order.
    private func filteredItemsSignature(limit: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(allItems.count)
        let n = min(limit, allItems.count, 50)
        if n > 0 {
            for idx in 0..<n {
                let item = allItems[idx]
                hasher.combine(item.id)
                hasher.combine(item.date.timeIntervalSince1970)
                hasher.combine(item.stackedSaves.count)
            }
        }
        return hasher.finalize()
    }

    private func setupGamepadHandling() {
        // Cancel existing handler if it exists
        gamepadCancellable?.cancel()

        // Use weak self to prevent retain cycles
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                // Only handle events when a controller is actually connected.
                // Handling events while disconnected can create a hot loop of focus/page updates on iOS.
                guard viewModel.isControllerConnected else { return }

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
           let item = limitedItems.first(where: { $0.id == focused }),
           let saveState = item.resolver() {
            Task.detached { @MainActor in
                SceneCoordinator.shared.launchSaveState(saveState.freeze(), core: saveState.core?.freeze())
            }
        }
    }

    private func handleHorizontalNavigation(_ value: Float) {
        guard parentFocusedSection == .recentSaveStates else { return }

        let items = limitedItems.map { $0.id }
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
        let items = limitedItems.map { $0.id }

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

        // Ensure footer metadata stays in sync with the newly visible page.
        viewModel.updateCurrentSaveState(selectedItemId: parentFocusedItem, page: newPage)
    }

    private func resolveCurrentSaveState() -> PVSaveState? {
        currentDisplayItem()?.resolver()
    }

    /// Derive the display item directly from focus/page to avoid stale cached selections.
    private func currentDisplayItem() -> ContinueItemModel? {
        if let focusedId = parentFocusedItem,
           let focused = limitedItems.first(where: { $0.id == focusedId }) {
            return focused
        }

        let page = viewModel.currentPage
        guard page >= 0, page < pagedItems.count else {
            return limitedItems.first
        }
        return pagedItems[page].first ?? limitedItems.first
    }

    private func rebuildPagedItems() {
        let itemsPerPage = max(1, viewModel.itemsPerPage)
        guard !limitedItems.isEmpty else {
            pagedItems = []
            return
        }

        var pages: [[ContinueItemModel]] = []
        pages.reserveCapacity(Int(ceil(Double(limitedItems.count) / Double(itemsPerPage))))

        var index = 0
        while index < limitedItems.count {
            let end = min(index + itemsPerPage, limitedItems.count)
            pages.append(Array(limitedItems[index..<end]))
            index = end
        }
        pagedItems = pages
    }
}

// Optimized grid view with better lazy loading and performance
private struct SaveStatesGridView: View {
    let pageIndex: Int
    let pageSaveStates: [ContinueItemModel]
    let isLandscapePhone: Bool
    let gridColumns: [GridItem]
    let adjustedHeight: CGFloat
    let hideSystemLabel: Bool
    weak var rootDelegate: PVRootDelegate?

    @Binding var parentFocusedSection: HomeSectionType?
    @Binding var parentFocusedItem: String?
    @ObservedObject var viewModel: ContinuesSectionViewModel

    var body: some View {
        WithPerceptionTracking {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(pageSaveStates, id: \.id) { saveState in
                    // Use optimized HomeContinueItemView with extracted data
                    HomeContinueItemView(
                        model: saveState,
                        height: adjustedHeight,
                        hideSystemLabel: hideSystemLabel,
                        action: {
                            if let resolved = saveState.resolver() {
                                Task.detached { @MainActor in
                                    SceneCoordinator.shared.launchSaveState(resolved.freeze(), core: resolved.core?.freeze())
                                }
                            }
                        },
                        isFocused: (parentFocusedSection == .recentSaveStates && parentFocusedItem == saveState.id) && viewModel.isControllerConnected,
                        rootDelegate: rootDelegate
                    )
                    .id(saveState.id) // Stable identity for better performance
                    .focusableIfAvailable()
                    .onChange(of: parentFocusedItem) { newValue in
                        if newValue == saveState.id {
                            // Avoid redundant state writes; they trigger extra graph transactions.
                            if parentFocusedSection != .recentSaveStates {
                                parentFocusedSection = .recentSaveStates
                            }
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
}

private struct EmptyContinuesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Text("No Continues")
            .tag("no continues")
            .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
    }
}

// MARK: - SwiftData Support

/// Maximum number of save-state records fetched by the SwiftData continues driver.
private let maxContinuesFetchCount = 500

/// Extends `ContinueItemModel` to be initialised from a SwiftData `SaveState_Data` record.
///
/// During the Realm → SwiftData migration the `resolver` closure still falls back to Realm
/// so that the game-launch codepath continues to work until the full action layer is migrated.
extension ContinueItemModel {
    init(saveStateData state: SaveState_Data) {
        let saveId = state.id
        let gameTitle = state.game?.title
        let date = state.date
        let systemIdentifier = state.game?.systemIdentifier

        // Resolve the artwork URL from the partial path stored in ImageFile_Data.
        // The full URL is constructed by appending the partial path to the shared save‑states directory.
        let imageURL: URL? = state.image.flatMap { img -> URL? in
            guard !img.partialPath.isEmpty else { return nil }
            let savesDir = Paths.saveSavesPath
            return savesDir.appendingPathComponent(img.partialPath)
        }

        self.init(
            id: saveId,
            gameTitle: gameTitle,
            imageURL: imageURL,
            date: date,
            systemIdentifier: systemIdentifier,
            isAutosave: state.isAutosave,
            resolver: {
                // Hybrid resolver: fetch from Realm during migration so that
                // game-launch actions keep working before the action layer is
                // fully migrated to SwiftData.
                RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: saveId)
            }
        )
    }
}

/// SwiftData-backed implementation of `ContinuesDataDriver`.
///
/// Fetches `SaveState_Data` records from the shared `ModelContainer` and maps
/// them to `ContinueItemModel` values for display in `HomeContinueSection`.
///
/// This is a **one-shot** driver: it yields a single snapshot of the data and
/// finishes.  Live updates are a future enhancement (tracked in #2555) that
/// will use SwiftData's `withChanges(in:)` API (iOS 18+) or periodic polling.
/// In the interim the Realm driver (`RealmContinuesDataDriver`) remains active.
@available(iOS 17, tvOS 17, *)
final class SwiftDataContinuesDataDriver: ContinuesDataDriver, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func stream(consoleIdentifier: String?) -> AsyncStream<[ContinueItemModel]> {
        AsyncStream { continuation in
            let container = modelContainer
            let task = Task.detached {
                let context = ModelContext(container)
                // Build the descriptor with sort, optional system predicate, and a fetch cap.
                // The consoleIdentifier filter is pushed into the store-level predicate so
                // SwiftData can skip irrelevant rows without loading them into memory.
                var descriptor = FetchDescriptor<SaveState_Data>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                if let consoleIdentifier {
                    descriptor.predicate = #Predicate<SaveState_Data> { state in
                        state.game?.systemIdentifier == consoleIdentifier
                    }
                }
                // Cap the fetch at the store level to avoid loading a large result set
                // into memory; game/system presence is validated in the post-fetch filter.
                descriptor.fetchLimit = maxContinuesFetchCount
                do {
                    let results = try context.fetch(descriptor)
                    // Filter: both game and its system must be present.
                    let models = results
                        .filter { $0.game?.system != nil }
                        .map { ContinueItemModel(saveStateData: $0) }
                    continuation.yield(models)
                } catch {
                    ELOG("SwiftDataContinuesDataDriver: fetch failed: \(error)")
                    continuation.yield([])
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}

#endif
