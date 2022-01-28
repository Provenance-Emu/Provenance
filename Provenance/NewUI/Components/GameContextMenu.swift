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

@available(iOS 14.0.0, *)
struct GameContextMenu: SwiftUI.View {
    
    @ObservedObject var game: PVGame
    
    var gameLaunchDelegate: GameLaunchingViewController?
    
    var body: some SwiftUI.View {
        Group {
            // Open with...
            Button {
                gameLaunchDelegate?.load(game, sender: self, core: nil, saveState: nil)
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
            // Delete
        }
    }
}
#endif
