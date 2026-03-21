//
//  PVAppDelegate+Open.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import PVLogging
import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift
import RxSwift
import PVRealm
import PVFileSystem
import PVUIBase

#if !targetEnvironment(macCatalyst) && !os(macOS) && canImport(SteamController)
import SteamController
import UIKit
#endif

public extension Array<URLQueryItem> {
    subscript(key: String) -> String? {
        get {
            return first(where: {$0.name == key})?.value
        }
        set(newValue) {

            if let newValue = newValue {
                removeAll(where: {$0.name == key})
                let newItem = URLQueryItem(name: key, value: newValue)
                append(newItem)
            } else {
                removeAll(where: {$0.name == key})
            }
        }
    }
}

public extension PVAppDelegate {
    /// Helper method to safely fetch a game from Realm by its MD5 hash
    /// - Parameter md5: The MD5 hash of the game
    /// - Returns: The game if found, nil otherwise
    @MainActor
    internal func fetchGame(byMD5 md5: String) -> PVGame? {
        let realm = RomDatabase.sharedInstance.realm
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())
    }

    /// Helper method to safely fetch a system from Realm by its identifier
    /// - Parameter identifier: The system identifier
    /// - Returns: The system if found, nil otherwise
    @MainActor
    private func fetchSystem(byIdentifier identifier: String) -> PVSystem? {
        let realm = RomDatabase.sharedInstance.realm
        return realm.object(ofType: PVSystem.self, forPrimaryKey: identifier)
    }

    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        ILOG("PVAppDelegate: application open url: \(url.description), options: \(options.description)")

        #if !os(tvOS) && canImport(SiriusRating)
        if isAppStore {
            appRatingSignifigantEvent()
        }
        #endif
#if os(tvOS)
        // On tvOS, check if this is an app URL scheme first (e.g., from TopShelf)
        if let scheme = url.scheme, scheme.lowercased() == PVAppURLKey {
            return handle(appURL: url, options: options)
        }
        // Otherwise treat as file import
        importFile(atURL: url)
        return true
#else
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.isFileURL {
            return handle(fileURL: url, options: options)
        }
        else if let scheme = url.scheme, scheme.lowercased() == PVAppURLKey {
            return handle(appURL: url, options: options)
        } else if let components = components,
                  components.path == PVGameControllerKey,
                  let first = components.queryItems?.first,
                  first.name == PVGameMD5Key,
                  let md5Value = first.value,
                  let matchedGame = fetchGame(byMD5: md5Value) {
            AppState.shared.appOpenAction = .openGame(matchedGame)
            return true
        }

        return false
#endif
    }

#if os(iOS) || os(macOS)
    /// Legacy fallback: called only when there is NO active scene session (e.g. non-scene builds).
    /// In practice, PVSceneDelegate handles shortcut taps for all normal runs.
    public func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        ILOG("PVAppDelegate: performActionFor shortcut (legacy path) type=\(shortcutItem.type)")
        Task { @MainActor in
            HomeScreenShortcutService.shared.handleShortcutTap(shortcutItem)
        }
        completionHandler(true)
    }
#endif

    public func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        defer {
            #if !os(tvOS)
            if isAppStore {
                appRatingSignifigantEvent()
            }
            #endif
        }

        ILOG("PVAppDelegate: Continuing user activity: \(userActivity.activityType)")

        // Check if this is an intent-based user activity
        #if os(iOS)
        if #available(iOS 14.0, *) {
            if handleIntentUserActivity(userActivity) {
                return true
            }
        }
        #endif
        // Siri "Search in App" — CSQueryContinuationActionType carries the search string
#if os(iOS) || os(macOS)
        if userActivity.activityType == CSQueryContinuationActionType {
            if let searchQuery = userActivity.userInfo?[CSSearchQueryString] as? String, !searchQuery.isEmpty {
                ILOG("PVAppDelegate: Setting pendingSearchQuery from Siri handoff: '\(searchQuery)'")
                AppState.shared.pendingSearchQuery = searchQuery
                return true
            }
        }
