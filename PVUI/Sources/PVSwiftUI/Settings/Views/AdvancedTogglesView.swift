//
//  AdvancedTogglesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/9/24.
//

import SwiftUI
import Combine

internal struct AdvancedTogglesView: View {
    @Default(.autoJIT) var autoJIT
    @Default(.disableAutoLock) var disableAutoLock
    @Default(.iCloudSync) var iCloudSync
    @Default(.useMetal) var useMetalRenderer
    @Default(.useUIKit) var useUIKit
    @Default(.webDavAlwaysOn) var webDavAlwaysOn
    @Default(.unsupportedCores) var unsupportedCores

#if !os(tvOS)
    @Default(.movableButtons) var movableButtons
#endif

    /// Check if the app is from the App Store
    let isAppStore: Bool = {
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }()

    var body: some View {

        Group {
            if !isAppStore {
                PremiumThemedToggle(isOn: $autoJIT) {
                    SettingsRow(title: "Auto JIT",
                                subtitle: "Automatically enable JIT when available.",
                                icon: .sfSymbol("bolt"))
                }
            }

            PremiumThemedToggle(isOn: $disableAutoLock) {
                SettingsRow(title: "Disable Auto Lock",
                            subtitle: "Prevent device from auto-locking during gameplay.",
                            icon: .sfSymbol("lock.open"))
            }

            if !isAppStore {
                PremiumThemedToggle(isOn: $iCloudSync) {
                    SettingsRow(title: "iCloud Sync",
                                subtitle: "Sync save states and settings across devices.",
                                icon: .sfSymbol("icloud"))
                }
            }

            PremiumThemedToggle(isOn: Binding(
                get: { !useMetalRenderer },
                set: { useMetalRenderer = !$0 }
            )) {
                SettingsRow(title: "OpenGL Renderer",
                            subtitle: "Use OpenGL instead of Metal renderer for legacy graphics filters. Not all cores are supported.",
                            icon: .sfSymbol("cpu"))
            }

            PremiumThemedToggle(isOn: $useUIKit) {
                SettingsRow(title: "Use UIKit",
                            subtitle: "Use UIKit interface instead of SwiftUI.",
                            icon: .sfSymbol("switch.2"))
            }

#if !os(tvOS)
            PremiumThemedToggle(isOn: $movableButtons) {
                SettingsRow(title: "Movable Buttons",
                            subtitle: "Allow player to move on screen controller buttons. Tap with 3-fingers 3 times to toggle.",
                            icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }
#endif
            PremiumThemedToggle(isOn: $webDavAlwaysOn) {
                SettingsRow(title: "WebDAV Always On",
                            subtitle: "Keep WebDAV server running in background.",
                            icon: .sfSymbol("network"))
            }

            if !isAppStore {
                PremiumThemedToggle(isOn: $unsupportedCores) {
                    SettingsRow(title: "Show Unsupported Cores",
                                subtitle: "Display experimental and unsupported cores.",
                                icon: .sfSymbol("exclamationmark.triangle"))
                }
            }
        }
    }
}
