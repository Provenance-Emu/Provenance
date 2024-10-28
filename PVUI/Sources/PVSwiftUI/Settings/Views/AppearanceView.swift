//
//  AppearanceView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import Combine

struct AppearanceView: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("Display Options")) {
                ThemedToggle(isOn: $viewModel.showGameTitles) {
                    SettingsRow(title: "Show Game Titles",
                              subtitle: "Display game titles under artwork.",
                              icon: .sfSymbol("textformat"))
                }

                ThemedToggle(isOn: $viewModel.showRecentGames) {
                    SettingsRow(title: "Show Recently Played Games",
                              subtitle: "Display recently played games section.",
                              icon: .sfSymbol("clock"))
                }

                ThemedToggle(isOn: $viewModel.showRecentSaveStates) {
                    SettingsRow(title: "Show Recent Save States",
                              subtitle: "Display recent save states section.",
                              icon: .sfSymbol("bookmark"))
                }

                ThemedToggle(isOn: $viewModel.showFavorites) {
                    SettingsRow(title: "Show Favorites",
                              subtitle: "Display favorites section.",
                              icon: .sfSymbol("star"))
                }

                ThemedToggle(isOn: $viewModel.showGameBadges) {
                    SettingsRow(title: "Show Game Badges",
                              subtitle: "Display badges on game artwork.",
                              icon: .sfSymbol("rosette"))
                }

                #if os(tvOS) || targetEnvironment(macCatalyst)
                ThemedToggle(isOn: $viewModel.largeGameArt) {
                    SettingsRow(title: "Show Large Game Artwork",
                              subtitle: "Use larger artwork in game grid.",
                              icon: .sfSymbol("rectangle.expand.vertical"))
                }
                #endif
            }
        }
        .navigationTitle("Appearance")
    }
}
