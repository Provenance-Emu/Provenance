//
//  GameLaunchingViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import RealmSwift

/*
 Protocol with default implimentation.
 
 This allows any UIViewController class to just inherit GameLaunchingViewController, and then it can call load(PVGame)!
 
 */

public protocol GameLaunchingViewController: class {
    var mustRefreshDataSource: Bool {get set}
    func canLoad(_ game: PVGame) throws
    func load(_ game: PVGame)
    func updateRecentGames(_ game: PVGame)
    func register3DTouchShortcuts()
}

public enum GameLaunchingError: Error {
    case systemNotFound
    case generic(String)
    case missingBIOSes([String])
}

extension GameLaunchingViewController where Self : UIViewController {

    private func biosCheck(system: PVSystem) throws {
        guard system.requiresBIOS else {
            // Nothing to do
            return
        }

        // Check if requires a BIOS and has them all - only warns if md5's mismatch
        let biosEntries = system.bioses
        guard !biosEntries.isEmpty  else {
            ELOG("System \(system.name) specifies it requires BIOS files but does not provide values for \(SystemDictionaryKeys.BIOSEntries)")
            throw GameLaunchingError.generic("Invalid configuration for system \(system.name). Missing BIOS dictionary in systems.plist")
        }

        let biosPathContents: [String]
        do {
            biosPathContents = try FileManager.default.contentsOfDirectory(at: system.biosDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).flatMap { $0.isFileURL ? $0.lastPathComponent : nil }
        } catch {
            try? FileManager.default.createDirectory(at: system.biosDirectory, withIntermediateDirectories: true, attributes: nil)
            let biosFiles = biosEntries.map { return $0.expectedFilename }.joined(separator: ", ")

            let documentsPath = PVEmulatorConfiguration.documentsPath.path
            let biosDirectory  = system.biosDirectory.path.replacingOccurrences(of: documentsPath, with: "")

            let message = "This system requires BIOS files. Please upload '\(biosFiles)' to \(biosDirectory)."
            ELOG(message)
            throw GameLaunchingError.generic(message)
        }

        // Store the HASH : FILENAME of the BIOS directory contents
        // Only generated if needed for matching if filename fails
        var biosPathContentsMD5Cache: [String: String]?

        var missingBIOSES = [String]()

        // Go through each BIOSEntry struct and see if all non-optional BIOS's were found in the BIOS dir
        // Try to match MD5s for files that don't match by name, and rename them to what's expected if found
        // Warn on files that have filename match but MD5 doesn't match expected
        let canLoad = biosEntries.all {

            // Check for a direct filename match and that it isn't an optional BIOS if we don't find it
            if !biosPathContents.contains($0.expectedFilename) && !$0.optional {
                // Didn't match by files name, now we generate all the md5's and see if any match, if they do, move the matching file to the correct filename

                // 1 - Lazily generate the hashes of files in the BIOS directory
                if biosPathContentsMD5Cache == nil {
                    biosPathContentsMD5Cache = biosPathContents.reduce([String:String](), { (hashDictionary, filename) -> [String: String] in
                        let fullBIOSFileURL = system.biosDirectory.appendingPathComponent(filename, isDirectory: false)
                        if let hash = FileManager.default.md5ForFile(atPath: fullBIOSFileURL.path, fromOffset: 0), !hash.isEmpty {
                            // Make mutable
                            var hashDictionary = hashDictionary
                            hashDictionary[hash] = filename
                            return hashDictionary
                        } else {
                            // Couldn't hash for whatever reason, just pass on the hash dict
                            return hashDictionary
                        }
                    })
                }

                // 2 - See if any hashes in the BIOS directory match the current BIOS entry we're investigating.
                if let biosPathContentsMD5Cache = biosPathContentsMD5Cache, let filenameOfFoundFile = biosPathContentsMD5Cache[$0.expectedMD5.uppercased()] {
                    // Rename the file to what we expected
                    do {
                        let from = system.biosDirectory.appendingPathComponent(filenameOfFoundFile, isDirectory: false)
                        let to = system.biosDirectory.appendingPathComponent($0.expectedFilename, isDirectory: false)
                        try FileManager.default.moveItem(at: from, to: to)
                        // Succesfully move the file, mark this BIOSEntry as true in the .all{} loop
                        ILOG("Rename file \(filenameOfFoundFile) to \($0.expectedFilename) because it matched by MD5 \($0.expectedMD5)")
                        return true
                    } catch {
                        ELOG("Failed to rename \(filenameOfFoundFile) to \($0.expectedFilename)\n\(error.localizedDescription)")
                        // Since we couldn't rename, mark this as a false
                        missingBIOSES.append($0.expectedFilename)
                        return false
                    }
                } else {
                    // No MD5 matches either
                    missingBIOSES.append($0.expectedFilename)
                    return false
                }
            } else {
                // Not as important, but log if MD5 is mismatched.
                // Cores care about filenames for some reason, not MD5s
                let fileMD5 = FileManager.default.md5ForFile(atPath: system.biosDirectory.appendingPathComponent($0.expectedFilename, isDirectory: false).path, fromOffset: 0) ?? ""
                if fileMD5 != $0.expectedMD5.uppercased() {
                    WLOG("MD5 hash for \($0.expectedFilename) didn't match the expected value.\nGot {\(fileMD5)} expected {\($0.expectedMD5.uppercased())}")
                }
                return true
            }
        } // End canLoad .all loop

        if !canLoad {
            throw GameLaunchingError.missingBIOSes(missingBIOSES)
        }
    }

