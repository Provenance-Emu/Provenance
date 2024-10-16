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

struct GameMoreInfoViewController : UIViewControllerRepresentable {
    typealias UIViewControllerType = GameMoreInfoPageViewController

    var game: PVGame

   func updateUIViewController(_ uiViewController: GameMoreInfoPageViewController, context: Context) {
   }

   func makeUIViewController(context: Context) -> GameMoreInfoPageViewController {
       let firstVC = UIStoryboard(name: "GameMoreInfo", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
       firstVC.game = game

       let moreInfoCollectionVC = GameMoreInfoPageViewController.init() //segue.destination as! GameMoreInfoPageViewController
       moreInfoCollectionVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        return moreInfoCollectionVC
   }
}

@available(iOS 14, tvOS 14, *)
struct GameContextMenu: SwiftUI.View {

    var game: PVGame

    weak var rootDelegate: PVRootDelegate?

    var body: some SwiftUI.View {
        Group {
//            game.system.cores.count > 1 {
                Button {
                    Task { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                } label: { Label("Open in...", systemImage: "gamecontroller") }
//            }
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
                promptUserToRename(game: game)
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
    }
}

extension GameContextMenu {

    func showMoreInfo(forGame game: PVGame) {
        let moreInfoCollectionVC = GameMoreInfoViewController(game: game)

    }

    func promptUserToRename(game: PVGame) {
        #warning("TODO: Rename button action")
        self.rootDelegate?.showUnderConstructionAlert()
    }

    func promptUserMD5CopiedToClipboard(forGame game: PVGame) {
        // Get the MD5 of the game
        let md5 = game.md5
        // Copy to pasteboard
#if !os(tvOS)
        UIPasteboard.general.string = md5
        #endif
        // Alert the user that the MD5 has been copied to the clipboard

    }

    func promptUserToSelectArtwork(forGame game: PVGame) {
#warning("TODO: Select artwork button action")
        self.rootDelegate?.showUnderConstructionAlert()
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
//        let alert = Alert(
//            title: Text("No Artwork Found"),
//            message: Text("The clipboard does not contain an image that can be used as artwork."),
//            dismissButton: .default(Text("OK"))
//        )
//        rootDelegate?.presentAlert(alert)
    }

    func share(game: PVGame) {
    #warning("TODO: Share button action")
    self.rootDelegate?.showUnderConstructionAlert()
    }
}
