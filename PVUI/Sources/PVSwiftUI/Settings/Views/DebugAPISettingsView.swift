//
//  DebugAPISettingsView.swift
//  PVUI
//
//  Hidden Developer page (shown with Feature Flags Debug: always on DEBUG /
//  sideload / TestFlight, behind the secret D-pad unlock on App Store installs)
//  for the `/api/debug/*` automation API and screenshot-safe library covers.
//  See `Scripts/capture_device_screenshots.py`.
//

import SwiftUI
import Defaults
import PVSettings
import PVThemes
import PVUIBase
#if canImport(PVWebServer)
import PVWebServer
#endif

struct DebugAPISettingsView: View {
    @Default(.debugAPIEnabled) private var debugAPIEnabled
    @Default(.debugAPIPassword) private var debugAPIPassword
    @Default(.pixelateLibraryArtwork) private var pixelateLibraryArtwork
    @State private var authEnabled = false
    @State private var serverURL: String?

    var body: some View {
        ZStack {
            RetroTheme.retroBackground

            ScrollView {
                VStack(spacing: 12) {
                    SettingsSubheading(title: "Debug API")

                    #if canImport(PVWebServer)
                    if PVDebugAPIPrefs.isDebugBuild {
                        SettingsRow(title: "Debug API: always on",
                                    subtitle: "DEBUG build — /api/debug/* is registered on the web server.",
                                    icon: .sfSymbol("ladybug"),
                                    showChevron: false)
                    } else {
                        PremiumThemedToggle(isOn: $debugAPIEnabled) {
                            SettingsRow(title: "Enable Debug API",
                                        subtitle: "Expose /api/debug/* (screenshots, boot, savestates) on the local network. Takes effect when the web server restarts.",
                                        icon: .sfSymbol("ladybug"),
                                        showChevron: false)
                        }
                    }

                    PremiumThemedToggle(isOn: $authEnabled) {
                        SettingsRow(title: "Require Password",
                                    subtitle: "HTTP Basic Auth, username \"\(PVDebugAPIPrefs.username)\". With no password set, every request is refused.",
                                    icon: .sfSymbol("lock"),
                                    showChevron: false)
                    }
                    .onChange(of: authEnabled) { PVDebugAPIPrefs.authEnabled = $0 }

                    TextField("Password", text: $debugAPIPassword)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        #endif

                    if let serverURL {
                        SettingsRow(title: "Server",
                                    subtitle: "\(serverURL)api/debug",
                                    icon: .sfSymbol("network"),
                                    showChevron: false)
                    }
                    #endif

                    SettingsSubheading(title: "Screenshots")

                    PremiumThemedToggle(isOn: $pixelateLibraryArtwork) {
                        SettingsRow(title: "Pixelate Library Artwork",
                                    subtitle: "Render covers as a coarse pixel mosaic so screenshots keep color and layout without readable box art.",
                                    icon: .sfSymbol("square.grid.3x3"),
                                    showChevron: false)
                    }
                }
                .padding()
            }
        }
        .task {
            #if canImport(PVWebServer)
            authEnabled = PVDebugAPIPrefs.authEnabled
            serverURL = await PVWebServerManager.shared.serverURL?.absoluteString
            #endif
        }
    }
}
