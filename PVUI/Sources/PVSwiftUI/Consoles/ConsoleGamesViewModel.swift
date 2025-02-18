//
//  ConsoleGamesViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVRealm
import PVSettings
import Combine

class ConsoleGamesViewModel: ObservableObject {
    let console: PVSystem

    @Published var focusedSection: HomeSectionType?
    @Published var focusedItemInSection: String?
    @Published var showDiscSelectionAlert = false
    @Published var discSelectionAlert: DiscSelectionAlert?

    init(console: PVSystem) {
        self.console = console
    }

    // Navigation state helpers
    func updateFocus(section: HomeSectionType?, item: String?) {
        focusedSection = section
        focusedItemInSection = item
    }

    func getCurrentSection() -> HomeSectionType? {
        return focusedSection
    }

    func getCurrentItem() -> String? {
        return focusedItemInSection
    }

    func presentDiscSelectionAlert(for game: PVGame, rootDelegate: PVRootDelegate?) {
        let discs = game.relatedFiles.toArray()
        let alertDiscs = discs.compactMap { disc -> DiscSelectionAlert.Disc? in
            return DiscSelectionAlert.Disc(fileName: disc.fileName, path: disc.url.path)
        }

        self.discSelectionAlert = DiscSelectionAlert(
            game: game,
            discs: alertDiscs
        )
        self.showDiscSelectionAlert = true
    }
}
