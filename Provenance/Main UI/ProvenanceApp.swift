import SwiftUI
import Foundation
import PVLogging
import PVSwiftUI
import PVUIBase
import PVFeatureFlags
import PVThemes
import PVLibrary
import PVEmulatorCore
import PVCoreBridge
import UserNotifications
#if os(tvOS)
import CloudKit
#endif
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
    @StateObject private var sceneCoordinator = SceneCoordinator.shared

    /// Handles the spotlight indexing background task identifier
    @State private var spotlightBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    init() {
        // Register for Spotlight background processing
        registerSpotlightBackgroundTask()
    }

    /// Register a background task for Spotlight indexing
    private func registerSpotlightBackgroundTask() {
        // Register a background task identifier for Spotlight indexing
        var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "SpotlightIndexing") {
            WLOG("Spotlight indexing background task expired")
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }

        // Store the background task identifier for later use
        spotlightBackgroundTaskIdentifier = backgroundTaskIdentifier

        ILOG("Registered background task for Spotlight indexing with identifier: \(backgroundTaskIdentifier)")
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .netplayJoinHandler()
                .environmentObject(appState)
                .environmentObject(PVFeatureFlagsManager.shared)
                .environmentObject(appDelegate)
                .environmentObject(appState.bootupStateManager)
                .environmentObject(ThemeManager.shared)
                .task {
                    try? await PVFeatureFlagsManager.shared.loadConfiguration(
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
                        whatsNewCollection: WhatsNewLoader.loadAll(
                            primaryActionBackground: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
                            primaryActionForeground: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white
                        )
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
            #if !os(tvOS)
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    handleSpotlightActivity(userActivity)
                }
                .onContinueUserActivity(CSQueryContinuationActionType) { userActivity in
                    ILOG("ProvenanceApp: Handling Siri 'Search in App' continuation activity")
                    handleSiriSearchActivity(userActivity)
                }
                .onContinueUserActivity("PVOpenIntent") { userActivity in
                    ILOG("ProvenanceApp: Handling PVOpenIntent user activity")
                    handleIntentUserActivity(userActivity)
                }
                .onContinueUserActivity("com.provenance.open-game") { userActivity in
                    ILOG("ProvenanceApp: Handling com.provenance.open-game user activity")
                    handleIntentUserActivity(userActivity)
                }
            #endif
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

                        // Prefer save state id if present (TopShelf "Recent Saves")
                        if let components = components,
                           components.host?.lowercased() == "open",
                           let queryItems = components.queryItems,
                           let saveStateID = queryItems.first(where: { $0.name == AppURLKeys.OpenKeys.saveStateId.rawValue })?.value,
                           !saveStateID.isEmpty {
                            ILOG("ProvenanceApp: Found saveStateId parameter in URL: \(saveStateID)")
                            AppState.shared.appOpenAction = .openSaveStateID(saveStateID)
                            // Don't open immediately - wait for bootup completion
                            openEmulatorSceneWhenReady()
                            return
                        }

                        // Check for direct md5 parameter in the URL
                        if let components = components,
                           components.host?.lowercased() == "open",
                           let queryItems = components.queryItems,
                           let md5Value = queryItems.first(where: { $0.name == AppURLKeys.OpenKeys.md5.rawValue })?.value,
                           !md5Value.isEmpty {
                            ILOG("ProvenanceApp: Found direct md5 parameter in URL: \(md5Value)")
                            AppState.shared.appOpenAction = .openMD5(md5Value)
                            // Don't open immediately - wait for bootup completion
                            openEmulatorSceneWhenReady()
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
                        // Don't open immediately - wait for bootup completion
                        openEmulatorSceneWhenReady()
                        return
                    } else {
                        WLOG("ProvenanceApp: Unrecognized URL format: \(url.absoluteString)")
                    }
                }
            #if !os(tvOS)
                .handlesExternalEvents(preferring: ["main"], allowing: ["main"])
            #endif
                .preferredColorScheme(ThemeManager.shared.currentPalette.dark ? .dark : .light)
                // Add listener for bootup state changes to trigger Spotlight reindexing
                .onReceive(appState.bootupStateManager.$currentState) { state in
                    if case .completed = state {
                        _initICloud()
                        // When bootup is completed, trigger Spotlight reindexing
                        // This is a good time to do it as the database is fully loaded
                        ILOG("Bootup completed, triggering Spotlight reindexing")
//                        DispatchQueue.global(qos: .utility).async {
//                            self.forceSpotlightReindexing()
//                        }

                        // CRITICAL: Now that bootup is complete, handle any pending emulator scene requests
                        openEmulatorSceneIfNeeded()

                        // Home Screen Quick Action taps are handled by HomeScreenShortcutService
                        // via PVSceneDelegate — no need to check pendingShortcutItem here.
                    }
                }
                // Observe appOpenAction changes to handle shortcuts and TopShelf launches
                .onReceive(appState.$appOpenAction) { action in
                    // Handle all action types that require the emulator scene
                    if action.requiresEmulatorScene {
                        ILOG("ProvenanceApp: Detected appOpenAction change requiring emulator scene: \(String(describing: action))")
                        if appState.bootupState == .completed {
                            openEmulatorSceneIfNeeded()
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {

                // Start bootup sequence
                appState.startBootupSequence()

                // Initialize CloudKit subscription manager when app becomes active
                if Defaults[.iCloudSync] {
                    Task {
                        await CloudKitSubscriptionManager.shared.setupSubscriptions()
                    }
                }

                /// Swizzle sendEvent(UIEvent)
                if !appState.sendEventWasSwizzled {
                    UIApplication.swizzleSendEvent()
                    appState.sendEventWasSwizzled = true
                }

                // Only check for app open action if there's no current game
                // This prevents reopening games when returning from emulator
                if appState.bootupState == .completed, appState.emulationUIState.currentGame == nil {
                    openEmulatorSceneIfNeeded()
                }

                ILOG("skins: Setting SkinImporterInjector service to DeltaSkinManager.shared")
                SkinImporterInjector.shared.service = DeltaSkinManager.shared
                ILOG("skins: SkinImporterInjector service initialized")

                // Drain any Siri/Shortcuts/Widget pending side-effects and refresh widget timelines
                processPendingAppIntents()
            }

            // Handle scene phase changes for import pausing
            appState.handleScenePhaseChange(newPhase)
        }

        // Add the emulator scene
        EmulatorScene()
        #if !os(tvOS)
            .handlesExternalEvents(matching: ["emulator"])
        #endif
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
    /// Prepares the game for the emulator scene by fetching it from the database if needed
    private func prepareGameForEmulatorScene() {
        switch appState.appOpenAction {
        case .openMD5(let md5):
            // MD5 primary keys are stored uppercase; normalise to avoid case mismatches
            // when the deep link supplies a lower- or mixed-case hash.
            let normalizedMD5 = md5.uppercased()
            if let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: normalizedMD5) {
                ILOG("ProvenanceApp: Found game '\(game.title)' for MD5: \(normalizedMD5)")
                appState.emulationUIState.currentGame = game
                #if os(iOS)
                if #available(iOS 14.0, *) {
                    appDelegate.donateMediaIntent(for: game)
                }
                #endif
            } else {
                ELOG("ProvenanceApp: No game found for MD5: \(normalizedMD5)")
            }
        case .openGame(let game):
            ILOG("ProvenanceApp: Setting currentGame to '\(game.title)'")
            appState.emulationUIState.currentGame = game
            #if os(iOS)
            if #available(iOS 14.0, *) {
                appDelegate.donateMediaIntent(for: game)
            }
            #endif
        case .openSaveStateID(let saveStateID):
            let realm = RomDatabase.sharedInstance.realm
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateID) else {
                ELOG("ProvenanceApp: No save state found for id: \(saveStateID)")
                break
            }
            let frozen = saveState.freeze()
            appState.emulationUIState.currentGame = frozen.game?.freeze()
            appState.emulationUIState.currentSaveState = frozen
            appState.emulationUIState.currentCore = frozen.core?.freeze()
            #if os(iOS)
            if #available(iOS 14.0, *), let game = frozen.game {
                appDelegate.donateMediaIntent(for: game)
            }
            #endif
        case .openFile(let url):
            ILOG("ProvenanceApp: Opening file '\(url.lastPathComponent)' - emulator scene will handle import")
        case .none:
            break
        }
        // Reset the action to avoid processing it multiple times
        appState.appOpenAction = .none
    }

    // Helper method to open the emulator scene if needed based on app open action
    private func openEmulatorSceneIfNeeded() {
        // If a game is already set, open the emulator scene
        if let game = appState.emulationUIState.currentGame {
            ILOG("Opening emulator scene for game already set: \(game.title)")
            sceneCoordinator.openEmulatorScene()
            return
        }

        // Otherwise check if appOpenAction requires emulator scene
        if appState.appOpenAction.requiresEmulatorScene {
            ILOG("Opening emulator scene for action: \(appState.appOpenAction)")
            // First prepare the game (fetch from database if needed)
            prepareGameForEmulatorScene()
            // Now open the emulator scene
            sceneCoordinator.openEmulatorScene()
        }
    }

    // Safe method to open emulator scene only when bootup is complete
    private func openEmulatorSceneWhenReady() {
        // Check if bootup is already complete
        if case .completed = appState.bootupStateManager.currentState {
            ILOG("Bootup already complete, opening emulator scene immediately")
            openEmulatorSceneIfNeeded()
        } else {
            ILOG("Bootup not complete, deferring emulator scene opening until bootup finishes")
            // The scene will be opened when bootup completes via the onReceive handler
        }
    }

    func handle(appURL url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let components = components else {
            ELOG("Failed to parse url <\(url.absoluteString)>")
            return false
        }

        ILOG("App to open url \(url.absoluteString). Parsed components: \(String(describing: components))")

        // Debug log the URL structure in detail
        DLOG("URL scheme: \(components.scheme ?? "nil"), host: \(components.host ?? "nil"), path: \(components.path)")
        if let queryItems: [URLQueryItem] = components.queryItems {
            DLOG("Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")
        } else {
            DLOG("No query items found in URL")
        }

        guard let action = AppURLKeys(rawValue: components.host ?? "") else {
            ELOG("Invalid host/action: \(components.host ?? "nil")")
            return false
        }

        switch action {
        case .screen, .debug:
            // Try NavigationRouter first — handles library-level routes (e.g. search)
            // via registered RouteProviders such as LibraryNavigator.routeProvider.
            if NavigationRouter.shared.handle(url: url) { return true }
            // Fall back to ScreenNavigator for UITest/automation deep links.
            return ScreenNavigator.shared.handle(url: url)

        case .installSkin:
            return handleInstallSkin(url: url, components: components)

        case .save:
            guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                ELOG("Query items is nil")
                return false
            }

            guard let actionValue = queryItems["action"],
                  let saveAction = AppURLKeys.SaveKeys(rawValue: actionValue) else {
                ELOG("Invalid save action: \(queryItems["action"] ?? "nil")")
                return false
            }

            guard let game = resolveGameForSaveAction(queryItems: queryItems) else {
                ELOG("Failed to resolve game for save action")
                return false
            }

            guard let saveState = resolveSaveState(for: game, action: saveAction) else {
                ELOG("No matching save state found for action \(saveAction.rawValue) and game \(game.title)")
                return false
            }

            ILOG("Open save by action \(saveAction.rawValue) for game \(game.title)")
            AppState.shared.appOpenAction = .openSaveStateID(saveState.id)
            return true
        case .open:
            guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                ELOG("No query items found for open action")
                return false
            }

            DLOG("Processing open action with \(queryItems.count) query items")

            // Check for save state id parameter (provenance://open?saveStateId=...)
            if let saveStateId = queryItems.first(where: { $0.name == AppURLKeys.OpenKeys.saveStateId.rawValue })?.value,
               !saveStateId.isEmpty {
                ILOG("Opening save state by id: \(saveStateId)")
                AppState.shared.appOpenAction = .openSaveStateID(saveStateId)
                return true
            }

            // Check for direct md5 parameter (provenance://open?md5=...)
            if let md5Value = queryItems.first(where: { $0.name == AppURLKeys.OpenKeys.md5.rawValue })?.value, !md5Value.isEmpty {
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

        case .netplay:
            guard components.path == "/join" else {
                ELOG("netplay: unrecognised path '\(components.path)' in \(url.absoluteString)")
                return false
            }
            guard let hostValue = components.queryItems?.first(where: { $0.name == AppURLKeys.NetplayJoinKeys.host.rawValue })?.value,
                  !hostValue.isEmpty else {
                ELOG("netplay/join: missing required 'host' parameter in \(url.absoluteString)")
                return false
            }
            NotificationCenter.default.post(
                name: .netplayJoinRequest,
                object: nil,
                userInfo: components.queryItems?.reduce(into: [String: Any]()) { dict, item in
                    if let value = item.value { dict[item.name] = value }
                }
            )
            return true
        }
    }

    func handle(fileURL url: URL) {
        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()

        // Check if this is a skin file (.deltaskin or .manicskin)
        if fileExtension == "deltaskin" || fileExtension == "manicskin" {
            ILOG("ProvenanceApp: Handling skin file: \(filename)")
            Task {
                do {
                    // Import the skin using DeltaSkinManager
                    try await DeltaSkinManager.shared.importSkin(from: url)
                    ILOG("ProvenanceApp: Successfully imported skin: \(filename)")

                    // Reload skins to update the UI
                    await DeltaSkinManager.shared.reloadSkins()

                    await MainActor.run {
                        AppState.shared.presentExternalImportAcknowledgement(.skinImported(fileName: filename))
                    }
                } catch {
                    ELOG("ProvenanceApp: Failed to import skin \(filename): \(error.localizedDescription)")
                }
            }
            return
        }

        // Handle ROM files as before
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

            let copiedDestination = destinationPath
            let copiedFilename = filename
            Task { @MainActor in
                AppState.shared.presentExternalImportAcknowledgement(.fileCopiedToImports(fileName: copiedFilename))
                AppState.shared.appOpenAction = .openFile(copiedDestination)
                self.openEmulatorSceneIfNeeded()
            }
        } catch {
            ELOG("Unable to move file from \(url.path) to \(destinationPath.path) because \(error.localizedDescription)")
            return
        }

        return
    }

    /// Handle the `provenance://install-skin?url=<encoded-url>` deep link.
    ///
    /// Downloads the skin file at the given URL to a temporary location,
    /// then passes it to `DeltaSkinManager.importSkin(from:)`.
    /// A notification is posted on success or failure.
    private func handleInstallSkin(url deepLink: URL, components: URLComponents) -> Bool {
        guard let skinURLString = components.queryItems?.first(where: {
            $0.name == AppURLKeys.InstallSkinKeys.url.rawValue
        })?.value,
              !skinURLString.isEmpty,
              let skinURL = URL(string: skinURLString) else {
            ELOG("install-skin: missing or invalid 'url' query parameter in \(deepLink.absoluteString)")
            return false
        }

        ILOG("install-skin: downloading skin from \(skinURL.absoluteString)")

        Task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: skinURL)
                defer { try? FileManager.default.removeItem(at: tempURL) }

                let filename = skinURL.lastPathComponent
                let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                defer { try? FileManager.default.removeItem(at: destURL) }

                try await DeltaSkinManager.shared.importSkin(from: destURL)
                ILOG("install-skin: successfully installed '\(filename)'")

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .skinInstallDidSucceed,
                        object: nil,
                        userInfo: ["skinName": filename]
                    )
                }
            } catch {
                ELOG("install-skin: failed to install skin from \(skinURL.absoluteString): \(error.localizedDescription)")
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .skinInstallDidFail,
                        object: nil,
                        userInfo: ["error": error.localizedDescription]
                    )
                }
            }
        }

        return true
    }

    /// Helper method to safely fetch a game from Realm by its MD5 hash
    /// - Parameter md5: The MD5 hash of the game
    /// - Returns: The game if found, nil otherwise
    private func fetchGame(byMD5 md5: String) -> PVGame? {
        // Ensure database is ready before accessing
        guard case .completed = appState.bootupStateManager.currentState else {
            WLOG("Attempted to fetch game by MD5 \(md5) before database was ready")
            return nil
        }

        return RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: md5)
    }

    /// Helper method to safely fetch a system from Realm by its identifier
    /// - Parameter identifier: The system identifier
    /// - Returns: The system if found, nil otherwise
    private func fetchSystem(byIdentifier identifier: String) -> PVSystem? {
        // Ensure database is ready before accessing
        guard case .completed = appState.bootupStateManager.currentState else {
            WLOG("Attempted to fetch system by identifier \(identifier) before database was ready")
            return nil
        }

        return RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: identifier)
    }

    /// Resolves the target game for a save-action deep link using the same lookup rules as `open`.
    private func resolveGameForSaveAction(queryItems: [URLQueryItem]) -> PVGame? {
        if let md5Value = queryItems.first(where: { $0.name == AppURLKeys.OpenKeys.md5.rawValue })?.value,
           !md5Value.isEmpty,
           let matchedGame = fetchGame(byMD5: md5Value) {
            return matchedGame
        }

        let md5QueryItem = queryItems[AppURLKeys.OpenKeys.md5Key.rawValue]
        let systemItem = queryItems[AppURLKeys.OpenKeys.system.rawValue]
        let nameItem = queryItems[AppURLKeys.OpenKeys.title.rawValue]

        if let value = md5QueryItem, !value.isEmpty,
           let matchedGame = fetchGame(byMD5: value) {
            return matchedGame
        }

        if let gameName = nameItem, !gameName.isEmpty {
            if let value = systemItem, !value.isEmpty,
               let matchedSystem = fetchSystem(byIdentifier: value) {
                return RomDatabase.sharedInstance
                    .all(PVGame.self)
                    .filter("systemIdentifier == %@ AND title == %@", matchedSystem.identifier, gameName)
                    .first
            }

            return RomDatabase.sharedInstance
                .all(PVGame.self, where: #keyPath(PVGame.title), value: gameName)
                .first
        }

        return nil
    }

    /// Resolves the latest save state matching the requested save-action semantics.
    private func resolveSaveState(for game: PVGame, action: AppURLKeys.SaveKeys) -> PVSaveState? {
        switch action {
        case .lastQuickSave:
            return game.newestAutoSave
        case .lastManualSave:
            return game.saveStates
                .filter("isAutosave == false")
                .sorted(byKeyPath: "date", ascending: false)
                .first
        case .lastAnySave:
            return game.saveStates
                .sorted(byKeyPath: "date", ascending: false)
                .first
        }
    }
}

