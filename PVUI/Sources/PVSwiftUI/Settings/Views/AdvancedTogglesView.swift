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
    @Default(.iCloudSync) var iCloudSync
    @Default(.useMetal) var useMetalRenderer
    @Default(.mainUIMode) var mainUIMode
    @Default(.useModernWebServer) var useModernWebServer
    @Default(.useLegacyRetroArchWrapper) var useLegacyRetroArchWrapper

    // Promoted from PVFeatureFlags 2026-05-22 (commits 908087274c / 72a567288b).
    // Surfaced here so users can find and toggle them without depending on
    // the Feature Flags JSON or remote-config plumbing.
    @Default(.sramImportExport) var sramImportExport
    @Default(.caseCompanionSkins) var caseCompanionSkins
    @Default(.liveBroadcast) var liveBroadcast
    @Default(.netplayEnabled) var netplayEnabled
    @Default(.mupenTransferPak) var mupenTransferPak

    /// Check if the app is from the App Store
    let isAppStore: Bool = {
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // Title with retrowave styling
            Text("ADVANCED OPTIONS")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 8)
                .padding(.bottom, 8)
                .shadow(color: .retroPink.opacity(0.5), radius: 5, x: 0, y: 0)
            
            // Options with retrowave styling
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
                
                if !isAppStore {
                    PremiumThemedToggle(isOn: $iCloudSync) {
                        SettingsRow(title: "iCloud Sync",
                                    subtitle: "Sync save states and settings across devices.",
                                    icon: .sfSymbol("icloud"),
                                    showChevron: false)
                    }
                    .padding(.vertical, 4)
                }
                
                PremiumThemedToggle(isOn: Binding(
                    get: { !useMetalRenderer },
                    set: { useMetalRenderer = !$0 }
                )) {
                    SettingsRow(title: "OpenGL Renderer",
                                subtitle: "Use OpenGL instead of Metal renderer for legacy graphics filters. Not all cores are supported.",
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

                #if os(iOS)
                PremiumThemedToggle(isOn: $useLegacyRetroArchWrapper) {
                    SettingsRow(title: "Use Legacy RetroArch Wrapper",
                                subtitle: "Revert to the full in-process RetroArch runtime for libretro cores. The default lightweight wrapper has better scaling, lower memory use, and the same core compatibility. Enable this only if you experience a regression with a specific core.",
                                icon: .sfSymbol("arrow.uturn.backward.circle"),
                                showChevron: false)
                }
                .padding(.vertical, 4)
                #endif

                // Beta-promoted toggles. Each was a PVFeatureFlag entry until
                // 2026-05-22; promoted to first-class user settings so they're
                // discoverable. All default OFF except sramImportExport.
                #if os(iOS)
                PremiumThemedToggle(isOn: $sramImportExport) {
                    SettingsRow(title: "SRAM Import / Export",
                                subtitle: "Show explicit battery-save import and export actions in the game context menu. iOS only — tvOS syncs saves via iCloud.",
                                icon: .sfSymbol("square.and.arrow.up.on.square"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

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
                                subtitle: "ReplayKit Go Live button in the pause menu. Cast gameplay to Twitch / Facebook / other ReplayKit-compatible services. Early — quality and reconnect handling still iterating.",
                                icon: .sfSymbol("dot.radiowaves.left.and.right"),
                                showChevron: false)
                }
                .padding(.vertical, 4)

                PremiumThemedToggle(isOn: $netplayEnabled) {
                    SettingsRow(title: "Netplay",
                                subtitle: "Native lobby and host / join UI for RetroArch cores. mGBA link-cable also works. Other native cores have stub conformances and don't connect yet.",
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
            }
        }
    }
}
