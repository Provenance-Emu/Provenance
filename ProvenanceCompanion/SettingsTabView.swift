import SwiftUI

struct SettingsTabView: View {
    @Environment(\.openURL) private var openURL

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

                Section {
                    NavigationLink(String(localized: "store.nav_title")) {
                        DriverStoreView()
                    }
                } header: {
                    Text("settings.drivers.section")
                } footer: {
                    Text("settings.drivers.footer")
                }

                Section(String(localized: "settings.support.section")) {
                    if let githubURL = URL(string: "https://github.com/Provenance-Emu/Provenance") {
                        Link(String(localized: "settings.support.github"), destination: githubURL)
                    }
                    if let driverKitURL = URL(string: "https://developer.apple.com/contact/request/driverkit/") {
                        Link(String(localized: "settings.support.driverkit_entitlement"), destination: driverKitURL)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.nav_title"))
        }
    }
}

#Preview {
    SettingsTabView()
}
