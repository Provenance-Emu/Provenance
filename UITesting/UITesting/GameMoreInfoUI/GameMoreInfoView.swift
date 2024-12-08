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
                    onLongPress?()
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
            if var game = game {
                game.name = newValue
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
            if var game = game {
                game.developer = newValue
            }
        }
    }

    /// Publish Date (Editable)
    var publishDate: String? {
        get { game?.publishDate }
        set {
            if var game = game {
                game.publishDate = newValue
            }
        }
    }

    /// Genres (Comma seperated, editable)
    var genres: String? {
        get { game?.genres }
        set {
            if var game = game {
                game.genres = newValue
            }
        }
    }

    /// Region (Editable)
    var region: String? {
        get { game?.region }
        set {
            if var game = game {
                game.region = newValue
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

struct GameMoreInfoView: View {
    @StateObject var viewModel: GameMoreInfoViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork view at the top
                GameArtworkView(
                    frontArtwork: viewModel.frontArtwork,
                    backArtwork: viewModel.backArtwork
                )
                .padding(.vertical)

                // Info rows
                VStack(spacing: 12) {
                    LabelRowView(
                        label: "Name",
                        value: viewModel.name,
                        onLongPress: {
                            print("Edit name")
                        }
                    )

                    LabelRowView(
                        label: "Filename",
                        value: viewModel.filename
                    )

                    LabelRowView(
                        label: "System",
                        value: viewModel.system
                    )

                    LabelRowView(
                        label: "Developer",
                        value: viewModel.developer,
                        onLongPress: {
                            print("Edit developer")
                        }
                    )

                    LabelRowView(
                        label: "Publish Date",
                        value: viewModel.publishDate,
                        onLongPress: {
                            print("Edit publish date")
                        }
                    )

                    LabelRowView(
                        label: "Genres",
                        value: viewModel.genres,
                        onLongPress: {
                            print("Edit genres")
                        }
                    )

                    LabelRowView(
                        label: "Region",
                        value: viewModel.region,
                        onLongPress: {
                            print("Edit region")
                        }
                    )

                    LabelRowView(
                        label: "Plays",
                        value: viewModel.plays.map(String.init),
                        onLongPress: {
                            print("Reset plays")
                        }
                    )

                    LabelRowView(
                        label: "Time Spent",
                        value: viewModel.timeSpent.map(String.init),
                        onLongPress: {
                            print("Reset time spent")
                        }
                    )
                }
                .padding()
            }
        }
        .navigationTitle("Game Info")
    }
}

#Preview {
    NavigationView {
        GameMoreInfoView(viewModel: .mockViewModel())
    }
}
