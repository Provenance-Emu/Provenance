//
//  GameContextMenu.swift
//  Provenance
//
//  Created by Ian Clawson on 1/28/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm

@_exported import PVUIBase

struct GameMoreInfoViewController: UIViewControllerRepresentable {
    typealias UIViewControllerType = GameMoreInfoPageViewController

    let game: PVGame

    func updateUIViewController(_ uiViewController: GameMoreInfoPageViewController, context: Context) {
        // No need to update anything here
    }

    func makeUIViewController(context: Context) -> GameMoreInfoPageViewController {
        let firstVC = UIStoryboard(name: "GameMoreInfo", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController

        // Ensure we're using a frozen copy of the game
        let frozenGame = game.isFrozen ? game : game.freeze()
        firstVC.game = frozenGame

        let moreInfoCollectionVC = GameMoreInfoPageViewController()
        moreInfoCollectionVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        return moreInfoCollectionVC
    }
}

struct GameContextMenu: SwiftUI.View {

    var game: PVGame

    weak var rootDelegate: PVRootDelegate?
    @State private var showingRenameAlert = false
    @State private var newGameTitle = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some SwiftUI.View {
        Group {
            if game.system.cores.count > 1 {
                Button {
                    Task { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                } label: { Label("Open in...", systemImage: "gamecontroller") }
            }
            Button {
                showMoreInfo(forGame: game)
            } label: { Label("Game Info", systemImage: "info.circle") }
            Button {
                // Toggle isFavorite for the selected PVGame
                let thawedGame = game.thaw()!
                try! Realm().write {
                    thawedGame.isFavorite = !thawedGame.isFavorite
                }
            } label: { Label("Favorite", systemImage: "heart") }
            Button {
                showingRenameAlert = true
                newGameTitle = game.title
            } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
            Button {
                promptUserMD5CopiedToClipboard(forGame: game)
            } label: { Label("Copy MD5 URL", systemImage: "number.square") }
            Button {
                promptUserToSelectArtwork(forGame: game)
            } label: { Label("Choose Cover", systemImage: "book.closed") }
            Button {
                pasteArtwork(forGame: game)
            } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
            Button {
                share(game: game)
            } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Divider()
            if #available(iOS 15, tvOS 15, macOS 12, *) {
                Button(role: .destructive) {
                    rootDelegate?.attemptToDelete(game: game)
                } label: { Label("Delete", systemImage: "trash") }
            } else {
                Button {
                    rootDelegate?.attemptToDelete(game: game)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .alert("Rename Game", isPresented: $showingRenameAlert) {
            TextField("New name", text: $newGameTitle)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                if !newGameTitle.isEmpty {
                    RomDatabase.sharedInstance.renameGame(game, toTitle: newGameTitle)
                } else {
                    rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
                }
            }
        } message: {
            Text("Enter a new name for \(game.title)")
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { self.selectedImage ?? UIImage() },
                set: { self.selectedImage = $0 }
            ), didSet: Binding(
                get: { self.selectedImage != nil },
                set: { _ in }
            ))
            .onDisappear {
                if let image = selectedImage {
                    saveArtwork(image: image, forGame: game)
                }
            }
        }
    }
}

extension GameContextMenu {

    func showMoreInfo(forGame game: PVGame) {
        let moreInfoCollectionVC = GameMoreInfoViewController(game: game)
        if let rootDelegate = rootDelegate as? UIViewController {

            let firstVC = UIStoryboard(name: "GameMoreInfo", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
            firstVC.game = game

            let moreInfoCollectionVC = GameMoreInfoPageViewController()
            moreInfoCollectionVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
            rootDelegate.present(moreInfoCollectionVC, animated: true)
        }
    }

    func promptUserMD5CopiedToClipboard(forGame game: PVGame) {
        // Get the MD5 of the game
        let md5 = game.md5
        // Copy to pasteboard
#if !os(tvOS)
        UIPasteboard.general.string = md5
        #endif

        rootDelegate?.showMessage("The MD5 hash for \(game.title) has been copied to the clipboard.", title: "MD5 Copied")
    }

    func promptUserToSelectArtwork(forGame game: PVGame) {
        showImagePicker = true
    }

    func pasteArtwork(forGame game: PVGame) {
        #if !os(tvOS)
        guard let artwork = UIPasteboard.general.image else {
            // Alert user Pasteboard did not contain image
            artworkNotFoundAlert()
            return
        }
        #endif
#warning("TODO: Paste artwork button action")
        self.rootDelegate?.showUnderConstructionAlert()
    }

    func artworkNotFoundAlert() {
        rootDelegate?.showMessage("Pasteboard did not contain an image.", title: "Artwork Not Found")
    }

    func share(game: PVGame) {
    #warning("TODO: Share button action")
    self.rootDelegate?.showUnderConstructionAlert()
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        do {
            let uniqueFileName = UUID().uuidString + ".png"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
            try image.pngData()?.write(to: fileURL)

            try RomDatabase.sharedInstance.writeTransaction {
                game.customArtworkURL = fileURL.absoluteString
            }
        } catch {
            rootDelegate?.showMessage("Failed to save artwork: \(error.localizedDescription)", title: "Error")
        }
    }
}
