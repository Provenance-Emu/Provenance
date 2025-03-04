//
//  GameArtworkView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI
import UIKit
import PVRealm
import PVMediaCache
import PVThemes
import PVLogging

/// A view that displays game artwork with optional flipping between front and back artwork
struct GameArtworkView: View {
    let frontArtwork: UIImage?
    let backArtwork: UIImage?
    let game: PVGame?
    @State private var showingFrontArt = true
    @State private var isAnimating = false
    @State private var showingFullscreen = false
    @State private var showArtworkSourceAlert = false
    @State private var showImagePicker = false
    @State private var showArtworkSearch = false
    /// State to track the current artwork URL for change detection
    @State private var currentArtworkURL: String = ""

    weak var rootDelegate: PVRootDelegate?
    var contextMenuDelegate: GameContextMenuDelegate?

    /// Initialize with artwork and game information
    /// - Parameters:
    ///   - frontArtwork: The front artwork image
    ///   - backArtwork: The back artwork image
    ///   - game: The game object
    ///   - rootDelegate: The root delegate for handling UI actions
    ///   - contextMenuDelegate: The context menu delegate for handling menu actions
    init(
        frontArtwork: UIImage?,
        backArtwork: UIImage?,
        game: PVGame? = nil,
        rootDelegate: PVRootDelegate? = nil,
        contextMenuDelegate: GameContextMenuDelegate? = nil
    ) {
        self.frontArtwork = frontArtwork
        self.backArtwork = backArtwork
        self.game = game
        self.rootDelegate = rootDelegate
        self.contextMenuDelegate = contextMenuDelegate
        self._currentArtworkURL = State(initialValue: game?.trueArtworkURL ?? "")
    }

    private var canShowBackArt: Bool {
        backArtwork != nil
    }

    private var currentArtwork: UIImage? {
        showingFrontArt ? frontArtwork : (backArtwork?.withHorizontallyFlippedOrientation())
    }

    /// The game title to display in placeholder artwork
    private var gameTitle: String {
        // First try to get the title from the game object
        if let gameTitle = game?.title, !gameTitle.isEmpty {
            return gameTitle
        }

        // If we can't get it from the game object, return a default
        return "Unknown Game"
    }

    /// The aspect ratio to use for the artwork
    private var boxArtAspectRatio: PVGameBoxArtAspectRatio {
        game?.boxartAspectRatio ?? .square
    }

