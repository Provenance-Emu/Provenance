//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import SwiftUI
import PVLibrary
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
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starButton(for: index)
            }
        }
        #if os(tvOS)
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
        #endif
#if !os(tvOS)
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

    private func starButton(for index: Int) -> some View {
        Button(action: {
            handleTap(index)
        }) {
            Image(systemName: index <= rating ? "star.fill" : "star")
                .foregroundColor(color)
                .font(.system(size: size))
                #if os(tvOS)
                .scaleEffect(focusedStar == index ? 1.2 : 1.0)
                .shadow(color: focusedStar == index ? color : .clear, radius: focusedStar == index ? 10 : 0)
                .animation(.spring(), value: focusedStar == index)
                #endif
        }
        .buttonStyle(StarButtonStyle())
        .id("star-\(index)-\(rating)") // Force view refresh when rating changes
    }

    private func handleTap(_ index: Int) {
        #if !os(tvOS)
        Haptics.impact(style: .light)
        #endif

        if index == rating {
            onRatingChanged(0) // Toggle off if tapping the same star
        } else {
            onRatingChanged(index)
        }
    }
}

/// Custom button style to prevent unwanted animations and state changes
private struct StarButtonStyle: ButtonStyle {
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
    @Environment(\.dismiss) private var dismiss
    /// Tracks if the rating has been modified but not saved
    @State private var hasUnsavedRating: Bool = false
    /// Stores the original rating before modification
    @State private var originalRating: Int = 0
    @State private var editingField: EditableField?
    @State private var editingValue: String = ""

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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork section with direct binding to published properties
                GameArtworkView(
                    frontArtwork: viewModel.frontArtwork,
                    backArtwork: viewModel.backArtwork
                )

                // Game information section
                VStack(spacing: 8) {
                    LabelRowView(
                        label: "Name",
                        value: viewModel.name
                    ) {
                        editField(.name, initialValue: viewModel.name)
                    }

                    LabelRowView(
                        label: "Filename",
                        value: viewModel.filename,
                        isEditable: false
                    )

                    LabelRowView(
                        label: "System",
                        value: viewModel.system,
                        isEditable: false
                    )

                    LabelRowView(
                        label: "Developer",
                        value: viewModel.developer
                    ) {
                        editField(.developer, initialValue: viewModel.developer)
                    }

                    LabelRowView(
                        label: "Publish Date",
                        value: viewModel.publishDate
                    ) {
                        editField(.publishDate, initialValue: viewModel.publishDate)
                    }

                    LabelRowView(
                        label: "Genres",
                        value: viewModel.genres
                    ) {
                        editField(.genres, initialValue: viewModel.genres)
                    }

                    LabelRowView(
                        label: "Region",
                        value: viewModel.region.map { RegionLabel.format($0) } ?? "",
                        onLongPress: {
                            editField(.region, initialValue: viewModel.region)
                        }
                    )

                    if let timeSpent = viewModel.timeSpent {
                        LabelRowView(
                            label: "Time Spent",
                            value: formatPlayTime(timeSpent),
                            isEditable: false
                        )
                    }

                    // Star rating section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rating")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

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
                                }
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
                                }

                                Spacer()

                                Button(action: {
                                    // Rating is already updated in the viewModel
                                    hasUnsavedRating = false
                                }) {
                                    Text("Save")
                                        .bold()
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)

                    if viewModel.plays != nil || viewModel.timeSpent != nil {
                        Button("Reset Stats") {
                            viewModel.resetStats()
                        }
                        .padding(.top)
                    }
                }
                .padding()

                // Game description section
                if let description = viewModel.gameDescription,
                   !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        ScrollView {
                            Text(description)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                }

                // Debug section
                if let debugInfo = viewModel.debugDescription {
                    #if !os(tvOS)
                    DisclosureGroup(
                        isExpanded: $viewModel.isDebugExpanded,
                        content: {
                            GameDebugInfoView(debugInfo: debugInfo)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical)
                        },
                        label: {
                            Text("Debug Information")
                                .font(.headline)
                        }
                    )
                    .padding()
                    #endif
                }
            }
            .padding(.bottom, 50)
        }
        .alert(editingField?.title ?? "", isPresented: .init(
            get: { editingField != nil },
            set: { if !$0 { editingField = nil } }
        )) {
            TextField("Value", text: $editingValue)
            Button("Cancel", role: .cancel) {
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

    private func formatPlayTime(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "Never" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Paged Game Info View Model
public class PagedGameMoreInfoViewModel: ObservableObject {
    @Published var currentIndex: Int
    private let driver: (any GameLibraryDriver & PagedGameLibraryDataSource)
    let playGameCallback: ((String) async -> Void)?
    @Published var isDebugExpanded = false

    // Navigation bar item states
    @Published var showingWebView = false

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

// MARK: - Paged Game Info View
public struct PagedGameMoreInfoView: View {
    @StateObject var viewModel: PagedGameMoreInfoViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: PagedGameMoreInfoViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(0..<viewModel.gameCount, id: \.self) { index in
                if let gameViewModel = viewModel.makeGameViewModel(for: index) {
                    GameMoreInfoView(viewModel: gameViewModel)
                        .tag(index)
                }
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
#if canImport(SafariServices)
                if let game = viewModel.currentGame,
                   let urlString = game.referenceURL?.absoluteString,
                   let url = URL(string: urlString) {
                    Button {
                        viewModel.openWebView()
                    } label: {
                        Image(systemName: "book")
                    }
                    .sheet(isPresented: $viewModel.showingWebView) {
                        GameReferenceWebView(url: url)
                    }
                }
#endif

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
                    }
                }
            }
        }
    }
}

// MARK: - Web View
#if canImport(SafariServices)
struct GameReferenceWebView: View {
    let url: URL

    var body: some View {
        SafariWebView(url: url)
            .edgesIgnoringSafeArea(.bottom)
    }
}

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif

#if DEBUG
// MARK: - Preview
#Preview("Mock Data") {
    NavigationView {
        GameMoreInfoView(viewModel: .mockViewModel())
    }
}

#Preview("Realm Data") {
    NavigationView {
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
