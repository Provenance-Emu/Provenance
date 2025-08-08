//
//  CoreProjectsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes
import PVLibrary
import Defaults
import PVSettings

struct CoreProjectsView: View {
    private let cores: [PVCore]
    @Default(.unsupportedCores) private var unsupportedCores
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var searchText = ""
    /// State to force view updates when unsupportedCores changes
    @State private var viewUpdateTrigger = false

    init() {
        let isAppStore = AppState.shared.isAppStore
        let allCores = RomDatabase.sharedInstance.all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName)).toArray()

        self.cores = allCores.filter { core in
            // Keep core if:
            // 1. It's not disabled, OR unsupportedCores is true
            // 2. AND (It's not app store disabled, OR we're not in the app store, OR unsupportedCores is true)
            (!core.disabled || Defaults[.unsupportedCores]) &&
            (!core.appStoreDisabled || !isAppStore || Defaults[.unsupportedCores])
        }
    }

    var filteredCores: [PVCore] {
        if searchText.isEmpty {
            return cores
        }
        return cores.filter { core in
            core.projectName.localizedCaseInsensitiveContains(searchText) ||
            core.supportedSystems.contains {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            ForEach(filteredCores, id: \.self) { core in
                CoreSection(core: core, systems: Array(core.supportedSystems))
            }
        }
        .searchable(text: $searchText, prompt: "Search cores or systems")
        .navigationTitle("Emulator Cores")
        .tvOSNavigationSupport(title: "Emulator Cores")
        .onChange(of: unsupportedCores) { _ in
            /// Force view to update by toggling state
            viewUpdateTrigger.toggle()
        }
        /// Add id modifier that depends on both unsupportedCores and viewUpdateTrigger
        .id("\(unsupportedCores)_\(viewUpdateTrigger)")
    }
}