    var body: some View {
        Group {
            if let currentArtwork = currentArtwork {
                Image(uiImage: currentArtwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                /// Use ArtworkImageBaseView for placeholder artwork
                ArtworkImageBaseView(
                    artwork: nil,
                    gameTitle: gameTitle,
                    boxartAspectRatio: boxArtAspectRatio
                )
            }
        }
#if !os(tvOS)
        .background(Color(.systemBackground))
#endif
        .cornerRadius(8)
        .shadow(radius: 3)
        .padding()
        .rotation3DEffect(
            .degrees(showingFrontArt ? 0 : 180),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .animation(.easeInOut(duration: isAnimating ? 0.4 : 0), value: showingFrontArt)
        // Only enable double tap gesture when artwork is available
        .onTapGesture(count: 2) {
            if frontArtwork != nil {
                showingFullscreen = true
            }
        }
        .onTapGesture {
            if canShowBackArt {
                isAnimating = true
                showingFrontArt.toggle()
            }
        }
        // Only show overlay with instructions when artwork is available
        .overlay(
            Group {
                if frontArtwork != nil {
                    VStack {
                        Spacer()
                        Text(canShowBackArt ? "Tap to flip • Double-tap to enlarge • Hold for options" : "Double-tap to enlarge • Hold for options")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .background(Color(.systemBackground).opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 16)
                } else {
                    // Show a different message for placeholder artwork
                    VStack {
                        Spacer()
                        Text("Hold to add artwork")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .background(Color(.systemBackground).opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 16)
                }
            }
        )
        .onAppear {
            // Reset to front on appear
            showingFrontArt = true
            isAnimating = false

            // Store initial artwork URL for change detection
            if let game = game {
                currentArtworkURL = game.trueArtworkURL
            }

            // Setup notification observer for artwork changes
            NotificationCenter.default.addObserver(forName: .gameLibraryDidUpdate, object: nil, queue: .main) { _ in
                if let game = game, game.trueArtworkURL != currentArtworkURL {
                    currentArtworkURL = game.trueArtworkURL
                    // Force view to refresh
                    showingFrontArt = true
                }
            }
        }
        .onDisappear {
            // Remove notification observer
            NotificationCenter.default.removeObserver(self)

            // Reset all state variables
            showingFrontArt = true
            isAnimating = false
            showingFullscreen = false
            showArtworkSourceAlert = false
            showImagePicker = false
            showArtworkSearch = false
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            FullscreenArtworkView(
                frontImage: frontArtwork,
                backImage: backArtwork?.withHorizontallyFlippedOrientation()
            )
        }
        .contextMenu {
            if let game = game {
                Button {
                    showArtworkSourceAlert = true
                } label: {
                    Label("Choose Cover", systemImage: "book.closed")
                }

                Button {
                    pasteArtwork(forGame: game)
                } label: {
                    Label("Paste Cover", systemImage: "doc.on.clipboard")
                }

                if game.customArtworkURL != "" {
                    Button {
                        clearCustomArtwork(forGame: game)
                    } label: {
                        Label("Clear Custom Artwork", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .uiKitAlert(
            "Choose Artwork Source",
            message: "Select artwork from your photo library or search online sources",
            isPresented: $showArtworkSourceAlert,
            buttons: {
                UIAlertAction(title: "Select from Photos", style: .default) { _ in
                    handleArtworkSourceSelection(sourceType: .photoLibrary)
                }
                UIAlertAction(title: "Search Online", style: .default) { _ in
                    handleArtworkSourceSelection(sourceType: .onlineSearch)
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showArtworkSourceAlert = false
                }
            }
        )
    }

    /// Save artwork for a game
    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        Task {
            do {
                let uniqueID: String = UUID().uuidString
                let md5: String = game.md5 ?? ""
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
                    rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")
                }
            } catch {
                await MainActor.run {
                    DLOG("Failed to set custom artwork: \(error.localizedDescription)")
                    rootDelegate?.showMessage("Failed to set custom artwork: \(error.localizedDescription)", title: "Error")
                }
            }
        }
    }

    /// Paste artwork from clipboard
    func pasteArtwork(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
#if !os(tvOS)
        DLOG("Attempting to paste artwork for game: \(game.title)")
        let pasteboard = UIPasteboard.general
        if let pastedImage = pasteboard.image {
            DLOG("Image found in pasteboard")
            saveArtwork(image: pastedImage, forGame: game)
        } else if let pastedURL = pasteboard.url {
            DLOG("URL found in pasteboard: \(pastedURL)")
            do {
                let imageData = try Data(contentsOf: pastedURL)
                DLOG("Successfully loaded data from URL")
                if let image = UIImage(data: imageData) {
                    DLOG("Successfully created UIImage from URL data")
                    saveArtwork(image: image, forGame: game)
                } else {
                    DLOG("Failed to create UIImage from URL data")
                    artworkNotFoundAlert()
                }
            } catch {
                DLOG("Failed to load data from URL: \(error.localizedDescription)")
                artworkNotFoundAlert()
            }
        } else {
            DLOG("No image or URL found in pasteboard")
            artworkNotFoundAlert()
        }
#else
        DLOG("Pasting artwork not supported on this platform")
        rootDelegate?.showMessage("Pasting artwork is not supported on this platform.", title: "Not Supported")
#endif
    }

    /// Show alert when artwork is not found
    func artworkNotFoundAlert() {
        DLOG("Showing artwork not found alert")
        rootDelegate?.showMessage("Pasteboard did not contain an image.", title: "Artwork Not Found")
    }

    /// Clear custom artwork for a game
    private func clearCustomArtwork(forGame game: PVGame) {
        guard !game.isInvalidated else { return }
        DLOG("GameArtworkView: Attempting to clear custom artwork for game: \(game.title)")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.customArtworkURL = ""
            }
            rootDelegate?.showMessage("Custom artwork has been cleared for \(game.title).", title: "Artwork Cleared")
        } catch {
            DLOG("Failed to clear custom artwork: \(error.localizedDescription)")
            rootDelegate?.showMessage("Failed to clear custom artwork: \(error.localizedDescription)", title: "Error")
        }
    }

    /// Handle artwork source selection
    private func handleArtworkSourceSelection(sourceType: ArtworkSourceType) {
        guard let game = game, let contextMenuDelegate = contextMenuDelegate else { return }

        switch sourceType {
        case .photoLibrary:
            contextMenuDelegate.gameContextMenu(
                GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: contextMenuDelegate),
                didRequestShowImagePickerFor: game
            )
        case .onlineSearch:
            contextMenuDelegate.gameContextMenu(
                GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: contextMenuDelegate),
                didRequestShowArtworkSearchFor: game
            )
        }

        // Always reset the alert state
        showArtworkSourceAlert = false
    }

    /// Artwork source types
    private enum ArtworkSourceType {
        case photoLibrary
        case onlineSearch
    }
}
