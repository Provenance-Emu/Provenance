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
    
    @ObservedRealmObject var game: PVGame
    
    var rootDelegate: PVRootDelegate?
    
    var body: some SwiftUI.View {
        Group {
            // Open with...
            Button {
                rootDelegate?.load(game, sender: self, core: nil, saveState: nil)
            } label: {
                Text("Open with...")
            }
            // Game Info
            // Favorite
            // Rename
            // Copy MD5 URL
            // Choose Cover
            // Paste Cover
            // Share
            Divider()
            // Delete
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