extension ProvenanceApp {
    func _initICloud() {
        // Check for files stuck in iCloud Drive at startup
        #if !os(tvOS)
        Task.detached {
            await iCloudDriveSync.checkForStuckFilesInICloudDrive()
        }
        #endif

        // Initialize CloudKit for all platforms
        appDelegate.initializeCloudKit()

        // Keep the legacy iCloud document sync code in place but don't use it by default
        // We can uncomment this if we need to revert back to the old sync method
        #if !os(tvOS)
        iCloudDriveSync.initICloudDocuments()
        #endif
    }
}

import CoreSpotlight
extension ProvenanceApp {
    /// Force a reindexing of all Spotlight items
    func forceSpotlightReindexing() {
//        ILOG("Forcing Spotlight reindexing")
//
//        // Register a new background task if needed
//        if spotlightBackgroundTaskIdentifier == .invalid {
//            registerSpotlightBackgroundTask()
//        }
//
//        Task {
//            do {
//                // First delete existing items to ensure a clean slate
//                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
//                    CSSearchableIndex.default().deleteAllSearchableItems { error in
//                        if let error = error {
//                            continuation.resume(throwing: error)
//                        } else {
//                            continuation.resume(returning: ())
//                        }
//                    }
//                }
//
//                ILOG("Successfully deleted all searchable items")
//
//                // Get the extension identifier
//                guard let extensionIdentifier = Bundle.main.bundleIdentifier.map({ $0 + ".Spotlight" }) else {
//                    WLOG("Could not determine Spotlight extension identifier")
//                    return
//                }
//
//                // After deleting all items, we let the Spotlight extension handle reindexing
//                // This occurs automatically when the user searches in Spotlight
//                // For a more proactive approach, we can manually index a few key items
//
//                // Get some games to trigger the indexing
//                let database = RomDatabase.sharedInstance
//                let games = database.all(PVGame.self).prefix(5) // Get first 5 games to create searchable items
//
//                if !games.isEmpty {
//                    // Create searchable items from games
//                    let items = games.compactMap { game -> CSSearchableItem? in
//                        // Make sure the game has a valid MD5 hash
//                        guard !game.md5Hash.isEmpty else { return nil }
//
//                        // Create a searchable item with the game's spotlight content
//                        return CSSearchableItem(
//                            uniqueIdentifier: game.spotlightUniqueIdentifier,
//                            domainIdentifier: "org.provenance-emu.games",
//                            attributeSet: game.spotlightContentSet
//                        )
//                    }
//
//                    if !items.isEmpty {
//                        // Index these items to trigger the extension
//                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
//                            CSSearchableIndex.default().indexSearchableItems(items) { error in
//                                if let error = error {
//                                    continuation.resume(throwing: error)
//                                } else {
//                                    continuation.resume(returning: ())
//                                }
//                            }
//                        }
//
//                        ILOG("Successfully indexed \(items.count) sample items to trigger the extension")
//                    } else {
//                        WLOG("No valid searchable items could be created from games")
//                    }
//                } else {
//                    WLOG("No games found to create sample searchable items")
//                }
//
//                ILOG("Spotlight reindexing process completed. Extension \(extensionIdentifier) will handle full reindexing when needed.")
//
//                // End the background task if it's valid
//                if spotlightBackgroundTaskIdentifier != .invalid {
//                    ILOG("Ending Spotlight indexing background task: \(spotlightBackgroundTaskIdentifier)")
//                    UIApplication.shared.endBackgroundTask(spotlightBackgroundTaskIdentifier)
//                    spotlightBackgroundTaskIdentifier = .invalid
//                }
//
//            } catch {
//                ELOG("Error during Spotlight reindexing: \(error.localizedDescription)")
//
//                // End the background task even if there was an error
//                if spotlightBackgroundTaskIdentifier != .invalid {
//                    ILOG("Ending Spotlight indexing background task due to error: \(spotlightBackgroundTaskIdentifier)")
//                    UIApplication.shared.endBackgroundTask(spotlightBackgroundTaskIdentifier)
//                    spotlightBackgroundTaskIdentifier = .invalid
//                }
//            }
//        }
    }

