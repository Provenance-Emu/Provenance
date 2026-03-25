//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import PVCoreBridge
#if canImport(SafariServices)
import SafariServices
#endif
import Combine

/// Protocol for observing artwork changes
protocol ArtworkObservable: AnyObject {
    var frontArtwork: UIImage? { get }
    var backArtwork: UIImage? { get }

    // Specific methods for each artwork publisher
    func frontArtworkPublisher() -> AnyPublisher<UIImage?, Never>
    func backArtworkPublisher() -> AnyPublisher<UIImage?, Never>
}

/// Star rating view component that shows 5 stars and handles user interaction
struct StarRatingView: View {
    let rating: Int
    let maxRating: Int
    let onRatingChanged: (Int) -> Void
    let size: CGFloat
    let spacing: CGFloat
    let color: Color

    @State private var focusedStar: Int?
    @State private var isFocused: Bool = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocusedState: Bool

    init(
        rating: Int,
        maxRating: Int = 5,
        onRatingChanged: @escaping (Int) -> Void,
        size: CGFloat = 30,
        spacing: CGFloat = 8,
        color: Color = .yellow
    ) {
        self.rating = rating
        self.maxRating = maxRating
        self.onRatingChanged = onRatingChanged
        self.size = size
        self.spacing = spacing
        self.color = color
    }

    var body: some View {
        #if os(tvOS)
        // tvOS: Use a focusable container with left/right navigation
        HStack(spacing: spacing * 2) {
            ForEach(1...maxRating, id: \.self) { index in
                starImage(for: index)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(isFocused ? 0.3 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(isFocused ? 0.8 : 0.3), lineWidth: isFocused ? 2 : 1)
                )
        )
        .focusable()
        .focused($isFocusedState)
        .onChange(of: isFocusedState) { focused in
            isFocused = focused
            if focused {
                focusedStar = rating > 0 ? rating : 1
            } else {
                focusedStar = nil
            }
        }
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .left:
                if let current = focusedStar, current > 1 {
                    focusedStar = current - 1
                }
            case .right:
                if let current = focusedStar, current < maxRating {
                    focusedStar = current + 1
                }
            default:
                break
            }
        }
        .onPlayPauseCommand {
            if let star = focusedStar {
                handleTap(star)
            }
        }
        .onExitCommand {
            // Select current star on menu button press if focused
            if let star = focusedStar {
                handleTap(star)
            }
        }
        #else
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starButton(for: index)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    let starWidth = size + spacing
                    let starIndex = min(max(1, Int(round(dragOffset / starWidth)) + (focusedStar ?? 1)), maxRating)
                    focusedStar = starIndex
                }
                .onEnded { _ in
                    if let star = focusedStar {
                        handleTap(star)
                    }
                    dragOffset = 0
                }
        )
        #endif
    }

    #if os(tvOS)
    @ViewBuilder
    private func starImage(for index: Int) -> some View {
        let isSelected = index <= rating
        let isHighlighted = focusedStar == index

        Button(action: {
            handleTap(index)
        }) {
            Image(systemName: isSelected ? "star.fill" : "star")
                .foregroundColor(isSelected ? color : color.opacity(0.4))
                .font(.system(size: size * 1.5))
                .scaleEffect(isHighlighted ? 1.3 : 1.0)
                .shadow(color: isHighlighted ? color : .clear, radius: isHighlighted ? 12 : 0)
                .animation(.spring(response: 0.3), value: isHighlighted)
        }
        .buttonStyle(.plain)
    }
    #endif

    @ViewBuilder
    private func starButton(for index: Int) -> some View {
        Button(action: {
            handleTap(index)
        }) {
            Image(systemName: index <= rating ? "star.fill" : "star")
                .foregroundColor(color)
                .font(.system(size: size))
        }
        .buttonStyle(StarButtonStyle())
        .id("star-\(index)-\(rating)")
    }

    private func handleTap(_ index: Int) {
        #if !os(tvOS)
        Haptics.impact(style: .light)
        #endif

        if index == rating {
            onRatingChanged(0)
        } else {
            onRatingChanged(index)
        }
    }
}

/// Custom button style to prevent unwanted animations and state changes
private struct StarButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .animation(nil, value: configuration.isPressed) // Disable press animation
    }
}

class GameMoreInfoViewModel: ObservableObject {
    @Published private var driver: any GameLibraryDriver
    private let gameId: String
    @Published private(set) var game: (any GameMoreInfoViewModelDataSource)?
    @Published var isDebugExpanded = false

    /// Front Artwork with published wrapper
    @Published private(set) var frontArtwork: UIImage?

    /// Back Artwork with published wrapper
    @Published private(set) var backArtwork: UIImage?

    /// Access to the driver for passing to views
    var rootDelegate: PVRootDelegate? {
        return driver as? PVRootDelegate
    }

