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
    @Default(.webDavAlwaysOn) var webDavAlwaysOn
    @Default(.unsupportedCores) var unsupportedCores
    
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
                                    icon: .sfSymbol("bolt"))
                    }
                    .padding(.vertical, 4)
                }
                
                PremiumThemedToggle(isOn: $disableAutoLock) {
                    SettingsRow(title: "Disable Auto Lock",
                                subtitle: "Prevent device from auto-locking during gameplay.",
                                icon: .sfSymbol("lock.open"))
                }
                .padding(.vertical, 4)
                
                if !isAppStore {
                    PremiumThemedToggle(isOn: $iCloudSync) {
                        SettingsRow(title: "iCloud Sync",
                                    subtitle: "Sync save states and settings across devices.",
                                    icon: .sfSymbol("icloud"))
                    }
                    .padding(.vertical, 4)
                }
                
                PremiumThemedToggle(isOn: Binding(
                    get: { !useMetalRenderer },
                    set: { useMetalRenderer = !$0 }
                )) {
                    SettingsRow(title: "OpenGL Renderer",
                                subtitle: "Use OpenGL instead of Metal renderer for legacy graphics filters. Not all cores are supported.",
                                icon: .sfSymbol("cpu"))
                }
                
                PremiumThemedPicker(selection: $mainUIMode) {
                    SettingsRow(title: "UI Mode",
                                subtitle: "Choose between different UI modes: \(mainUIMode.description)",
                                icon: .sfSymbol("switch.2"))
                }
                
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
}
