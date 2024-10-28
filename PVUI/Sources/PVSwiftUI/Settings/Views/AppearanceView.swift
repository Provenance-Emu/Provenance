//
//  AppearanceView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import Combine

struct AppearanceView: View {
    @Default(.showGameTitles) var showGameTitles
    @Default(.showRecentGames) var showRecentGames
    @Default(.showRecentSaveStates) var showRecentSaveStates
    @Default(.showGameBadges) var showGameBadges
    @Default(.showFavorites) var showFavorites
#if os(tvOS) || targetEnvironment(macCatalyst)
    @Default(.largeGameArt) var largeGameArt
#endif

    var body: some View {
        Form {
            Section(header: Text("Display Options")) {
                ThemedToggle(isOn: $showGameTitles) {
                    SettingsRow(title: "Show Game Titles",
                              subtitle: "Display game titles under artwork.",
                              icon: .sfSymbol("textformat"))
                }

                ThemedToggle(isOn: $showRecentGames) {
                    SettingsRow(title: "Show Recently Played Games",
                              subtitle: "Display recently played games section.",
                              icon: .sfSymbol("clock"))
                }

                ThemedToggle(isOn: $showRecentSaveStates) {
                    SettingsRow(title: "Show Recent Save States",
                              subtitle: "Display recent save states section.",
                              icon: .sfSymbol("bookmark"))
                }

                ThemedToggle(isOn: $showFavorites) {
                    SettingsRow(title: "Show Favorites",
                              subtitle: "Display favorites section.",
                              icon: .sfSymbol("star"))
                }

                ThemedToggle(isOn: $showGameBadges) {
                    SettingsRow(title: "Show Game Badges",
                              subtitle: "Display badges on game artwork.",
                              icon: .sfSymbol("rosette"))
                }

                #if os(tvOS) || targetEnvironment(macCatalyst)
                ThemedToggle(isOn: $largeGameArt) {
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

//private struct AppearanceSection: View {
//    @Default(.showGameTitles) var showGameTitles
//    @Default(.showRecentGames) var showRecentGames
//    @Default(.showRecentSaveStates) var showRecentSaveStates
//    @Default(.showGameBadges) var showGameBadges
//    @Default(.showFavorites) var showFavorites
//
//    var body: some View {
//        Section(header: Text("Appearance")) {
//            ThemedToggle(isOn: $showGameTitles) {
//                SettingsRow(title: "Show Game Titles",
//                           subtitle: "Display game titles under artwork.",
//                           icon: .sfSymbol("text.below.photo"))
//            }
//            ThemedToggle(isOn: $showRecentGames) {
//                SettingsRow(title: "Show Recent Games",
//                           subtitle: "Display recently played games section.",
//                           icon: .sfSymbol("clock"))
//            }
//            ThemedToggle(isOn: $showRecentSaveStates) {
//                SettingsRow(title: "Show Recent Saves",
//                           subtitle: "Display recent save states section.",
//                           icon: .sfSymbol("clock.badge.checkmark"))
//            }
//            ThemedToggle(isOn: $showGameBadges) {
//                SettingsRow(title: "Show Game Badges",
//                           subtitle: "Display badges for favorite and recent games.",
//                           icon: .sfSymbol("star.circle"))
//            }
//            ThemedToggle(isOn: $showFavorites) {
//                SettingsRow(title: "Show Favorites",
//                           subtitle: "Display favorites section.",
//                           icon: .sfSymbol("star"))
//            }
//        }
//    }
//}