    /// Handle an intent user activity (from Siri shortcuts/App Intents)
    func handleIntentUserActivity(_ userActivity: NSUserActivity) {
        ILOG("ProvenanceApp: Handling intent user activity: \(userActivity.activityType)")

        #if os(iOS)
        if #available(iOS 14.0, *) {
            // Delegate to app delegate's intent handler
            if appDelegate.handleIntentUserActivity(userActivity) {
                ILOG("ProvenanceApp: Intent user activity handled successfully")
                // The app delegate sets appOpenAction, so we just need to wait for bootup
                openEmulatorSceneWhenReady()
            } else {
                WLOG("ProvenanceApp: Intent user activity was not handled")
            }
        }
        #endif
    }

    /// Handle a Siri "Search in App" continuation activity (`CSQueryContinuationActionType`).
    /// Extracts the search string and stores it in `AppState.pendingSearchQuery` so that
    /// search-capable views (e.g. HomeView) can pre-populate their search fields.
    func handleSiriSearchActivity(_ userActivity: NSUserActivity) {
        ILOG("ProvenanceApp: handleSiriSearchActivity activityType=\(userActivity.activityType)")
        #if !os(tvOS)
        guard userActivity.activityType == CSQueryContinuationActionType,
              let searchQuery = userActivity.userInfo?[CSSearchQueryString] as? String,
              !searchQuery.isEmpty else {
            WLOG("ProvenanceApp: Siri search activity missing query string")
            return
        }
        ILOG("ProvenanceApp: Setting pendingSearchQuery to: '\(searchQuery)'")
        AppState.shared.pendingSearchQuery = searchQuery
        #endif
    }

    /// Handle a Spotlight search result activation
    func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        ILOG("Handling Spotlight activity: \(userActivity.activityType)")
        #if !os(tvOS)
        // Check if this is a Spotlight search result
        if userActivity.activityType == CSSearchableItemActionType {
            // Get the unique identifier from the activity
            guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
                ELOG("Failed to get unique identifier from Spotlight activity")
                return
            }

            ILOG("Spotlight item selected with identifier: \(uniqueIdentifier)")

            // Check if this is a game identifier (format: org.provenance-emu.game.MD5HASH)
            if uniqueIdentifier.hasPrefix("org.provenance-emu.game.") {
                let md5Hash = uniqueIdentifier.replacingOccurrences(of: "org.provenance-emu.game.", with: "")
                ILOG("Extracted game MD5 hash: \(md5Hash)")

                // Set the app open action to open this game by MD5
                // Use the safe pattern that waits for bootup completion
                AppState.shared.appOpenAction = .openMD5(md5Hash)
                openEmulatorSceneWhenReady()
            }
            // Check if this is a save state identifier
            else if uniqueIdentifier.hasPrefix("org.provenance-emu.savestate.") {
                let saveStateId = uniqueIdentifier.replacingOccurrences(of: "org.provenance-emu.savestate.", with: "")
                ILOG("Save state selected: \(saveStateId)")
                // Use the save state ID directly to open and resume the specific save state
                AppState.shared.appOpenAction = .openSaveStateID(saveStateId)
                openEmulatorSceneWhenReady()
            }
        }
        #endif //!tvOS
    }
}

// What's New!
// Release notes are defined in PVUI/Sources/PVSwiftUI/Resources/whats-new.json.
// To add a new version: edit that JSON file — no Swift code changes needed.
