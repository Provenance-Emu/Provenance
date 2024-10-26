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
import PVLogging

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

protocol GameContextMenuDelegate {
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame)
}

struct GameContextMenu: SwiftUI.View {

    var game: PVGame

    weak var rootDelegate: PVRootDelegate?
    var contextMenuDelegate: GameContextMenuDelegate?

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
                contextMenuDelegate?.gameContextMenu(self, didRequestRenameFor: game)
            } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
            Button {
                promptUserMD5CopiedToClipboard(forGame: game)
            } label: { Label("Copy MD5 URL", systemImage: "number.square") }
#if !os(tvOS)
            Button {
                DLOG("GameContextMenu: Choose Cover button tapped")
                contextMenuDelegate?.gameContextMenu(self, didRequestChooseCoverFor: game)
            } label: { Label("Choose Cover", systemImage: "book.closed") }
#endif
            Button {
                pasteArtwork(forGame: game)
            } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
            //            Button {
            //                share(game: game)
            //            } label: { Label("Share", systemImage: "square.and.arrow.up") }
            // New menu item to clear custom artwork
            if game.customArtworkURL != "" {
                Button {
                    clearCustomArtwork(forGame: game)
                } label: { Label("Clear Custom Artwork", systemImage: "xmark.circle") }
            }
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
            rootDelegate.show(moreInfoCollectionVC, sender: self)
//            rootDelegate.present(moreInfoCollectionVC, animated: true)
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

    func pasteArtwork(forGame game: PVGame) {
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

    func artworkNotFoundAlert() {
        DLOG("Showing artwork not found alert")
        rootDelegate?.showMessage("Pasteboard did not contain an image.", title: "Artwork Not Found")
    }

    func share(game: PVGame) {
        #warning("TODO: Share button action")
        self.rootDelegate?.showUnderConstructionAlert()
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID = UUID().uuidString
        let key = "artwork_\(game.md5)_\(uniqueID)"
        DLOG("Generated key for image: \(key)")

        do {
            DLOG("Attempting to write image to disk")
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            DLOG("Image successfully written to disk")

            DLOG("Attempting to update game's customArtworkURL")
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                DLOG("Game thawed: \(thawedGame?.title ?? "Unknown")")
                thawedGame?.customArtworkURL = key
                DLOG("Game's customArtworkURL updated to: \(key)")
            }
            DLOG("Database transaction completed successfully")
            rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

            // Verify the image can be retrieved
            DLOG("Attempting to verify image retrieval")
            PVMediaCache.shareInstance().image(forKey: key) { retrievedKey, retrievedImage in
                if let retrievedImage = retrievedImage {
                    DLOG("Successfully retrieved saved image for key: \(retrievedKey)")
                    DLOG("Retrieved image size: \(retrievedImage.size)")
                } else {
                    DLOG("Failed to retrieve saved image for key: \(retrievedKey)")
                }
            }
        } catch {
            DLOG("Failed to set custom artwork: \(error.localizedDescription)")
            DLOG("Error details: \(error)")
            rootDelegate?.showMessage("Failed to set custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
    }

    private func clearCustomArtwork(forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to clear custom artwork for game: \(game.title)")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.customArtworkURL = ""
            }
            DLOG("Successfully cleared custom artwork for game: \(game.title)")
            rootDelegate?.showMessage("Custom artwork has been cleared for \(game.title).", title: "Artwork Cleared")
            try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            DLOG("Successfully deleted custom artowrk form game: \(game.title)")
        } catch {
            DLOG("Failed to clear custom artwork: \(error.localizedDescription)")
            rootDelegate?.showMessage("Failed to clear custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
    }
}
