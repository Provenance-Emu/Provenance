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
                .onOpenURL { url in
                    // Handle the URL
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

                    ILOG("ProvenanceApp: Received URL to open: \(url.absoluteString)")

                    // Debug log the URL structure in detail
                    if let components = components {
                        DLOG("ProvenanceApp: URL scheme: \(components.scheme ?? "nil"), host: \(components.host ?? "nil"), path: \(components.path)")
                        if let queryItems = components.queryItems {
                            DLOG("ProvenanceApp: Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")
                        } else {
                            DLOG("ProvenanceApp: No query items found in URL")
                        }
                    }

                    if url.isFileURL {
                        ILOG("ProvenanceApp: Handling file URL")
                        return handle(fileURL: url)
                    }
                    else if let scheme = url.scheme, scheme.lowercased() == PVAppURLKey {
                        ILOG("ProvenanceApp: Handling app URL with scheme: \(scheme)")

                        // Check for direct md5 parameter in the URL
                        if let components = components,
                           components.host?.lowercased() == "open",
                           let queryItems = components.queryItems,
                           let md5Value = queryItems.first(where: { $0.name == "md5" })?.value,
                           !md5Value.isEmpty {
                            ILOG("ProvenanceApp: Found direct md5 parameter in URL: \(md5Value)")
                            AppState.shared.appOpenAction = .openMD5(md5Value)
                            return
                        }

                        handle(appURL: url)
                    } else if let components = components,
                              components.path == PVGameControllerKey,
                              let first = components.queryItems?.first,
                              first.name == PVGameMD5Key,
                              let md5Value = first.value {
                        ILOG("ProvenanceApp: Found game controller path with MD5: \(md5Value)")
                        AppState.shared.appOpenAction = .openMD5(md5Value)
                        return
                    } else {
                        WLOG("ProvenanceApp: Unrecognized URL format: \(url.absoluteString)")
                    }
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

            // Handle scene phase changes for import pausing
            appState.handleScenePhaseChange(newPhase)
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


// MARK: - URL Handling
extension ProvenanceApp {
    func handle(appURL url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let components = components else {
            ELOG("Failed to parse url <\(url.absoluteString)>")
            return false
        }

        ILOG("App to open url \(url.absoluteString). Parsed components: \(String(describing: components))")

        // Debug log the URL structure in detail
        DLOG("URL scheme: \(components.scheme ?? "nil"), host: \(components.host ?? "nil"), path: \(components.path)")
        if let queryItems = components.queryItems {
            DLOG("Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")
        } else {
            DLOG("No query items found in URL")
        }

        guard let action = AppURLKeys(rawValue: components.host ?? "") else {
            ELOG("Invalid host/action: \(components.host ?? "nil")")
            return false
        }

        switch action {
        case .save:
            guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                ELOG("Query items is nil")
                return false
            }

            guard let a = queryItems["action"] else {
                return false
            }

            let md5QueryItem = queryItems["PVGameMD5Key"]
            let systemItem = queryItems["system"]
            let nameItem = queryItems["title"]

            if let md5QueryItem = md5QueryItem {

            }
            if let systemItem = systemItem {

            }
            if let nameItem = nameItem {

            }
            return false
            // .filter("systemIdentifier == %@ AND title == %@", matchedSystem.identifier, gameName)
        case .open:
            guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                ELOG("No query items found for open action")
                return false
            }

            DLOG("Processing open action with \(queryItems.count) query items")

            // Check for direct md5 parameter (provenance://open?md5=...)
            if let md5Value = queryItems.first(where: { $0.name == "md5" })?.value, !md5Value.isEmpty {
                DLOG("Found direct md5 parameter: \(md5Value)")
                if let matchedGame = fetchGame(byMD5: md5Value) {
                    ILOG("Opening game by direct md5 parameter: \(md5Value)")
                    AppState.shared.appOpenAction = .openGame(matchedGame)
                    return true
                } else {
                    ELOG("Game not found for direct md5 parameter: \(md5Value)")
                    return false
                }
            }

            // Fall back to the original parameter names if direct md5 not found
            let md5QueryItem = queryItems["PVGameMD5Key"]
            let systemItem = queryItems["system"]
            let nameItem = queryItems["title"]

            DLOG("Fallback parameters - PVGameMD5Key: \(md5QueryItem ?? "nil"), system: \(systemItem ?? "nil"), title: \(nameItem ?? "nil")")

            if let value = md5QueryItem, !value.isEmpty,
               let matchedGame = fetchGame(byMD5: value) {
                // Match by md5
                ILOG("Open by md5 \(value)")
                AppState.shared.appOpenAction = .openGame(matchedGame)
                return true
            } else if let gameName = nameItem, !gameName.isEmpty {
                if let value = systemItem {
                    // Match by name and system
                    if !value.isEmpty,
                       let matchedSystem = fetchSystem(byIdentifier: value) {
                        if let matchedGame = RomDatabase.sharedInstance.all(PVGame.self).filter("systemIdentifier == %@ AND title == %@", matchedSystem.identifier, gameName).first {
                            ILOG("Open by system \(value), name: \(gameName)")
                            AppState.shared.appOpenAction = .openGame(matchedGame)
                            return true
                        } else {
                            ELOG("Failed to open by system \(value), name: \(gameName)")
                            return false
                        }
                    } else {
                        ELOG("Invalid system id \(systemItem ?? "nil")")
                        return false
                    }
                } else {
                    if let matchedGame = RomDatabase.sharedInstance.all(PVGame.self, where: #keyPath(PVGame.title), value: gameName).first {
                        ILOG("Open by name: \(gameName)")
                        AppState.shared.appOpenAction = .openGame(matchedGame)
                        return true
                    } else {
                        ELOG("Failed to open by name: \(gameName)")
                        return false
                    }
                }
            } else {
                ELOG("Open Query didn't have acceptable values")
                return false
            }
        }
    }

    func handle(fileURL url: URL) {
        let filename = url.lastPathComponent
        let destinationPath = Paths.romsImportPath.appendingPathComponent(filename, isDirectory: false)
        var secureDocument = false
        do {
            defer {
                if secureDocument {
                    url.stopAccessingSecurityScopedResource()
                }

            }

            // Doesn't seem we need access in dev builds?
            secureDocument = url.startAccessingSecurityScopedResource()

//            if let openInPlace = options[.openInPlace] as? Bool, openInPlace {
                try FileManager.default.copyItem(at: url, to: destinationPath)
//            } else {
//                try FileManager.default.moveItem(at: url, to: destinationPath)
//            }
        } catch {
            ELOG("Unable to move file from \(url.path) to \(destinationPath.path) because \(error.localizedDescription)")
            return
        }

        return
    }

    /// Helper method to safely fetch a game from Realm by its MD5 hash
    /// - Parameter md5: The MD5 hash of the game
    /// - Returns: The game if found, nil otherwise
    private func fetchGame(byMD5 md5: String) -> PVGame? {
        return RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5)
    }

    /// Helper method to safely fetch a system from Realm by its identifier
    /// - Parameter identifier: The system identifier
    /// - Returns: The system if found, nil otherwise
    private func fetchSystem(byIdentifier identifier: String) -> PVSystem? {
        return RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: identifier)
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
            title: "3DS Enhancements & UI Improvements",
            features: [
                .init(
                    image: .init(systemName: "gamecontroller.fill", foregroundColor: .blue),
                    title: "3DS Performance Boost",
                    subtitle: "Major optimizations for 3DS emulation with improved rendering, audio processing, and hardware acceleration"
                ),
                .init(
                    image: .init(systemName: "gearshape.2.fill", foregroundColor: .orange),
                    title: "Core Options Menu",
                    subtitle: "Access and customize RetroArch core options directly from the Provenance interface"
                ),
                .init(
                    image: .init(systemName: "magnifyingglass", foregroundColor: .green),
                    title: "Enhanced Search",
                    subtitle: "Improved search functionality in Home and Console views with auto-hiding search bars"
                ),
                .init(
                    image: .init(systemName: "opticaldisc", foregroundColor: .purple),
                    title: "Multi-Disc Support",
                    subtitle: "Enhanced disc selection menu for multi-disc games"
                ),
                .init(
                    image: .init(systemName: "arrow.clockwise", foregroundColor: .red),
                    title: "Core Updates",
                    subtitle: "Updated Mednafen to 1.32.1 and improved RetroArch cores with better Vulkan support"
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
