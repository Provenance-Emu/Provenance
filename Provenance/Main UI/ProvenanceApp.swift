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
                    #if targetEnvironment(simulator)
                    FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                    #else
                    if !appDelegate.isAppStore {
                        FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                    }
                    #endif
#endif
                    /// Swizzle sendEvent(UIEvent)
                    UIApplication.swizzleSendEvent()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                appState.startBootupSequence()
            }
        }
    }
}

/// Hack to get touches send to RetroArch

extension UIApplication {
    
    @objc static func swizzleSendEvent() {
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            let swizzledSelector = #selector(UIApplication.pv_sendEvent(_:))
            let orginalStoreSelector = #selector(UIApplication.originalSendEvent(_:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                let swizzledMethod = class_getInstanceMethod(self, swizzledSelector),
                  let orginalStoreMethod = class_getInstanceMethod(self, orginalStoreSelector)
            else { return }
            method_exchangeImplementations(originalMethod, orginalStoreMethod)
            method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc func originalSendEvent(_ event: UIEvent) { }
    
    @objc func pv_sendEvent(_ event: UIEvent) {
//        print("Handling touch event: \(event.type.rawValue ?? -1)")
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
  
        originalSendEvent(event)
    }
}