    func canLoad(_ game: PVGame) throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try biosCheck(system: system)
    }

    private func displayAndLogError(withTitle title: String, message: String) {
        ELOG(message)

        let alertController = UIAlertController(title: "Missing BIOS Files", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true)
    }

    func load(_ game: PVGame) {
        guard !(presentedViewController is PVEmulatorViewController) else {
            let currentGameVC = presentedViewController as! PVEmulatorViewController
            displayAndLogError(withTitle: "Cannot open new game", message: "A game is already running the game \(currentGameVC.game.title).")
            return
        }

        // Pre-flight
        guard let system = game.system else {
            displayAndLogError(withTitle: "Cannot open game", message: "Requested system cannot be found for game '\(game.title)'.")
            return
        }

        do {
            try self.canLoad(game)
            // Init emulator VC

            // TODO: let the user choose the core here
            guard let core = game.system.cores.first else {
                displayAndLogError(withTitle: "Cannot open game", message: "No core gound for game system '\(system.shortName)'.")
                return
            }

            guard let coreInstance = core.createInstance(forSystem: game.system) else {
                displayAndLogError(withTitle: "Cannot open game", message: "Failed to create instance of core '\(core.projectName)'.")
                ELOG("Failed to init core instance")
                return
            }

            let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)

            // Configure emulator VC
            // NOTE: These technically could be derived in PVEmulatorViewController directly
            emulatorViewController.batterySavesPath = PVEmulatorConfiguration.batterySavesPath(forGame: game).path
            emulatorViewController.saveStatePath = PVEmulatorConfiguration.saveStatePath(forGame: game).path
            emulatorViewController.BIOSPath = PVEmulatorConfiguration.biosPath(forGame: game).path

            // Present the emulator VC
            emulatorViewController.modalTransitionStyle = .crossDissolve
            self.present(emulatorViewController, animated: true) {() -> Void in }

            PVControllerManager.shared.iCadeController?.refreshListener()

            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    game.playCount += 1
                    game.lastPlayed = Date()
                }
            } catch {
                ELOG("\(error.localizedDescription)")
            }

            self.updateRecentGames(game)
        } catch GameLaunchingError.missingBIOSes(let missingBIOSes) {
            // Create missing BIOS directory to help user out
            PVEmulatorConfiguration.createBIOSDirectory(forSystemIdentifier: system.enumValue)

            let missingFilesString = missingBIOSes.joined(separator: ", ")
            let relativeBiosPath = "Documents/BIOS/\(system.identifier)/"

            let message = "\(system.shortName) requires BIOS files to run games. Ensure the following files are inside \(relativeBiosPath)\n\(missingFilesString)"
            displayAndLogError(withTitle: "Missing BIOS files", message: message)
        } catch GameLaunchingError.systemNotFound {
            displayAndLogError(withTitle: "Core not found", message: "No Core was found to run system '\(system.name)'.")
        } catch GameLaunchingError.generic(let message) {
            displayAndLogError(withTitle: "Cannot open game", message: message)
        } catch {
            displayAndLogError(withTitle: "Cannot open game", message: "Unknown error: \(error.localizedDescription)")
        }
    }

    func doLoad(_ game: PVGame) throws {
        guard let system = game.system else {
            throw GameLaunchingError.systemNotFound
        }

        try biosCheck(system: system)
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        database.refresh()

        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)

        let recentsMatchingGame =  database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        let recentToDelete = recentsMatchingGame.first
        if let recentToDelete = recentToDelete {
            do {
                try database.delete(recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }

        if recents.count >= PVMaxRecentsCount() {
            // TODO: This should delete more than just the last incase we had an overflow earlier
            if let oldestRecent: PVRecentGame = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                do {
                    try database.delete(oldestRecent)
                } catch {
                    ELOG("Failed to delete recent: \(error.localizedDescription)")
                }
            }
        }

        if let currentRecent = game.recentPlays.first {
            do {
                currentRecent.lastPlayedDate = Date()
                try database.add(currentRecent, update: true)
            } catch {
                ELOG("Failed to update Recent Game entry. \(error.localizedDescription)")
            }
        } else {
            let newRecent = PVRecentGame(withGame: game)
            do {
                try database.add(newRecent, update: false)

                let activity = game.spotlightActivity
                // Make active, causes it to index also
                self.userActivity = activity
            } catch {
                ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
            }
        }

        register3DTouchShortcuts()
    }

    func register3DTouchShortcuts() {
        if #available(iOS 9.0, *) {
            #if os(iOS)
                // Add 3D touch shortcuts to recent games
                var shortcuts = [UIApplicationShortcutItem]()

                let database = RomDatabase.sharedInstance

                let favorites = database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true)
                for game in favorites {
                    let icon: UIApplicationShortcutIcon?
                    if #available(iOS 9.1, *) {
                        icon  = UIApplicationShortcutIcon(type: .favorite)
                    } else {
                        icon = UIApplicationShortcutIcon(type: .play)
                    }

                    let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
                    shortcuts.append(shortcut)
                }

                let sortedRecents: Results<PVRecentGame> = database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)

                for recentGame in sortedRecents {
                    if let game = recentGame.game {

                        let icon: UIApplicationShortcutIcon?
                        icon = UIApplicationShortcutIcon(type: .play)

                        let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
                        shortcuts.append(shortcut)
                    }
                }

                UIApplication.shared.shortcutItems = shortcuts
            #endif
        } else {
            // Fallback on earlier versions
        }
    }
}

// TODO: Move me
extension Sequence {
    func any(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        return try self.contains(where: { try predicate($0) == true })
    }

    func all(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let containsFailed = try self.contains(where: { try predicate($0) == false })
        return !containsFailed
    }

    func none(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        let result = try self.any(predicate)
        return !result
    }

    func count(_ predicate: (Element) throws -> Bool) rethrows -> Int {
        return try self.reduce(0, { (result, element) in
            return result + (try predicate(element) ? 1 : 0)
        })
    }
}
