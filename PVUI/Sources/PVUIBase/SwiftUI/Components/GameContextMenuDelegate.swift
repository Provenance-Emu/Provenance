//
//  GameContextMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/31/24.
//

import Foundation
import SwiftUI
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm
import PVLogging
import PVUIBase

public protocol GameContextMenuDelegate {
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String)
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestDownloadFromCloudFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestSkinSelectionFor game: PVGame)
    func gameContextMenu(_ menu: GameContextMenu, didRequestResetSkinFor game: PVGame)
}

/// Default implementations for GameContextMenuDelegate
/// This allows types to conform to the protocol without implementing all methods
public extension GameContextMenuDelegate {
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        DLOG("Default implementation: didRequestRenameFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        DLOG("Default implementation: didRequestChooseCoverFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("Default implementation: didRequestMoveToSystemFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("Default implementation: didRequestShowSaveStatesFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        DLOG("Default implementation: didRequestShowGameInfoFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        DLOG("Default implementation: didRequestShowImagePickerFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        DLOG("Default implementation: didRequestShowArtworkSearchFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("Default implementation: didRequestChooseArtworkSourceFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        DLOG("Default implementation: didRequestDiscSelectionFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDownloadFromCloudFor game: PVGame) {
        DLOG("Default implementation: didRequestDownloadFromCloudFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestSkinSelectionFor game: PVGame) {
        DLOG("Default implementation: didRequestSkinSelectionFor not implemented")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestResetSkinFor game: PVGame) {
        DLOG("Default implementation: didRequestResetSkinFor not implemented")
    }
}
