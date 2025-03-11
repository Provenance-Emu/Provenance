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
}
