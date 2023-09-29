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
#if !targetEnvironment(macCatalyst) && !os(macOS) // && canImport(SteamController)
import SteamController
import UIKit
#endif

public enum AppURLKeys: String, Codable {
    case open
    case save

    public enum OpenKeys: String, Codable {
        case md5Key = "PVGameMD5Key"
        case system
        case title
    }
    public enum SaveKeys: String, Codable {
        case lastQuickSave
        case lastAnySave
        case lastManualSave
    }
}

extension Array<URLQueryItem> {
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

extension PVAppDelegate {
    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        #if os(tvOS)
        importFile(atURL: url)
        return true
        #else
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.isFileURL {
            let filename = url.lastPathComponent
            let destinationPath = PVEmulatorConfiguration.Paths.romsImportPath.appendingPathComponent(filename, isDirectory: false)

            do {
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                // Doesn't seem we need access in dev builds?
                _ = url.startAccessingSecurityScopedResource()

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
        } else if let scheme = url.scheme, scheme.lowercased() == PVAppURLKey {
            guard let components = components else {
                ELOG("Failed to parse url <\(url.absoluteString)>")
                return false
            }

            let sendingAppID = options[.sourceApplication]
            ILOG("App with id <\(sendingAppID ?? "nil")> requested to open url \(url.absoluteString)")

            guard let action = AppURLKeys(rawValue: components.host ?? "") else {
                ELOG("Invalid host/action: \(components.host ?? "nil")")
                return false
            }

            switch action {
            case .save:
                guard let queryItems = components.queryItems, !queryItems.isEmpty else {
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
                    return false
                }

                let md5QueryItem = queryItems["PVGameMD5Key"]
                let systemItem = queryItems["system"]
                let nameItem = queryItems["title"]

                if let value = md5QueryItem, !value.isEmpty,
                   let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: value)) as PVGame??) {
                    // Match by md5
                    ILOG("Open by md5 \(value)")
                    shortcutItemGame = matchedGame
                    return true
                } else if let gameName = nameItem, !gameName.isEmpty {
                    if let value = systemItem {
                        // MAtch by name and system
                        if !value.isEmpty,
                           let systemMaybe = ((try? Realm().object(ofType: PVSystem.self, forPrimaryKey: value)) as PVSystem??),
                           let matchedSystem = systemMaybe {
                            if let matchedGame = RomDatabase.sharedInstance.all(PVGame.self).filter("systemIdentifier == %@ AND title == %@", matchedSystem.identifier, gameName).first {
                                ILOG("Open by system \(value), name: \(gameName)")
                                shortcutItemGame = matchedGame
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
                            shortcutItemGame = matchedGame
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
        } else if
            let components = components,
                components.path == PVGameControllerKey,
                let first = components.queryItems?.first,
                first.name == PVGameMD5Key,
                let md5Value = first.value,
                let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
            shortcutItemGame = matchedGame
            return true
        }

        return false
        #endif
    }

    #if os(iOS) || os(macOS)
        func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
            if shortcutItem.type == "kRecentGameShortcut",
                let md5Value = shortcutItem.userInfo?["PVGameHash"] as? String,
                let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                shortcutItemGame = matchedGame
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    #endif

    func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Spotlight search click-through
        #if os(iOS) || os(macOS)
            if userActivity.activityType == CSSearchableItemActionType {
                if let md5 = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                    let md5Value = md5.components(separatedBy: ".").last,
                    let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                    // Comes in a format of "com....md5"
                    shortcutItemGame = matchedGame
                    return true
                } else {
                    WLOG("Spotlight activity didn't contain the MD5 I was looking for")
                }
            }
        #endif

        return false
    }

}

#if os(iOS) || os(macOS)
@available(iOS 9.0, macOS 11.0, macCatalyst 11.0, *)
extension PVGame {
    func asShortcut(isFavorite: Bool) -> UIApplicationShortcutItem {
        let icon: UIApplicationShortcutIcon = isFavorite ? .init(type: .favorite) : .init(type: .play)
        return UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: systemIdentifier), icon: icon, userInfo: ["PVGameHash": md5Hash as NSSecureCoding])
    }
}
#endif
