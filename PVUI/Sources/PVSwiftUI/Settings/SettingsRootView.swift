//
//  SettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/3/24.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase


/*
    * SettingsRootView
    * This is the root view for the settings screen.
    * It will contain a list of sections that the user can navigate through.
    * Each section will contain a list of settings that the user can interact with.
    * The settings will be persisted in a Realm database.
 
 group
    - App
        - Disable Auto Lock
            description: This also disables the screensaver
            type: Bool Switch
        - Systems
            description: Information on cores, thier bioses, links and stats
            type: push to SystemsView
        - Theme
            decription: Change the theme of the app
            type: radio selection
    - Core Options
        - Auto generated list of Cores with CoreOtional catgory
          type: navigation to CoreOptionsView
 
 */

@available(iOS 14, tvOS 14, *)
struct SettingsRootView: SwiftUI.View {
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            
        }
    }
}

#endif
