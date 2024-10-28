import SwiftUI
import Foundation
import PVLogging
import PVSwiftUI
#if canImport(FreemiumKit)
import FreemiumKit
#endif

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(appDelegate: appDelegate)
                .environmentObject(appState)
            #if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
            #endif
                .onAppear {
                    ILOG("ProvenanceApp: onAppear called, setting `appDelegate.appState = appState`")
                    appDelegate.appState = appState
#if canImport(FreemiumKit)
                    #if DEBUG
//                    FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                    #else
                    if !appDelegate.isAppStore {
                        FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                    }
                    #endif
#endif
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()
            }
        }
    }
}
