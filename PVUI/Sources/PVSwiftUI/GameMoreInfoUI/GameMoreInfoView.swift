//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import SwiftUI
import PVLibrary
import SafariServices
import Combine

/// Protocol for observing artwork changes
protocol ArtworkObservable: AnyObject {
    var frontArtwork: UIImage? { get }
    var backArtwork: UIImage? { get }

    // Specific methods for each artwork publisher
    func frontArtworkPublisher() -> AnyPublisher<UIImage?, Never>
    func backArtworkPublisher() -> AnyPublisher<UIImage?, Never>
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
}


// MARK: - Game Info View
struct GameMoreInfoView: View {
    @StateObject var viewModel: GameMoreInfoViewModel
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

                    if let playCount = viewModel.plays {
                        LabelRowView(
                            label: "Play Count",
                            value: "\(playCount)",
                            isEditable: false
                        )
                    }

                    if let timeSpent = viewModel.timeSpent {
                        LabelRowView(
                            label: "Time Spent",
                            value: formatPlayTime(timeSpent),
                            isEditable: false
                        )
                    }

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
        Haptics.impact(style: .light)
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
            Haptics.impact(style: .soft)
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
