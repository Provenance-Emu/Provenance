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
#if canImport(Sentry)
import Sentry
#endif

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    init() {
//#if canImport(Sentry)
//        if appState.isAppStore {
//            SentrySDK.start { options in
//                options.dsn = "https://f9976bad538343d59606a8ef312d4720@o199354.ingest.us.sentry.io/1309415"
//                #if DEBUG
//                options.debug = true // Enabled debug when first installing is always helpful
//                // Enable tracing to capture 100% of transactions for tracing.
//                // Use 'options.tracesSampleRate' to set the sampling rate.
//                // We recommend setting a sample rate in production.
//                options.tracesSampleRate = 1.0 // tracing must be enabled for profiling
//                options.profilesSampleRate = 1.0 // see also `profilesSampler` if you need custom sampling logic
//                options.enableAppLaunchProfiling = true // experimental new feature to start profiling in the pre-main launch phase
//                options.sessionReplay.onErrorSampleRate = 1.0
//                options.sessionReplay.sessionSampleRate = 0.1
//                #else
//                options.tracesSampleRate = 0.5
//                options.sessionReplay.onErrorSampleRate = 1.0
//                #endif
//            }
//        }
//#endif
      }

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
                           versionStore:
//                             InMemoryWhatsNewVersionStore(),
                           NSUbiquitousKeyValueWhatsNewVersionStore(),
                           // UserDefaultsWhatsNewVersionStore(),
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
        if let core = AppState.shared.emulationUIState.core {
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
        WhatsNew(
            version: "3.0.2",
            title: "Stability & Performance",
            features: [
                .init(
                    image: .init(systemName: "shield.lefthalf.filled", foregroundColor: .blue),
                    title: "Enhanced Stability",
                    subtitle: "Added crash reporting and fixed several startup-related issues for a more reliable experience"
                ),
                .init(
                    image: .init(systemName: "gauge.with.dots.needle.bottom.50percent", foregroundColor: .green),
                    title: "Performance Optimizations",
                    subtitle: "Improved app startup speed and fixed cache-related delays"
                ),
                .init(
                    image: .init(systemName: "cpu", foregroundColor: .purple),
                    title: "BIOS Management",
                    subtitle: "Improved BIOS file detection and automatic matching across all systems"
                ),
                .init(
                    image: .init(systemName: "gamecontroller", foregroundColor: .orange),
                    title: "Controller Improvements",
                    subtitle: "Updated Saturn and Jaguar controller support for better gameplay experience"
                ),
                .init(
                    image: .init(systemName: "gearshape.2", foregroundColor: .purple),
                    title: "Core Enhancements",
                    subtitle: "Improved 3DS core options with instant updates for settings like upscaling and CPU clock speed"
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                foregroundColor: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white,
                hapticFeedback: .notification(.success)
            )
        )
        WhatsNew(
            version: "3.0.3",
            title: "Performance & Compatibility",
            features: [
                .init(
                    image: .init(systemName: "cpu.fill", foregroundColor: .blue),
                    title: "Core Scanning Improvements",
                    subtitle: "Enhanced core detection and loading to prevent boot crashes"
                ),
                .init(
                    image: .init(systemName: "exclamationmark.triangle.fill", foregroundColor: .orange),
                    title: "Better Error Handling",
                    subtitle: "Improved RetroArch error handling for enhanced stability"
                ),
                .init(
                    image: .init(systemName: "gamecontroller.fill", foregroundColor: .green),
                    title: "Controller Fixes",
                    subtitle: "Fixed Intellivision on-screen control layout and responsiveness"
                ),
                .init(
                    image: .init(systemName: "cpu.fill", foregroundColor: .purple),
                    title: "Graphics Enhancements",
                    subtitle: "Custom MoltenVK implementation to fix 3DS crashes and shader issues"
                ),
                .init(
                    image: .init(systemName: "display", foregroundColor: .red),
                    title: "Jaguar Improvements",
                    subtitle: "Fixed video rendering and display issues for Atari Jaguar games"
                ),
                .init(
                    image: .init(systemName: "archivebox.fill", foregroundColor: .blue),
                    title: "BIOS Support",
                    subtitle: "Added support for zipped BIOS files including Neo Geo and others"
                ),
                .init(
                    image: .init(systemName: "wrench.and.screwdriver.fill", foregroundColor: .gray),
                    title: "General Improvements",
                    subtitle: "Various bug fixes and stability improvements across all systems"
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                foregroundColor: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white,
                hapticFeedback: .notification(.success)
            )
        )
        WhatsNew(
            version: "3.0.4",
            title: "RetroArch Improvements",
            features: [
                .init(
                    image: .init(systemName: "square.3.layers.3d.top.filled", foregroundColor: .blue),
                    title: "3DS Graphics Enhancement",
                    subtitle: "Fixed shadow rendering issues for improved visual quality in 3DS games"
                ),
                .init(
                    image: .init(systemName: "list.bullet.rectangle.fill", foregroundColor: .orange),
                    title: "RetroArch Menu Fix",
                    subtitle: "Resolved issues with RetroArch menu display and navigation"
                ),
                .init(
                    image: .init(systemName: "bolt.horizontal.circle.fill", foregroundColor: .green),
                    title: "Core Performance",
                    subtitle: "Enhanced stability and responsiveness across all RetroArch-based cores"
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                foregroundColor: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white,
                hapticFeedback: .notification(.success)
            )
        )
        WhatsNew(
            version: "3.0.5",
            title: "New Cores & System Improvements",
            features: [
                .init(
                    image: .init(systemName: "gamecontroller.fill", foregroundColor: .blue),
                    title: "New RetroArch Cores",
                    subtitle: "Added Pokemini, BNES, BSNES HD, BSNES Mercury, GenesisPlus GX Wide, and improved FDS support with fceumm and nestopia"
                ),
                .init(
                    image: .init(systemName: "music.note", foregroundColor: .purple),
                    title: "Audio Improvements",
                    subtitle: "Added CoreMIDI support, improved audio switching, and reduced audio glitching during gameplay"
                ),
                .init(
                    image: .init(systemName: "gearshape.2.fill", foregroundColor: .orange),
                    title: "Core Enhancements",
                    subtitle: "Improved core options interface, better system compatibility, and enhanced feature flags system"
                ),
                .init(
                    image: .init(systemName: "arrow.triangle.2.circlepath", foregroundColor: .red),
                    title: "Performance & Stability",
                    subtitle: "Faster system bootup, improved state management, and various crash fixes"
                ),
                .init(
                    image: .init(systemName: "square.3.layers.3d.top.filled", foregroundColor: .green),
                    title: "3DS Improvements",
                    subtitle: "Added support for custom textures and improved graphics performance"
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                foregroundColor: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white,
                hapticFeedback: .notification(.success)
            )
        )
        WhatsNew(
            version: "3.0.6",
            title: "System Enhancements & Hardware Features",
            features: [
                .init(
                    image: .init(systemName: "plus.circle.fill", foregroundColor: .blue),
                    title: "Expanded Gaming Support",
                    subtitle: "Added support for classic PC games including DOOM, Quake, Quake II, and Wolf3D, plus Neo Geo .neo format support and additional DS emulator options"
                ),
                .init(
                    image: .init(systemName: "camera.fill", foregroundColor: .green),
                    title: "Hardware Integration",
                    subtitle: "Added camera support for DS games and improved MIDI device compatibility for DOSBox enhanced gameplay features"
                ),
                .init(
                    image: .init(systemName: "gamecontroller", foregroundColor: .orange),
                    title: "Controller Improvements",
                    subtitle: "New on-screen controls toggle button, improved gamepad support, and enhanced mouse input for iPad"
                ),
                .init(
                    image: .init(systemName: "arrow.triangle.2.circlepath", foregroundColor: .purple),
                    title: "Interface Improvements",
                    subtitle: "Updated UI designs with modern styling, enhanced homepage organization, and new menu pause control options"
                ),
                .init(
                    image: .init(systemName: "bolt.horizontal.circle.fill", foregroundColor: .red),
                    title: "Performance Optimizations",
                    subtitle: "Parallel system bootup with faster initialization, improved import queue processing, and silent mode ignore support"
                ),
                .init(
                    image: .init(systemName: "wrench.and.screwdriver.fill", foregroundColor: .gray),
                    title: "System Refinements",
                    subtitle: "Enhanced BIOS management, improved database handling, and various stability fixes"
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
