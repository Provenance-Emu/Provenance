//
//  AdvancedTogglesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/9/24.
//

import SwiftUI
import PVUIBase
import Combine
import PVLibrary
import Defaults
import PVSettings

internal struct AdvancedTogglesView: View {
    @Default(.autoJIT) var autoJIT
    @Default(.disableAutoLock) var disableAutoLock
    @Default(.useMetal) var useMetalRenderer
    @Default(.mainUIMode) var mainUIMode
    @Default(.useModernWebServer) var useModernWebServer

    // Promoted from PVFeatureFlags 2026-05-22 (commits 908087274c / 72a567288b).
    // Surfaced here so users can find and toggle them without depending on
    // the Feature Flags JSON or remote-config plumbing.
    // 2026-10-14: SRAM Import / Export (always on), Tap to Remap (always on) and
    // Reposition Skin Buttons (default on; editor entry point lives in the pause
    // menu) lost their toggles. Light Gun Crosshair, Netplay and N64 Transfer Pak
    // now default on and keep theirs. Clip buffering is promoted as Gameplay Clips.
    @Default(.caseCompanionSkins) var caseCompanionSkins
    @Default(.liveBroadcast) var liveBroadcast
    @Default(.netplayEnabled) var netplayEnabled
    @Default(.mupenTransferPak) var mupenTransferPak

    // Promoted from PVFeatureFlags 2026-05-31 as off-by-default toggles;
    // Companion Controller and AirPlay Audio Menu are still off by default.
    @Default(.companionController) var companionController
    @Default(.lightGunCrosshair) var lightGunCrosshair
    @Default(.airPlayMenu) var airPlayMenu
    @Default(.clipBufferingEnabled) var clipBufferingEnabled

    /// Check if the app is from the App Store
    let isAppStore: Bool = {
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // No title of its own: the enclosing Advanced section already heads it.
            VStack(spacing: 12) {
                if !isAppStore {
                    PremiumThemedToggle(isOn: $autoJIT) {
                        SettingsRow(title: "Auto JIT",
                                    subtitle: "Automatically enable JIT when available.",
                                    icon: .sfSymbol("bolt"),
                                    showChevron: false)
                    }
                    .padding(.vertical, 4)
                }
                
                PremiumThemedToggle(isOn: $disableAutoLock) {
                    SettingsRow(title: "Disable Auto Lock",
                                subtitle: "Prevent device from auto-locking during gameplay.",
                                icon: .sfSymbol("lock.open"),
                                showChevron: false)
                }
                .padding(.vertical, 4)
                
                PremiumThemedToggle(isOn: Binding(
                    get: { !useMetalRenderer },
                    set: { useMetalRenderer = !$0 }
                )) {
                    SettingsRow(title: "OpenGL Renderer",
                                subtitle: "Native cores only: present through OpenGL instead of Metal for the legacy graphics filters. libretro cores always use Metal.",
                                icon: .sfSymbol("cpu"),
                                showChevron: false)
                }
                
                PremiumThemedPicker(selection: $mainUIMode) {
                    SettingsRow(title: "UI Mode",
                                subtitle: "Choose between different UI modes: \(mainUIMode.description)",
                                icon: .sfSymbol("switch.2"),
                                showChevron: false)
                }
                
                PremiumThemedToggle(isOn: $useModernWebServer) {
                    SettingsRow(title: "Use Modern Web Server",
                                subtitle: "Opt in to the native Swift Hummingbird HTTP / WebDAV server. The default GCDWebServer UI is fully featured; the modern implementation is still reaching parity.",
                                icon: .sfSymbol("network"),
                                showChevron: false)
                }

                // Toggles that were PVFeatureFlag entries until 2026-05-22;
                // promoted to first-class user settings so they're discoverable.
                #if os(iOS)
                PremiumThemedToggle(isOn: $caseCompanionSkins) {
                    SettingsRow(title: "Case Companion Skins",
                                subtitle: "Auto-load phone-case companion DeltaSkins when a known case controller is connected (Backbone, Kishi, PocketTaco, Soolra, etc.).",
                                icon: .sfSymbol("rectangle.on.rectangle.angled"),
                                showChevron: false)
                }
                .padding(.vertical, 4)
                #endif

                PremiumThemedToggle(isOn: $liveBroadcast) {
                    SettingsRow(title: "Live Broadcast",
                                subtitle: "ReplayKit Go Live button in the pause menu. Cast gameplay to Twitch, Facebook and other ReplayKit-compatible services.",
                                icon: .sfSymbol("dot.radiowaves.left.and.right"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $netplayEnabled) {
                    SettingsRow(title: "Netplay",
                                subtitle: "Host and join rooms from the pause menu. Works with mGBA link cable and with libretro cores that support netplay packets, such as gpSP and melonDS DS.",
                                icon: .sfSymbol("wifi"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $mupenTransferPak) {
                    SettingsRow(title: "N64 Transfer Pak",
                                subtitle: "Assign a Game Boy ROM to a Mupen64Plus controller port for Pokémon Stadium / Mario Golf integration. Works on native and RetroArch N64 cores.",
                                icon: .sfSymbol("gamecontroller.fill"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                // Toggles promoted from PVFeatureFlags 2026-05-31.
                PremiumThemedToggle(isOn: $companionController) {
                    SettingsRow(title: "Companion Controller",
                                subtitle: "Show a companion-controller overlay (trackball, numpad, DSU peripherals) in the pause menu.",
                                icon: .sfSymbol("dpad"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $lightGunCrosshair) {
                    SettingsRow(title: "Light Gun Crosshair",
                                subtitle: "Show an on-screen crosshair overlay for light-gun-capable cores. Configure the style in Mouse / Light Gun settings.",
                                icon: .sfSymbol("scope"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $clipBufferingEnabled) {
                    SettingsRow(title: "Gameplay Clips",
                                subtitle: "Keeps a rolling buffer so you can save recent clips from the pause menu. Uses screen recording.",
                                icon: .sfSymbol("scissors"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $airPlayMenu) {
                    SettingsRow(title: "AirPlay Audio Menu",
                                subtitle: "Show an AirPlay audio route-picker button in the pause menu. Audio only — video AirPlay is not yet implemented.",
                                icon: .sfSymbol("airplayaudio"),
                                showChevron: false)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
