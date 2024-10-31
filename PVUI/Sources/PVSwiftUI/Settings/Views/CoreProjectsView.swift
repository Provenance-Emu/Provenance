//
//  CoreProjectsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes
import PVLibrary

struct CoreProjectsView: View {
    let cores: [PVCore]
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var searchText = ""

    init() {
        cores = RomDatabase.sharedInstance.all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName)).toArray()
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
    }
}