    /// Access to the context menu delegate for passing to views
    var contextMenuDelegate: GameContextMenuDelegate? {
        return driver as? GameContextMenuDelegate
    }

    /// Access to the underlying PVGame object if available
    var pvGame: PVGame? {
        return game?.pvGame
    }

    init(driver: any GameLibraryDriver, gameId: String) {
        self.driver = driver
        self.gameId = gameId

        // Initial load
        self.game = driver.game(byId: gameId)

        // Setup artwork observation
        if let game = self.game as? ArtworkObservable {
            observeArtwork(from: game)
        }

        ILOG("Game set: \(self.game.debugDescription)")

        // Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameDidUpdate),
            name: .gameLibraryDidUpdate,
            object: nil
        )
    }

    private func observeArtwork(from game: ArtworkObservable) {
        // Use combine to observe artwork changes
        game.frontArtworkPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: &$frontArtwork)

        game.backArtworkPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: &$backArtwork)
    }

    @objc private func gameDidUpdate() {
        DispatchQueue.main.async {
            self.game = self.driver.game(byId: self.gameId)
            if let game = self.game as? ArtworkObservable {
                self.observeArtwork(from: game)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Box art aspect ratio
    var boxArtAspectRatio: CGFloat {
        game?.boxArtAspectRatio ?? 1.0
    }

    /// Reference URL for game info
    var referenceURL: URL? {
        game?.referenceURL
    }

    /// Debug description if available
    var debugDescription: String? {
        game?.debugDescription
    }

    /// Name (Editable)
    var name: String? {
        get { game?.name }
        set {
            if let newValue = newValue {
                driver.updateGameName(id: gameId, value: newValue)
            }
        }
    }

    /// Filename (Read-only)
    var filename: String? {
        game?.filename
    }

    /// System (Read-only)
    var system: String? {
        game?.system
    }

    /// Developer (Editable)
    var developer: String? {
        get { game?.developer }
        set {
            if let newValue = newValue {
                driver.updateGameDeveloper(id: gameId, value: newValue)
            }
        }
    }

    /// Publish Date (Editable)
    var publishDate: String? {
        get { game?.publishDate }
        set {
            if let newValue = newValue {
                driver.updateGamePublishDate(id: gameId, value: newValue)
            }
        }
    }

    /// Genres (Comma seperated, editable)
    var genres: String? {
        get { game?.genres }
        set {
            if let newValue = newValue {
                driver.updateGameGenres(id: gameId, value: newValue)
            }
        }
    }

    /// Region (Editable)
    var region: String? {
        get { game?.region }
        set {
            if let newValue = newValue {
                driver.updateGameRegion(id: gameId, value: newValue)
            }
        }
    }

    /// Plays (Read-only, Resetable)
    var plays: Int? {
        game?.playCount
    }

    /// Time Spent (Read-only, Resetable)
    var timeSpent: Int? {
        game?.timeSpentInGame
    }

    /// Reset game statistics
    func resetStats() {
        driver.resetGameStats(id: gameId)
    }

    /// Initialize with a mock driver for previews
    static func mockViewModel() -> GameMoreInfoViewModel {
        GameMoreInfoViewModel(
            driver: MockGameLibraryDriver(),
            gameId: "mario" // Using one of our mock game IDs
        )
    }

    /// Game description if available
    var gameDescription: String? {
        game?.gameDescription
    }

    /// Rating (0-5, -1 means unrated)
    var rating: Int {
        get { game?.rating ?? -1 }
        set {
            driver.updateGameRating(id: gameId, value: newValue)
        }
    }

    /// Format rating for display
    var formattedRating: String {
        if rating == -1 {
            return "Not Rated"
        } else {
            return "\(rating) of 5 Stars"
        }
    }
}



// MARK: - Game Info View
struct GameMoreInfoView: View {
    @ObservedObject var viewModel: GameMoreInfoViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    /// Tracks if the rating has been modified but not saved
    @State private var hasUnsavedRating: Bool = false
    /// Stores the original rating before modification
    @State private var originalRating: Int = 0
    @State private var editingField: EditableField?
    @State private var editingValue: String = ""
    @State private var showingResetStatsConfirmation = false
    @State private var showCoreOptionsSheet = false
    @FocusState private var focusedField: EditableField?
    /// Context menu delegate for handling artwork selection
    var contextMenuDelegate: GameContextMenuDelegate?

    private enum EditableField: Identifiable {
        case name
        case developer
        case publishDate
        case genres
        case region

        var id: Self { self }

        var title: String {
            switch self {
            case .name: return "Game Name"
            case .developer: return "Developer"
            case .publishDate: return "Publish Date"
            case .genres: return "Genres"
            case .region: return "Region"
            }
        }
    }

    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0

    /// Theme-aware color helpers
    private var primaryTextColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var cellBackgroundColor: Color {
        if let cellBg = themeManager.currentPalette.settingsCellBackground {
            return cellBg.swiftUIColor.opacity(themeManager.currentPalette.dark ? 0.7 : 0.9)
        }
        return themeManager.currentPalette.dark
            ? Color.black.opacity(0.7)
            : Color.white.opacity(0.9)
    }

    private var sectionBackgroundColor: Color {
        if let cellBg = themeManager.currentPalette.settingsCellBackground {
            return cellBg.swiftUIColor.opacity(themeManager.currentPalette.dark ? 0.6 : 0.8)
        }
        return themeManager.currentPalette.dark
            ? Color.black.opacity(0.6)
            : Color.white.opacity(0.8)
    }

    private func accentGradient(_ colors: [Color]? = nil) -> LinearGradient {
        let gradientColors = colors ?? [
            accentColor,
            accentColor.opacity(0.7),
            accentColor.opacity(0.5)
        ]
        return LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            // Theme-aware background
            RetroTheme.RetroBackgroundView()
                .environmentObject(themeManager)

            // Grid overlay with theme-aware colors
            RetroGrid(
                lineColor: themeManager.currentPalette.dark
                    ? themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.1)
                    : themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.05)
            )
            .opacity(0.3)

            ScrollView {
                #if os(tvOS)
                // Ensure tvOS focus stays within this section
                HStack(alignment: .top, spacing: 40) {
                    // Artwork section
                    GameArtworkView(
                        frontArtwork: viewModel.frontArtwork,
                        backArtwork: viewModel.backArtwork,
                        game: viewModel.pvGame,
                        rootDelegate: viewModel.rootDelegate,
                        contextMenuDelegate: contextMenuDelegate
                    )
                    .frame(width: 400)

                    // Info section
                    VStack(spacing: 24) {
                        gameInfoSection

                        // JIT preference section (only for JIT-capable systems)
                        jitPreferenceSection

                        // Core Options section (always shown; enabled only when the game has a configurable CoreOptional core)
                        coreOptionsSection

                        // Game description section
                        if let description = viewModel.gameDescription,
                           !description.isEmpty {
                            descriptionSection(description: description)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 40)
                .focusSection() // keep focus contained
                #else
                VStack(spacing: 24) {
                    // Artwork section with direct binding to published properties
                    GameArtworkView(
                        frontArtwork: viewModel.frontArtwork,
                        backArtwork: viewModel.backArtwork,
                        game: viewModel.pvGame,
                        rootDelegate: viewModel.rootDelegate,
                        contextMenuDelegate: contextMenuDelegate
                    )

                    // Game information section
                    gameInfoSection

                }
                .padding()
                .padding(.top, 8)

                // JIT preference section (only for JIT-capable systems)
                jitPreferenceSection
                    .padding(.horizontal)

                // Core Options section (always shown; enabled only when the game has a configurable CoreOptional core)
                coreOptionsSection
                    .padding(.horizontal)

                // Game description section
                if let description = viewModel.gameDescription,
                   !description.isEmpty {
                    descriptionSection(description: description)
                }

                // Debug section
                if let debugInfo = viewModel.debugDescription {
                    debugSection(debugInfo: debugInfo)
                }
                #endif
            }
            #if os(tvOS)
            .focusable(true)
            #endif
            .padding(.bottom, 50)
        }
        .onAppear {
            // Start retrowave animations
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                scanlineOffset = 1000
            }

            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
#if os(tvOS)
            // Set initial focus to the first editable field
            focusedField = .name
#endif
        }
        .alert(editingField?.title ?? "", isPresented: .init(
            get: { editingField != nil },
            set: { if !$0 { editingField = nil } }
        )) {
            TextField("Value", text: $editingValue)
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {
                editingField = nil
            }
            Button("Save") {
                if let field = editingField {
                    saveEdit(field)
                }
            }
        } message: {
            Text("Enter a new value")
        }
        .sheet(isPresented: $showCoreOptionsSheet) {
            if let info = coreOptionsInfo,
               let md5 = viewModel.pvGame?.md5Hash, !md5.isEmpty {
                NavigationStack {
                    CoreOptionsDetailView(
                        coreClass: info.coreClass,
                        title: info.name,
                        gameMD5: md5
                    )
                }
            } else {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Unable to load core options.")
                            .multilineTextAlignment(.center)
                        Button(NSLocalizedString("Close", comment: "Close core options sheet")) {
                            showCoreOptionsSheet = false
                        }
                    }
                    .padding()
                }
            }
        }
    }

    /// Returns the preferred CoreOptional class and display name for the current game, or nil if none.
    /// Respects game-level and system-level preferred core ID before falling back to the first available CoreOptional core.
    private var coreOptionsInfo: (coreClass: CoreOptional.Type, name: String)? {
        guard let game = viewModel.pvGame,
              let system = game.system else { return nil }
        let cores = Array(system.cores)
        // Resolve preferred core: game-level preference → system-level preference → first CoreOptional
        let preferredID = game.userPreferredCoreID ?? system.userPreferredCoreID
        if let preferredID = preferredID,
           let preferred = cores.first(where: { $0.identifier == preferredID }),
           let coreClass = NSClassFromString(preferred.principleClass) as? CoreOptional.Type {
            return (coreClass, preferred.projectName)
        }
        for core in cores {
            if let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type {
                return (coreClass, core.projectName)
            }
        }
        return nil
    }

    /// Counts active per-game option overrides for the given core and md5, recursing into option groups.
    private func countPerGameOverrides(in options: [CoreOption], coreClass: CoreOptional.Type, md5: String) -> Int {
        var seen = Set<String>()
        func count(_ opts: [CoreOption]) -> Int {
            var total = 0
            for option in opts {
                switch option {
                case let .group(_, subOptions: subOptions):
                    total += count(subOptions)
                default:
                    guard !seen.contains(option.key) else { continue }
                    seen.insert(option.key)
                    if coreClass.hasPerGameOverride(for: option, md5: md5) { total += 1 }
                }
            }
            return total
        }
        return count(options)
    }

    private func editField(_ field: EditableField, initialValue: String?) {
#if !os(tvOS)
        Haptics.impact(style: .light)
#endif
        editingValue = initialValue ?? ""
        editingField = field
    }

    private func saveEdit(_ field: EditableField) {
        switch field {
        case .name:
            viewModel.name = editingValue
        case .developer:
            viewModel.developer = editingValue
        case .publishDate:
            viewModel.publishDate = editingValue
        case .genres:
            viewModel.genres = editingValue
        case .region:
            viewModel.region = editingValue
        }

        editingField = nil
    }

    // MARK: - Component Views

    /// Game information section component
    private var gameInfoSection: some View {
        VStack(spacing: 16) {
            // Add instruction text at the top with theme-aware styling
            #if os(tvOS)
            Text("SELECT ANY FIELD WITH A PENCIL ICON TO EDIT")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)
                .shadow(color: accentColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            #else
            Text("TAP ANY FIELD WITH A PENCIL ICON TO EDIT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
                .shadow(color: accentColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            #endif

            // Game info rows
            LabelRowView(
                label: "NAME",
                value: viewModel.name,
                onLongPress: { editField(.name, initialValue: viewModel.name) },
                isEditable: true,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
            #if os(tvOS)
            .focused($focusedField, equals: .name)
            #endif
            // Non-editable rows: keep focusable to allow navigation continuity
            LabelRowView(
                label: "FILENAME",
                value: viewModel.filename,
                isEditable: false,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )

            LabelRowView(
                label: "SYSTEM",
                value: viewModel.system,
                isEditable: false,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )

            LabelRowView(
                label: "DEVELOPER",
                value: viewModel.developer,
                onLongPress: { editField(.developer, initialValue: viewModel.developer) },
                isEditable: true,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
            #if os(tvOS)
            .focused($focusedField, equals: .developer)
            #endif

            LabelRowView(
                label: "PUBLISH DATE",
                value: viewModel.publishDate,
                onLongPress: { editField(.publishDate, initialValue: viewModel.publishDate) },
                isEditable: true,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
            #if os(tvOS)
            .focused($focusedField, equals: .publishDate)
            #endif

            LabelRowView(
                label: "GENRES",
                value: viewModel.genres,
                onLongPress: { editField(.genres, initialValue: viewModel.genres) },
                isEditable: true,
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
            #if os(tvOS)
            .focused($focusedField, equals: .genres)
            #endif

            LabelRowView(
                label: "REGION",
                value: viewModel.region.map { RegionLabelSwiftUI.format($0) } ?? "",
                onLongPress: {
                    editField(.region, initialValue: viewModel.region)
                },
                labelColor: accentColor,
                valueColor: primaryTextColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
            #if os(tvOS)
            .focused($focusedField, equals: .region)
            #endif

            if let timeSpent = viewModel.timeSpent {
                LabelRowView(
                    label: "TIME SPENT",
                    value: formatPlayTime(timeSpent),
                    isEditable: false,
                    labelColor: accentColor,
                    valueColor: primaryTextColor,
                    backgroundColor: cellBackgroundColor,
                    borderGradient: accentGradient()
                )
            }

            // Star rating section with retrowave styling
            ratingSection

            if viewModel.plays != nil || viewModel.timeSpent != nil {
                resetStatsButton
            }
        }
#if os(tvOS)
        .focusSection() // Contain focus within the metadata block
#endif
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            accentGradient([
                                accentColor,
                                accentColor.opacity(0.7),
                                accentColor.opacity(0.5)
                            ]),
                            lineWidth: 1.5
                        )
                        .blur(radius: 1)
                )
        )
        .padding(.horizontal)
    }

    /// Core Options section — always shown; the button is enabled only when the game's system has a configurable CoreOptional core.
    @ViewBuilder
    private var coreOptionsSection: some View {
        let info = coreOptionsInfo
        let md5 = viewModel.pvGame?.md5Hash ?? ""
        let hasMD5 = !md5.isEmpty
        let isEnabled = info != nil && hasMD5
        let overrideCount: Int = {
            guard let info = info, hasMD5 else { return 0 }
            return countPerGameOverrides(in: info.coreClass.options, coreClass: info.coreClass, md5: md5)
        }()
        let isMatched = viewModel.pvGame?.system != nil

        VStack(alignment: .leading, spacing: 8) {
            Text("CORE OPTIONS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isEnabled ? accentColor : accentColor.opacity(0.4))
                .shadow(color: accentColor.opacity(isEnabled ? glowOpacity : 0.2), radius: 3, x: 0, y: 0)

            Button(action: {
                showCoreOptionsSheet = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(isEnabled ? accentColor : .secondary)
                    Text({
                        if info == nil {
                            return isMatched ? "No configurable core" : "ROM not matched"
                        } else if !hasMD5 {
                            return "No ROM hash"
                        } else {
                            return "Per-Game Settings"
                        }
                    }())
                        .font(.system(size: 14))
                        .foregroundColor(isEnabled ? primaryTextColor : .secondary)
                    Spacer()
                    if overrideCount > 0 {
                        Text("\(overrideCount) override\(overrideCount == 1 ? "" : "s")")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.2))
                            .foregroundColor(accentColor)
                            .clipShape(Capsule())
                    }
                    if isEnabled {
                        Image(systemName: "chevron.right")
                            .foregroundColor(accentColor.opacity(0.6))
                            .font(.caption)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cellBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isEnabled ? accentGradient() : LinearGradient(colors: [.secondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .disabled(!isEnabled)
            #if os(tvOS)
            .buttonStyle(.plain)
            #endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isEnabled ? accentGradient([accentColor, accentColor.opacity(0.7), accentColor.opacity(0.5)]) :
                                LinearGradient(colors: [.secondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1.5
                        )
                        .blur(radius: 1)
                )
        )
    }

    /// JIT preference section — only shown for JIT-capable systems.
    @ViewBuilder
    private var jitPreferenceSection: some View {
        if let md5 = viewModel.pvGame?.md5Hash,
           let sysID = viewModel.pvGame?.systemIdentifier,
           JITCoreCapability.systemHasJITCapability(sysID) {
            JITGameSettingsView(
                gameMD5: md5,
                accentColor: accentColor,
                backgroundColor: cellBackgroundColor,
                borderGradient: accentGradient()
            )
        }
    }

    /// Rating section component
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RATING")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(accentColor)
                .shadow(color: accentColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)

            HStack {
                StarRatingView(
                    rating: max(0, viewModel.rating),
                    onRatingChanged: { newRating in
                        if !hasUnsavedRating {
                            originalRating = viewModel.rating
                        }
                        hasUnsavedRating = true
#if !os(tvOS)
                        Haptics.impact(style: .light)
#endif
                        viewModel.rating = newRating
                    },
                    color: accentColor
                )

                Spacer()

                Text(viewModel.formattedRating)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if hasUnsavedRating {
                HStack {
                    Button(action: {
                        viewModel.rating = originalRating
                        hasUnsavedRating = false
                    }) {
                        Text("Reset")
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
                            )
                    }

                    Spacer()

                    Button(action: {
                        // Rating is already updated in the viewModel
                        hasUnsavedRating = false
                    }) {
                        Text("Save")
                            .bold()
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accentColor.opacity(0.7), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }

    /// Reset stats button with theme-aware styling
    private var resetStatsButton: some View {
        Button(action: {
            showingResetStatsConfirmation = true
        }) {
            Text("RESET STATS")
                #if os(tvOS)
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                #else
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                #endif
                .foregroundColor(accentColor)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentGradient(), lineWidth: 1.5)
                )
                .shadow(color: accentColor.opacity(glowOpacity), radius: 5, x: 0, y: 0)
        }
        #if os(tvOS)
        .buttonStyle(.plain)
        #endif
        .padding(.top)
        .alert("Reset Statistics", isPresented: $showingResetStatsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetStats()
            }
        } message: {
            Text("Are you sure you want to reset play count and time spent for this game? This action cannot be undone.")
        }
    }

    /// Game description section component
    private func descriptionSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(accentColor)
                .shadow(color: accentColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)

            ScrollView {
                Text(description)
                    .font(.body)
                    .foregroundColor(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            accentGradient([
                                accentColor,
                                accentColor.opacity(0.7)
                            ]),
                            lineWidth: 1.5
                        )
                        .blur(radius: 1)
                )
        )
        .padding(.horizontal)
    }

    /// Debug section component
    private func debugSection(debugInfo: String) -> some View {
        Group {
#if !os(tvOS)
            DisclosureGroup(
                isExpanded: $viewModel.isDebugExpanded,
                content: {
                    GameDebugInfoView(debugInfo: debugInfo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                },
                label: {
                    Text("DEBUG INFORMATION")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(accentColor)
                        .shadow(color: accentColor.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(sectionBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                accentGradient([
                                    accentColor,
                                    accentColor.opacity(0.6)
                                ]),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal)
#endif
        }
    }

    private func formatPlayTime(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "Never" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Paged Game Info View Model
public class PagedGameMoreInfoViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var showingWebView: Bool = false
    let driver: any (GameLibraryDriver & PagedGameLibraryDataSource)
    let playGameCallback: ((String) async -> Void)?
    @Published var isDebugExpanded = false

    /// Access to the root delegate for passing to views
    var rootDelegate: PVRootDelegate? {
        return driver as? PVRootDelegate
    }

    public init(driver: any GameLibraryDriver & PagedGameLibraryDataSource,
                initialGameId: String? = nil,
                playGameCallback: ((String) async -> Void)? = nil) {
        self.driver = driver
        self.playGameCallback = playGameCallback
        if let gameId = initialGameId, let index = driver.index(for: gameId) {
            self.currentIndex = index
        } else {
            self.currentIndex = 0
        }
    }

    var currentGameId: String? {
        driver.gameId(at: currentIndex)
    }

    var currentGame: (any GameMoreInfoViewModelDataSource)? {
        guard let gameId = currentGameId else { return nil }
        return driver.game(byId: gameId)
    }

    var currentGameName: String {
        if let gameId = currentGameId,
           let game = driver.game(byId: gameId) {
            return game.name ?? "Unknown Game"
        }
        return "Unknown Game"
    }

    var gameCount: Int {
        driver.gameCount
    }

    func makeGameViewModel(for index: Int) -> GameMoreInfoViewModel? {
        guard let gameId = driver.gameId(at: index) else { return nil }
        return GameMoreInfoViewModel(driver: driver, gameId: gameId)
    }

    // Navigation bar actions
    func openWebView() {
        if let game = currentGame,
           let urlString = game.referenceURL?.absoluteString,
           let _ = URL(string: urlString) {
            showingWebView = true
        }
    }

    func playGame() async {
        if let gameId = currentGameId,
           let callback = playGameCallback {
            await callback(gameId)
        }
    }

    var debugDescription: String? {
        currentGame?.debugDescription
    }
}

// MARK: - Lazy View Wrapper
/// A wrapper view that defers the creation of its content until it's needed
private struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

// MARK: - Paged Game Info View
public struct PagedGameMoreInfoView: View {
    @StateObject var viewModel: PagedGameMoreInfoViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    /// State for handling image picker and artwork search
    @State private var showImagePicker = false
    @State private var showArtworkSearch = false
    @State private var gameToUpdateCover: PVGame?
    @State private var selectedImage: UIImage?

    /// Cache for created view models to avoid recreating them
    @State private var viewModelCache: [Int: GameMoreInfoViewModel] = [:]

    /// Reference to the coordinator
    @State private var coordinatorRef: Coordinator?

    /// Theme-aware accent color
    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    /// Theme-aware accent gradient
    private func accentGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                accentColor,
                accentColor.opacity(0.7)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public init(viewModel: PagedGameMoreInfoViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Coordinator to handle context menu actions
    class Coordinator: GameContextMenuDelegate {
        weak var viewModel: PagedGameMoreInfoViewModel?
        var parent: PagedGameMoreInfoView?

        init(parent: PagedGameMoreInfoView, viewModel: PagedGameMoreInfoViewModel) {
            self.parent = parent
            self.viewModel = viewModel
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestRenameFor: game)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestChooseCoverFor: game)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestMoveToSystemFor: game)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestShowSaveStatesFor: game)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestShowGameInfoFor: gameId)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
            /// Handle locally
            parent?.gameToUpdateCover = game
            parent?.showImagePicker = true
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
            /// Handle locally
            parent?.gameToUpdateCover = game
            parent?.showArtworkSearch = true
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestChooseArtworkSourceFor: game)
        }

        func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
            /// Delegate to driver if available
            viewModel?.driver.gameContextMenu(menu, didRequestDiscSelectionFor: game)
        }
    }

    /// Create a new coordinator if needed
    private func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(parent: self, viewModel: viewModel)
        DispatchQueue.main.async {
            self.coordinatorRef = coordinator
        }
        return coordinator
    }

    /// Get or create the coordinator
    private func getCoordinator() -> Coordinator {
        return coordinatorRef ?? makeCoordinator()
    }

    /// Get or create a view model for the given index
    private func getViewModel(for index: Int) -> GameMoreInfoViewModel? {
        // Check if we already have a cached view model
        if let cachedViewModel = viewModelCache[index] {
            return cachedViewModel
        }

        // Create a new view model if needed
        if let newViewModel = viewModel.makeGameViewModel(for: index) {
            // Cache the new view model
            Task { @MainActor in
                self.viewModelCache[index] = newViewModel
            }
            return newViewModel
        }

        return nil
    }

    /// Save artwork for a game
    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        Task {
            do {
                let uniqueID = UUID().uuidString
                let md5: String = game.md5Hash ?? ""
                let key = "artwork_\(md5)_\(uniqueID)"

                // Write image to disk asynchronously
                try await Task.detached(priority: .background) {
                    try PVMediaCache.writeImage(toDisk: image, withKey: key)
                }.value

                // Update Realm on main thread
                try await RomDatabase.sharedInstance.asyncWriteTransaction {
                    if let thawedGame = game.thaw() {
                        thawedGame.customArtworkURL = key
                    }
                }

                await MainActor.run {
                    // Post notification to trigger UI updates
                    NotificationCenter.default.post(name: .gameLibraryDidUpdate, object: nil)

                    // Clear the ArtworkLoader cache for this game to force reload
                    ArtworkLoader.shared.cancelLoading(for: game.id)

                    // Update the cache with the new image
                    //                    PVMediaCache.shareInstance().setImage(image, forKey: key)

                    // Show success message
                    viewModel.rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

                    // Reset state variables
                    gameToUpdateCover = nil
                    showImagePicker = false
                    showArtworkSearch = false
                }
            } catch {
                await MainActor.run {
                    DLOG("Failed to set custom artwork: \(error.localizedDescription)")
                    viewModel.rootDelegate?.showMessage("Failed to set custom artwork: \(error.localizedDescription)", title: "Error")

                    // Reset state variables even on error
                    gameToUpdateCover = nil
                    showImagePicker = false
                    showArtworkSearch = false
                }
            }
        }
    }

    // MARK: - View Builders

    /// Build the content for a specific tab index
    @ViewBuilder
    private func tabContent(for index: Int) -> some View {
        if let gameViewModel = getViewModel(for: index) {
            GameMoreInfoView(
                viewModel: gameViewModel,
                contextMenuDelegate: getCoordinator()
            )
        } else {
            // Placeholder view if view model creation fails
            placeholderView()
        }
    }

    /// Build a placeholder view for when a game can't be loaded
    @ViewBuilder
    private func placeholderView() -> some View {
        VStack {
            Text("Unable to load game information")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()

            ProgressView()
                .padding()
        }
    }

    /// Build the web view button if a reference URL is available
    @ViewBuilder
    private func webViewButton() -> some View {
#if canImport(SafariServices)
        if let game = viewModel.currentGame,
           let urlString = game.referenceURL?.absoluteString,
           let url = URL(string: urlString) {
            Button {
                viewModel.openWebView()
            } label: {
                Image(systemName: "book")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(8)
                    .legacyStrokeBorder(Circle(), gradient: accentGradient())
                    .legacyGlowShadow(accentColor.opacity(0.7))
            }
            .sheet(isPresented: $viewModel.showingWebView) {
                GameReferenceWebView(url: url)
            }
        } else {
            EmptyView()
        }
#else
        EmptyView()
#endif
    }

    /// Build the play button if a callback is available
    @ViewBuilder
    private func playButton() -> some View {
        if viewModel.playGameCallback != nil {
            Button {
                dismiss()  // Dismiss first
                Task {
                    if let gameId = viewModel.currentGameId {
                        await viewModel.playGameCallback?(gameId)
                    }
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(8)
                    .legacyStrokeBorder(Circle(), gradient: accentGradient())
                    .legacyGlowShadow(accentColor.opacity(0.7))
            }
        } else {
            EmptyView()
        }
    }

    /// Build the image picker sheet
    @ViewBuilder
    private func imagePickerSheet() -> some View {
#if !os(tvOS)
        if showImagePicker {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let game = gameToUpdateCover {
                    saveArtwork(image: image, forGame: game)
                }
                showImagePicker = false
                gameToUpdateCover = nil
            }
        } else {
            EmptyView()
        }
#else
        EmptyView()
#endif
    }

    /// Build the artwork search sheet
    @ViewBuilder
    private func artworkSearchSheet() -> some View {
        if showArtworkSearch, let game = gameToUpdateCover {
            ArtworkSearchView(
                initialSearch: game.title,
                initialSystem: game.system?.enumValue ?? .Unknown
            ) { selection in
                Task {
                    do {
                        // Load image data from URL
                        let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                saveArtwork(image: uiImage, forGame: game)
                                showArtworkSearch = false
                                gameToUpdateCover = nil
                            }
                        }
                    } catch {
                        DLOG("Failed to load artwork image: \(error)")
                        // Make sure to reset state even on error
                        await MainActor.run {
                            showArtworkSearch = false
                            gameToUpdateCover = nil
                        }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    public var body: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(0..<viewModel.gameCount, id: \.self) { index in
                // Use LazyView to defer creation of content until needed
                LazyView {
                    tabContent(for: index)
                }
                .tag(index)
            }
        }
        .onChange(of: viewModel.currentIndex) { _ in
#if !os(tvOS)
            Haptics.impact(style: .soft)
#endif
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .navigationTitle(viewModel.currentGameName)
        .toolbar {
            SwiftUI.ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Text("DONE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .legacyStrokeBorder(RoundedRectangle(cornerRadius: 8), gradient: accentGradient())
                        .legacyGlowShadow(accentColor.opacity(0.7))
                }
            }

            SwiftUI.ToolbarItemGroup(placement: .topBarTrailing) {
                webViewButton()

                playButton()
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            // Reset state when sheet is dismissed
            gameToUpdateCover = nil
        }) {
            imagePickerSheet()
        }
        .sheet(isPresented: $showArtworkSearch, onDismiss: {
            // Reset state when sheet is dismissed
            gameToUpdateCover = nil
        }) {
            artworkSearchSheet()
        }
    }
}

// MARK: - Liquid-Glass-Aware Button Styling Helpers
/// On iOS/tvOS 26+, the system provides liquid glass styling for toolbar buttons.
/// These helpers conditionally suppress legacy custom borders and glow shadows
/// to avoid doubled/conflicting visual treatments on those OS versions.
private extension View {
    /// Applies a stroke border background only on OS versions prior to iOS/tvOS 26.
    /// On iOS/tvOS 26+ the system provides liquid glass styling, so the border is suppressed.
    /// On non-iOS/tvOS platforms the legacy border is always applied.
    @ViewBuilder
    func legacyStrokeBorder<S: Shape>(_ shape: S, gradient: LinearGradient, lineWidth: CGFloat = 1.5) -> some View {
        #if os(iOS) || os(tvOS)
        if #available(iOS 26, tvOS 26, *) {
            self
        } else {
            self.background(shape.stroke(gradient, lineWidth: lineWidth))
        }
        #else
        self.background(shape.stroke(gradient, lineWidth: lineWidth))
        #endif
    }

    /// Applies a glow shadow only on OS versions prior to iOS/tvOS 26.
    /// On iOS/tvOS 26+ the system provides liquid glass depth, so the shadow is suppressed.
    /// On non-iOS/tvOS platforms the legacy shadow is always applied.
    @ViewBuilder
    func legacyGlowShadow(_ color: Color, radius: CGFloat = 3) -> some View {
        #if os(iOS) || os(tvOS)
        if #available(iOS 26, tvOS 26, *) {
            self
        } else {
            self.shadow(color: color, radius: radius, x: 0, y: 0)
        }
        #else
        self.shadow(color: color, radius: radius, x: 0, y: 0)
        #endif
    }
}

