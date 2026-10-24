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
    @Default(.mainUIMode) var mainUIMode
    @Default(.useModernWebServer) var useModernWebServer

    // Netplay, N64 Transfer Pak, Light Gun Crosshair, Companion Controller, Case Companion Skins,
    // Gameplay Clips, Live Broadcast and AirPlay Audio Menu moved to Emulation › Gameplay Features
    // (GameplayFeaturesSection) on 2026-10-16.

    private var isAppStore: Bool { AppState.shared.isAppStore }
    
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
            }
        }
    }
}
