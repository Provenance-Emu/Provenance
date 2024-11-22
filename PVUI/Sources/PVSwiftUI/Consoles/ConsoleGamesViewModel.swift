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
}