// MARK: - Web View
#if canImport(SafariServices)
struct GameReferenceWebView: View {
    let url: URL

    var body: some View {
        SafariWebView(url: url, entersReaderIfAvailable: true)
            .edgesIgnoringSafeArea(.bottom)
    }
}
#endif

#if DEBUG
// MARK: - Preview
#Preview("Mock Data") {
    NavigationStack {
        GameMoreInfoView(viewModel: .mockViewModel())
    }
}

#Preview("Realm Data") {
    NavigationStack {
        // Realm driver preview
        if let driver = try? RealmGameLibraryDriver.previewDriver(),
           let firstGameId = driver.firstGameId() {
            GameMoreInfoView(
                viewModel: GameMoreInfoViewModel(
                    driver: driver,
                    gameId: firstGameId
                )
            )
        }
    }
}

#endif

// MARK: - GameLibraryDriver Extension
extension GameLibraryDriver {
    /// Helper method to forward context menu actions to the driver if it implements GameContextMenuDelegate
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestRenameFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestChooseCoverFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestMoveToSystemFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestShowSaveStatesFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestShowGameInfoFor: gameId)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestShowImagePickerFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestShowArtworkSearchFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestChooseArtworkSourceFor: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        (self as? GameContextMenuDelegate)?.gameContextMenu(menu, didRequestDiscSelectionFor: game)
    }
}
