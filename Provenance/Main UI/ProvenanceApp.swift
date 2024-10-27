import SwiftUI
import Foundation

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState, appDelegate: appDelegate)
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()
            }
        }
    }
}
