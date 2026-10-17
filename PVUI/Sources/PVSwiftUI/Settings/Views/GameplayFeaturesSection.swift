//
//  GameplayFeaturesSection.swift
//  PVUI
//
//  Settings › Emulation › Gameplay Features: user-facing features that used to sit under Advanced.
//

import SwiftUI
import PVUIBase
import Defaults
import PVSettings

internal struct GameplayFeaturesSection: View {
    @Default(.netplayEnabled) var netplayEnabled
    @Default(.mupenTransferPak) var mupenTransferPak
    @Default(.lightGunCrosshair) var lightGunCrosshair
    @Default(.companionController) var companionController
    #if os(iOS)
    @Default(.caseCompanionSkins) var caseCompanionSkins
    #endif
    @Default(.clipBufferingEnabled) var clipBufferingEnabled
    @Default(.liveBroadcast) var liveBroadcast
    @Default(.airPlayMenu) var airPlayMenu

    var body: some View {
        Section {
            ThemedToggle(isOn: $netplayEnabled) {
                SettingsRow(title: "Netplay",
                            subtitle: "Host and join rooms from Network Play in the library menu or from the pause menu, with cores that support it.",
                            icon: .sfSymbol("wifi"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $mupenTransferPak) {
                SettingsRow(title: "N64 Transfer Pak",
                            subtitle: "Assign a Game Boy ROM to a Mupen64Plus controller port for Pokémon Stadium / Mario Golf integration. Works on native and RetroArch N64 cores.",
                            icon: .sfSymbol("gamecontroller.fill"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $lightGunCrosshair) {
                SettingsRow(title: "Light Gun Crosshair",
                            subtitle: "Show an on-screen crosshair overlay for light-gun-capable cores. Configure the style in Mouse / Light Gun settings.",
                            icon: .sfSymbol("scope"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $companionController) {
                SettingsRow(title: "Companion Controller",
                            subtitle: "Show a companion-controller overlay (trackball, numpad, DSU peripherals) in the pause menu.",
                            icon: .sfSymbol("dpad"),
                            showChevron: false)
            }

            #if os(iOS)
            ThemedToggle(isOn: $caseCompanionSkins) {
                SettingsRow(title: "Case Companion Skins",
                            subtitle: "Auto-load phone-case companion DeltaSkins when a known case controller is connected (Backbone, Kishi, PocketTaco, Soolra, etc.).",
                            icon: .sfSymbol("rectangle.on.rectangle.angled"),
                            showChevron: false)
            }
            #endif

            ThemedToggle(isOn: $clipBufferingEnabled) {
                SettingsRow(title: "Gameplay Clips",
                            subtitle: "Keeps a rolling buffer so you can save recent clips from the pause menu. Uses screen recording.",
                            icon: .sfSymbol("scissors"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $liveBroadcast) {
                SettingsRow(title: "Live Broadcast",
                            subtitle: "ReplayKit Go Live button in the pause menu. Cast gameplay to Twitch, Facebook and other ReplayKit-compatible services.",
                            icon: .sfSymbol("dot.radiowaves.left.and.right"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $airPlayMenu) {
                SettingsRow(title: "AirPlay Audio Menu",
                            subtitle: "Show an AirPlay audio route-picker button in the pause menu. Audio only — video AirPlay is not yet implemented.",
                            icon: .sfSymbol("airplayaudio"),
                            showChevron: false)
            }
        }
    }
}
