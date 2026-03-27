import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("App", value: "Provenance Companion")
                    LabeledContent("Purpose", value: "DriverKit host & metadata companion")
                }

                Section("Main App") {
                    Button("Open Provenance") {
                        if let url = URL(string: "provenance://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsTabView()
}
