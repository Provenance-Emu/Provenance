import SwiftUI
import Foundation
import PVLogging

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(appDelegate: appDelegate)
                .environmentObject(appState)
                .onAppear {
                    ILOG("onAppear called, setting `appDelegate.appState = appState`")
                    appDelegate.appState = appState
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()
            }
        }
    }
}
