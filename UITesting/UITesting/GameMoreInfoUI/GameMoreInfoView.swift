//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import SwiftUI
import PVLibrary

/// A reusable view for displaying a label and value pair with optional editing
struct LabelRowView: View {
    let label: String
    let value: String?
    var onLongPress: (() -> Void)?
    var isEditable: Bool = true

    var body: some View {
        HStack {
            // Label side - right aligned
            Text(label + ":")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(.secondary)

            // Value side - left aligned
            Text(value ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle()) // Make entire area tappable
                .onLongPressGesture {
                    if isEditable {
                        onLongPress?()
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

class GameMoreInfoViewModel: ObservableObject {
    @Published private var driver: any GameLibraryDriver
    private let gameId: String

    init(driver: any GameLibraryDriver, gameId: String) {
        self.driver = driver
        self.gameId = gameId
    }

    private var game: GameMoreInfoViewModelDataSource? {
        driver.game(byId: gameId)
    }

    /// Front Artwork
    var frontArtwork: URL? {
        game?.boxFrontArtwork
    }

    /// Back Artwork
    var backArtwork: URL? {
        game?.boxBackArtwork
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

/// View for displaying and interacting with game artwork
struct GameArtworkView: View {
    let frontArtwork: URL?
    let backArtwork: URL?
    @State private var isShowingBack = false
    @State private var isShowingFullscreen = false

    var body: some View {
        ZStack {
            // Main artwork view
            artworkImage
                .rotation3DEffect(
                    .degrees(isShowingBack ? 180 : 0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isShowingBack.toggle()
                    }
                }
                .onTapGesture(count: 2) {
                    isShowingFullscreen = true
                }
        }
        .frame(width: 200, height: 200)
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            FullscreenArtworkView(
                url: isShowingBack ? backArtwork : frontArtwork,
                isShowingBack: $isShowingBack
            )
        }
    }

    private var artworkImage: some View {
        Group {
            if let url = isShowingBack ? backArtwork : frontArtwork {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 3)
    }
}

/// Fullscreen view for artwork with zoom and pan
struct FullscreenArtworkView: View {
    let url: URL?
    @Binding var isShowingBack: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)

                    if let url = url {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value.magnitude
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                        }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Flip") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isShowingBack.toggle()
                        }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        }
                    }
            )
        }
    }
}

/// Main view for displaying game information
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
                // Artwork section
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
            .previewDisplayName("Realm Driver")
        }
    }
}

#endif