#endif

        // Spotlight search click-through
#if os(iOS) || os(macOS)
        if userActivity.activityType == CSSearchableItemActionType {
            if let md5 = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let md5Value = md5.components(separatedBy: ".").last,
               let matchedGame = fetchGame(byMD5: md5Value) {
                    // Comes in a format of "com....md5"
                    AppState.shared.appOpenAction = .openGame(matchedGame)
                    return true
            } else {
                WLOG("Spotlight activity didn't contain the MD5 I was looking for")
            }
        }
#endif

        return false
    }
}

extension PVAppDelegate {
    public func handle(fileURL url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        ILOG("PVAppDelegate: handle fileURL url: \(url.description), options: \(options.description)")

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

            if let openInPlace = options[.openInPlace] as? Bool, openInPlace {
                try FileManager.default.copyItem(at: url, to: destinationPath)
            } else {
                try FileManager.default.moveItem(at: url, to: destinationPath)
            }
        } catch {
            ELOG("Unable to move file from \(url.path) to \(destinationPath.path) because \(error.localizedDescription)")
            return false
        }

        return true
    }

    public func handle(appURL url: URL,  options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        ILOG("PVAppDelegate: handle appURL url: \(url.description), options: \(options.description)")

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let components = components else {
            ELOG("Failed to parse url <\(url.absoluteString)>")
            return false
        }

        let sendingAppID = options[.sourceApplication]
        ILOG("App with id <\(sendingAppID ?? "nil")> requested to open url \(url.absoluteString)")

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
        case .netplay:
            guard let queryItems = components.queryItems,
                  let host = queryItems.first(where: { $0.name == AppURLKeys.NetplayJoinKeys.host.rawValue })?.value,
                  !host.isEmpty else {
                ELOG("netplay/join: missing required 'host' parameter in \(url.absoluteString)")
                return false
            }
            let portStr = queryItems.first(where: { $0.name == AppURLKeys.NetplayJoinKeys.port.rawValue })?.value ?? "55435"
            let port = UInt16(portStr) ?? 55435
            let relay = queryItems.first(where: { $0.name == AppURLKeys.NetplayJoinKeys.relay.rawValue })?.value
            let game = queryItems.first(where: { $0.name == AppURLKeys.NetplayJoinKeys.game.rawValue })?.value
            ILOG("netplay/join: host=\(host) port=\(port) relay=\(relay ?? "none")")
            var userInfo: [String: Any] = ["host": host, "port": port]
            if let relay { userInfo["relay"] = relay }
            if let game { userInfo["game"] = game }
            NotificationCenter.default.post(name: .netplayJoinRequest, object: nil, userInfo: userInfo)
            return true

        case .screen, .debug:
            return ScreenNavigator.shared.handle(url: url)

        case .installSkin:
            return handleInstallSkin(url: url, components: components)

        case .save:
            guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                ELOG("No query items found for save action")
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
                    // Set the MD5 action in case the game is found later
                    AppState.shared.appOpenAction = .openMD5(md5Value)
                    return true
                }
            }

            // Check for game name parameter (provenance://open?title=...)
            if let gameName = queryItems.first(where: { $0.name == "title" })?.value, !gameName.isEmpty {
                DLOG("Found game name parameter: \(gameName)")

                // Check if we also have a system parameter for more specific search
                let systemName = queryItems.first(where: { $0.name == "system" })?.value

                if let systemName = systemName, !systemName.isEmpty {
                    DLOG("Also found system parameter: \(systemName)")
                    return handleOpenByGameAndSystem(gameName: gameName, systemName: systemName)
                } else {
                    return handleOpenByGameName(gameName)
                }
            }

            // Fall back to the original parameter names if direct parameters not found
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

    /// Handle opening a game by name using fuzzy search
    /// - Parameter gameName: The name of the game to search for
    /// - Returns: True if a game was found and set to open, false otherwise
    @MainActor
    private func handleOpenByGameName(_ gameName: String) -> Bool {
        ILOG("PVAppDelegate: handleOpenByGameName: \(gameName)")

        let realm = RomDatabase.sharedInstance.realm

        // First try an exact match
        if let exactMatch = realm.objects(PVGame.self).filter("title == %@", gameName).first {
            ILOG("Found exact match for game name: \(gameName)")
            AppState.shared.appOpenAction = .openGame(exactMatch)
            return true
        }

        // If no exact match, try a case-insensitive contains search
        let fuzzyMatches = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", gameName)

        if let bestMatch = fuzzyMatches.first {
            ILOG("Found fuzzy match '\(bestMatch.title)' for game name: \(gameName)")
            AppState.shared.appOpenAction = .openGame(bestMatch)
            return true
        }

        // No matches found
        WLOG("No games found matching name: \(gameName)")
        return false
    }

    /// Handle opening a game by name and system using fuzzy search
    /// - Parameters:
    ///   - gameName: The name of the game to search for
    ///   - systemName: The name of the system to search for
    /// - Returns: True if a game was found and set to open, false otherwise
    @MainActor
    private func handleOpenByGameAndSystem(gameName: String, systemName: String) -> Bool {
        ILOG("PVAppDelegate: handleOpenByGameAndSystem: \(gameName), systemName: \(systemName)")

        let realm = RomDatabase.sharedInstance.realm

        // First find matching systems
        let systemMatches = realm.objects(PVSystem.self).filter("name CONTAINS[c] %@ OR shortName CONTAINS[c] %@", systemName, systemName)

        if systemMatches.isEmpty {
            WLOG("No systems found matching: \(systemName)")
            // Fall back to just game name search
            return handleOpenByGameName(gameName)
        }

        // Get system identifiers
        let systemIdentifiers = systemMatches.map { $0.identifier }

        // Try to find a game that matches both the name and one of the systems
        var bestMatch: PVGame? = nil

        // First try exact match on title with any matching system
        for systemId in systemIdentifiers {
            if let match = realm.objects(PVGame.self)
                .filter("title == %@ AND systemIdentifier == %@", gameName, systemId)
                .first {
                bestMatch = match
                break
            }
        }

        // If no exact match, try fuzzy match on title with any matching system
        if bestMatch == nil {
            for systemId in systemIdentifiers {
                if let match = realm.objects(PVGame.self)
                    .filter("title CONTAINS[c] %@ AND systemIdentifier == %@", gameName, systemId)
                    .first {
                    bestMatch = match
                    break
                }
            }
        }

        if let game = bestMatch {
            ILOG("Found game '\(game.title)' on system '\(game.systemIdentifier)'")
            AppState.shared.appOpenAction = .openGame(game)
            return true
        }

        // No matches found with system, fall back to just game name
        WLOG("No games found matching name: \(gameName) on system: \(systemName)")
        return handleOpenByGameName(gameName)
    }

    /// Resolves the target game for a save-action deep link using the same lookup rules as `open`.
    @MainActor
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
    @MainActor
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

    /// Handle the `provenance://install-skin?url=<encoded-url>` deep link.
    ///
    /// Downloads the skin file at the given URL to a temporary location,
    /// then passes it to `DeltaSkinManager.importSkin(from:)`.
    /// A banner notification is shown on success or failure.
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
                // Download skin to a temporary file
                let (tempURL, _) = try await URLSession.shared.download(from: skinURL)
                defer { try? FileManager.default.removeItem(at: tempURL) }

                // Derive a sensible filename from the source URL
                let filename = skinURL.lastPathComponent
                let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                defer { try? FileManager.default.removeItem(at: destURL) }

                // Import via DeltaSkinManager
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
}
