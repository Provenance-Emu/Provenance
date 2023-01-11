//
//  GameContextMenu.swift
//  Provenance
//
//  Created by Ian Clawson on 1/28/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)

import Foundation
import SwiftUI
import PVLibrary

@available(iOS 15, tvOS 15, *)
struct GameContextMenu: SwiftUI.View {

    @ObservedRealmObject var game: PVGame
    @State var multipleCores = false
    @State var isPresented = false
    @State private var showingMD5Alert = false
    @State private var showingRenameAlert = false

    weak var rootDelegate: PVRootDelegate?

    var body: some SwiftUI.View {
        Group {
            // Open in...
            if self.$multipleCores.wrappedValue {
                Button {
                    rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                } label: { Label("Open in...", systemImage: "gamecontroller") }
            }
            
            // Game Info
            Button {
            } label: { Label("Game Info", systemImage: "info.circle") }
                .sheet(isPresented: $isPresented) {
                   GameMoreInfoView(game: game)
                       .ignoresSafeArea()
               }
            
            // Favorite
            Button {
                do {
                    try RomDatabase.sharedInstance.writeTransaction {
                        self.game.thaw()?.isFavorite = !self.game.isFavorite
                    }
                } catch {
                    ELOG("\(error)")
                }
            } label: { Label("Favorite", systemImage: "heart") }
            
            // Rename
            Button {
//                self.renameGame(game)
                self.rootDelegate?.showUnderConstructionAlert() // TODO: this
            } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
            
            // Copy MD5 URL
            Button {
                let md5URL = "provenance://open?md5=\(game.md5Hash)"
                UIPasteboard.general.string = md5URL
                showingMD5Alert = true
            } label: { Label("Copy MD5 URL", systemImage: "number.square") }
                .alert("URL copied to clipboard", isPresented: $showingMD5Alert) {
                    Button("OK", role: .cancel) { }
                }

            // Choose cover
            Button {
                self.rootDelegate?.showUnderConstructionAlert() // TODO: this
//                self?.chooseCustomArtwork(for: game, sourceView: sender)
            } label: { Label("Choose Cover", systemImage: "book.closed") }
            
            // Paste cover
            if UIPasteboard.general.hasImages || UIPasteboard.general.hasURLs {
                Button {
                    self.rootDelegate?.showUnderConstructionAlert() // TODO: this
                } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
            }
            
            // Share
            Button {
//                if let libVC = viewController as? (UIViewController & GameSharingViewController) {
//                    libVC.share(for: game, sender: libVC.view)
//                }
                self.rootDelegate?.showUnderConstructionAlert() // TODO: this
            } label: { Label("Share", systemImage: "square.and.arrow.up") }
            
            Divider()
            
            // Delete
            Button(role: .destructive) {
                rootDelegate?.attemptToDelete(game: game)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
#endif
