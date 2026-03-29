import SwiftUI

@main
struct ProvenanceCompanionApp: App {
    @State private var storeManager = DriverStoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(storeManager)
        }
    }
}
