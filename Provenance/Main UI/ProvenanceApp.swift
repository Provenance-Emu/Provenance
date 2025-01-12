import SwiftUI
import Foundation
import PVLogging
import PVSwiftUI
import PVFeatureFlags
import PVThemes
#if canImport(FreemiumKit)
import FreemiumKit
#endif
#if canImport(WhatsNewKit)
import WhatsNewKit
#endif

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(appDelegate: appDelegate)
                .environmentObject(appState)
                .environmentObject(featureFlags)
                .task {
                    try? await featureFlags.loadConfiguration(
                        from: URL(string: "https://data.provenance-emu.com/features/features.json")!
                    )
                }
            #if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
            #endif
            #if canImport(WhatsNewKit)
                .environment(
                       \.whatsNew,
                       WhatsNewEnvironment(
                           // Specify in which way the presented WhatsNew Versions are stored.
                           // In default the `UserDefaultsWhatsNewVersionStore` is used.
                           versionStore: // InMemoryWhatsNewVersionStore(),
                           NSUbiquitousKeyValueWhatsNewVersionStore(), // UserDefaultsWhatsNewVersionStore(),
                           // Pass a `WhatsNewCollectionProvider` or an array of WhatsNew instances
                           whatsNewCollection: self
                       )
                   )
            #endif
                .onAppear {
                    ILOG("ProvenanceApp: onAppear called, setting `appDelegate.appState = appState`")
                    appDelegate.appState = appState

                    // Initialize the settings factory and import presenter
                    #if os(tvOS)
                    appState.settingsFactory = SwiftUISettingsViewControllerFactory()
                    appState.importOptionsPresenter = SwiftUIImportOptionsPresenter()
                    #endif

            #if canImport(FreemiumKit)
                #if targetEnvironment(simulator) || DEBUG
                    FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
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

                /// Swizzle sendEvent(UIEvent)
                if !appState.sendEventWasSwizzled {
                    UIApplication.swizzleSendEvent()
                    appState.sendEventWasSwizzled = true
                }
            }
        }
    }
}

/// Hack to get touches send to RetroArch

extension UIApplication {

    /// Swap implipmentations of sendEvent() while
    /// maintaing a reference back to the original
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

    /// Placeholder for storing original selector
    @objc func originalSendEvent(_ event: UIEvent) { }

    /// The sendEvent that will be called
    @objc func pv_sendEvent(_ event: UIEvent) {
//        print("Handling touch event: \(event.type.rawValue ?? -1)")
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }

        originalSendEvent(event)
    }
}

// What's New!
#if canImport(WhatsNewKit)
// MARK: - App+WhatsNewCollectionProvider

extension ProvenanceApp: WhatsNewCollectionProvider {

    /// Declare your WhatsNew instances per version
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "3.0.0",
            title: "App Store first release",
            features: [
                .init(image: .init(systemName: "apple"),
                      title: .init("App Store first release"),
                      subtitle: .init("First release on App Store"))
            ]
        )
        WhatsNew(
            version: "3.0.1",
            title: "Performance & Polish",
            features: [
                .init(
                    image: .init(systemName: "bolt.fill", foregroundColor: .orange),
                    title: "Performance Improvements",
                    subtitle: "Faster app startup and improved overall performance. Now with iOS 16 support!"
                ),
                .init(
                    image: .init(systemName: "gamecontroller.fill", foregroundColor: .blue),
                    title: "Enhanced Gaming Experience",
                    subtitle: "Improved 3DS support with better layouts, touch controls, and new performance options including overclocking settings"
                ),
                .init(
                    image: .init(systemName: "paintbrush.fill", foregroundColor: .purple),
                    title: "UI Refinements",
                    subtitle: "Polished theme system, improved systems list layout, and clearer graphics settings"
                ),
                .init(
                    image: .init(systemName: "wrench.and.screwdriver.fill", foregroundColor: .green),
                    title: "Bug Fixes",
                    subtitle: "Fixed various crashes, improved save states menu, and resolved homepage display issues"
                ),
                .init(
                    image: .init(systemName: "plus.circle.fill", foregroundColor: .blue),
                    title: "New Addition",
                    subtitle: "Added support for the RetroArch Mupen-Next core for enhanced N64 emulation"
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                foregroundColor: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white,
                hapticFeedback: .notification(.success)
            )
        )
    }
}
#endif
