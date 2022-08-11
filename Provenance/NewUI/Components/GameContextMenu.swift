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

@available(iOS 14, tvOS 14, *)
struct GameContextMenu: SwiftUI.View {

    var game: PVGame

    weak var rootDelegate: PVRootDelegate?

    var body: some SwiftUI.View {
        Group {
            Button {
                rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
            } label: { Label("Open in...", systemImage: "gamecontroller") }
            Button {
                self.rootDelegate?.root_presentGameInfo(game)
            } label: { Label("Game Info", systemImage: "info.circle") }
            Button {
                self.rootDelegate?.root_toggleFavorite(game)
            } label: { Label("Favorite", systemImage: "heart") }
            Button {
                self.rootDelegate?.root_renameGame(game)
            } label: { Label("Rename", systemImage: "rectangle.and.pencil.and.ellipsis") }
            Button {
                self.rootDelegate?.root_copyMD5URL(game)
            } label: { Label("Copy MD5 URL", systemImage: "number.square") }
            #warning("For some reason this kill the compiler")
//            Button {
//                self.rootDelegate?.root_chooseCover(game)
//            } label: { Label("Choose Cover", systemImage: "book.closed") }
            Button {
                self.rootDelegate?.root_pasteCover(game)
            } label: { Label("Paste Cover", systemImage: "doc.on.clipboard") }
            Button {
                self.rootDelegate?.root_restoreCover(game)
            } label: { Label("Restore Cover", systemImage: "photo") }
            Button {
                self.rootDelegate?.root_shareGame(game, sender: self)
            } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Divider()
            if #available(iOS 15, tvOS 15, *) {
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
#endif
