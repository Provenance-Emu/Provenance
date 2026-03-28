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
                Section("About") {
                    LabeledContent("App", value: "Provenance Companion")
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Purpose", value: "DriverKit host & upsell companion")
                }

                Section("Main App") {
                    Button("Open Provenance") {
                        if let url = URL(string: "provenance://") {
                            openURL(url)
                        }
                    }
                }

                Section {
                    NavigationLink("Driver Store") {
                        DriverStoreView()
                    }
                } header: {
                    Text("Drivers")
                } footer: {
                    Text("Purchased drivers are system-wide — they benefit every emulator and game on your iPad.")
                }

                Section("Support") {
                    Link("Provenance on GitHub", destination: URL(string: "https://github.com/Provenance-Emu/Provenance")!)
                    Link("DriverKit Entitlement Request", destination: URL(string: "https://developer.apple.com/contact/request/driverkit/")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsTabView()
}
