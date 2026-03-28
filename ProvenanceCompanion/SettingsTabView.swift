import SwiftUI

struct SettingsTabView: View {
    @Environment(\.openURL) private var openURL
    #if !os(tvOS)
    @State private var showDriverStore = false
    #endif

    private let appVersion: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }()

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "settings.about.section")) {
                    LabeledContent(String(localized: "settings.about.app"),
                                   value: "Provenance Companion")
                    LabeledContent(String(localized: "settings.about.version"),
                                   value: appVersion)
                    LabeledContent(String(localized: "settings.about.purpose"),
                                   value: String(localized: "settings.about.purpose_value"))
                }

                Section(String(localized: "settings.main_app.section")) {
                    Button(String(localized: "settings.main_app.open_provenance")) {
                        if let url = URL(string: "provenance://") {
                            openURL(url)
                        }
                    }
                }

                // DriverKit and StoreKit driver packs are iOS/macOS only — DriverKit
                // extensions do not run on tvOS, so the purchase UI is excluded there.
                #if !os(tvOS)
                Section {
                    Button(String(localized: "store.nav_title")) {
                        showDriverStore = true
                    }
                } header: {
                    Text("settings.drivers.section")
                } footer: {
                    Text("settings.drivers.footer")
                }
                #endif

                Section(String(localized: "settings.support.section")) {
                    if let githubURL = URL(string: "https://github.com/Provenance-Emu/Provenance") {
                        Link(String(localized: "settings.support.github"), destination: githubURL)
                    }
                    #if !os(tvOS)
                    if let driverKitURL = URL(string: "https://developer.apple.com/contact/request/driverkit/") {
                        Link(String(localized: "settings.support.driverkit_entitlement"), destination: driverKitURL)
                    }
                    #endif
                }
            }
            .navigationTitle(String(localized: "settings.nav_title"))
            #if !os(tvOS)
            .sheet(isPresented: $showDriverStore) {
                DriverStoreView()
            }
            #endif
        }
    }
}

#Preview {
    SettingsTabView()
}
