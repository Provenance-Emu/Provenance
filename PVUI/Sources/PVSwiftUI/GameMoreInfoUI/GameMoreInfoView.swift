//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import SwiftUI
import PVLibrary
import SafariServices


class GameMoreInfoViewModel: ObservableObject {
    @Published private var driver: any GameLibraryDriver
    private let gameId: String
    @Published private(set) var game: (any GameMoreInfoViewModelDataSource)?

    init(driver: any GameLibraryDriver, gameId: String) {
        self.driver = driver
        self.gameId = gameId

        // Initial load
        self.game = driver.game(byId: gameId)
        
        ILOG("Game set: \(self.game.debugDescription)")

        // Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameDidUpdate),
            name: .gameLibraryDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func gameDidUpdate() {
        DispatchQueue.main.async {
            self.game = self.driver.game(byId: self.gameId)
        }
    }

    /// Front Artwork
    var frontArtwork: UIImage? {
        game?.boxFrontArtwork
    }

    /// Back Artwork
    var backArtwork: UIImage? {
        game?.boxBackArtwork
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
}


// MARK: - Game Info View
struct GameMoreInfoView: View {
    @StateObject var viewModel: GameMoreInfoViewModel
    @State private var editingField: EditableField?
    @State private var editingValue: String = ""
    @State private var showingWebView = false
    @State private var showingDebugInfo = false

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
                // Artwork section
                GameArtworkView(
                    frontArtwork: viewModel.frontArtwork,
                    backArtwork: viewModel.backArtwork,
                    aspectRatio: viewModel.boxArtAspectRatio
                )
                .padding(.vertical)

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
                        value: viewModel.region
                    ) {
                        editField(.region, initialValue: viewModel.region)
                    }

                    // Stats section
                    VStack(spacing: 8) {
                        LabelRowView(
                            label: "Play Count",
                            value: viewModel.plays.map(String.init) ?? "Never",
                            isEditable: false
                        )

                        LabelRowView(
                            label: "Time Played",
                            value: formatPlayTime(viewModel.timeSpent),
                            isEditable: false
                        )

                        Button("Reset Stats") {
                            viewModel.resetStats()
                        }
                        .padding(.top)
                    }
                }
                .padding()
            }
            .padding(.bottom, 50)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if viewModel.debugDescription != nil {
                        NavigationLink(destination: GameDebugInfoView(debugInfo: viewModel.debugDescription!)) {
                            Image(systemName: "info.circle")
                        }
                    }

                    Button {
                        showingWebView = true
                    } label: {
                        Image(systemName: "safari")
                    }
                    .disabled(viewModel.referenceURL == nil)
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = viewModel.referenceURL {
                GameReferenceWebView(url: url)
            }
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
                saveEdit()
            }
        } message: {
            Text("Enter a new value")
        }
    }

    private func editField(_ field: EditableField, initialValue: String?) {
        editingField = field
        editingValue = initialValue ?? ""
    }

    private func saveEdit() {
        guard let field = editingField else { return }

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

    public init(driver: any GameLibraryDriver & PagedGameLibraryDataSource, initialGameId: String? = nil) {
        self.driver = driver
        if let gameId = initialGameId, let index = driver.index(for: gameId) {
            self.currentIndex = index
        } else {
            self.currentIndex = 0
        }
    }

    var currentGameId: String? {
        driver.gameId(at: currentIndex)
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
}

// MARK: - Paged Game Info View
public struct PagedGameMoreInfoView: View {
    @StateObject var viewModel: PagedGameMoreInfoViewModel

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
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .navigationTitle(viewModel.currentGameName)
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
