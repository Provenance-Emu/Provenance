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

protocol GameLaunchingViewController : class {
    typealias BiosDictionary = [String: String]
    var isMustRefreshDataSource : Bool {get set}
    
    func createBiosDirectory(atPath biosPath: String)
    func canLoad(_ game: PVGame) -> Bool
    func load(_ game: PVGame)
    func updateRecentGames(_ game: PVGame)
    func register3DTouchShortcuts()
}

extension GameLaunchingViewController where Self : UIViewController {
    func createBiosDirectory(atPath biosPath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: biosPath) {
            do {
                try fm.createDirectory(atPath: biosPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating BIOS dir: \(error.localizedDescription)")
            }
        }
    }
    
    // TODO: This should be a throw not a bool
    // with error message containting the message text
    // instead of using the handleError function
    func canLoad(_ game: PVGame) -> Bool {
        let config = PVEmulatorConfiguration.sharedInstance()
        
        guard let system = config.system(forIdentifier: game.systemIdentifier) else {
            ELOG("No system for id \(game.systemIdentifier)")
            return false
        }
        
        // Error handler
        let handleError : (String?)->Void = { [unowned self] errorMessage in
            // Create missing BIOS directory to help user out
            let biosPath: String = config.biosPath(forSystemID: game.systemIdentifier)
            self.createBiosDirectory(atPath: biosPath)
            
            let biosNames = system[PVBIOSNamesKey] as? [BiosDictionary] ?? [BiosDictionary]()
            
            var biosString = ""
            for bios: BiosDictionary in biosNames {
                let name = bios["Name"]
                biosString += "\(String(describing: name))"
                if biosNames.last! != bios {
                    biosString += """
                    ,
                    
                    """
                }
            }
            
            var message : String
            if let errorMessage = errorMessage {
                message = errorMessage
            } else {
                message = """
                \(String(describing: system[PVShortSystemNameKey])) requires BIOS files to run games. Ensure the following files are inside Documents/BIOS/\(String(describing: system[PVSystemIdentifierKey]))/
                
                \(biosString)
                """
            }
            
            let alertController = UIAlertController(title: "Missing BIOS Files", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true)
        }
        
        
        if let requiresBIOS = system[PVRequiresBIOSKey] as? Bool, requiresBIOS == true {
            
            guard  let biosNames = system[PVBIOSNamesKey] as? [BiosDictionary] else {
                ELOG("System \(game.systemIdentifier) specifies it requires BIOS files but does not provide values for \(PVBIOSNamesKey)")
                handleError("Invalid configuration for system \(game.systemIdentifier)")
                return false
            }
            
            let biosPath: String = config.biosPath(forSystemID: game.systemIdentifier)
            
            var contents : [String]!
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: biosPath)
            } catch {
                ELOG("Unable to get contents of \(biosPath) because \(error.localizedDescription)")
                handleError(nil)
                return false
            }
            
            for bios: BiosDictionary in biosNames {
                if let name = bios["name"], !contents.contains(name)  {
                    ELOG("Missing bios of name \(String(describing: name))")
                    handleError(nil)
                    return false
                }
            }
        }
        
        return true
    }
    
    // TODO: Make this throw
    func load(_ game: PVGame) {
        if !(presentedViewController is PVEmulatorViewController) {
            let config = PVEmulatorConfiguration.sharedInstance()
            if self.canLoad(game) {
                let emulatorViewController = PVEmulatorViewController(game: game)!
                emulatorViewController.batterySavesPath = config.batterySavesPath(forROM: URL(fileURLWithPath: config.romsPath).appendingPathComponent(game.romPath).path)
                emulatorViewController.saveStatePath = config.saveStatePath(forROM: URL(fileURLWithPath: config.romsPath).appendingPathComponent(game.romPath).path)
                emulatorViewController.biosPath = config.biosPath(forSystemID: game.systemIdentifier)
                emulatorViewController.systemID = game.systemIdentifier
                emulatorViewController.modalTransitionStyle = .crossDissolve
                self.present(emulatorViewController, animated: true) {() -> Void in }
                PVControllerManager.shared().iCadeController?.refreshListener()
                self.updateRecentGames(game)
            } else {
                ELOG("Cannot load game")
            }
        }
    }
    
    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.temporaryDatabaseContext()
        database.refresh()
        
        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)
        
        let recentsMatchingGame =  database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        let recentToDelete = recentsMatchingGame.first
        if let recentToDelete = recentToDelete {
            do {
                try database.delete(object: recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }
        
        if recents.count >= PVMaxRecentsCount() {
            // TODO: This should delete more than just the last incase we had an overflow earlier
            if let oldestRecent: PVRecentGame = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                do {
                    try database.delete(object: oldestRecent)
                } catch {
                    ELOG("Failed to delete recent: \(error.localizedDescription)")
                }
            }
        }
        
        let newRecent = PVRecentGame(withGame: game)
        do {
            try database.add(object: newRecent, update:false)
            
            let activity = game.spotlightActivity
            // Make active, causes it to index also
            self.userActivity = activity
        } catch {
            ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
        }
        register3DTouchShortcuts()
        isMustRefreshDataSource = true
    }
    
    func register3DTouchShortcuts() {
        // TODO: Maybe should add favorite games first, then recent games?
        
        if #available(iOS 9.0, *) {
            #if os(iOS)
                // Add 3D touch shortcuts to recent games
                var shortcuts = [UIApplicationShortcutItem]()
                
                let database = RomDatabase.temporaryDatabaseContext()
                
                let favorites = database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true)
                for game in favorites {
                    let icon : UIApplicationShortcutIcon?
                    if #available(iOS 9.1, *) {
                        icon  = UIApplicationShortcutIcon(type: .favorite)
                    } else {
                        icon = UIApplicationShortcutIcon(type: .play)
                    }
                    
                    let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.sharedInstance().name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
                    shortcuts.append(shortcut)
                }
                
                
                let sortedRecents: Results<PVRecentGame> = database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
                
                for recentGame in sortedRecents {
                    if let game = recentGame.game {
                        
                        let icon : UIApplicationShortcutIcon?
                        icon = UIApplicationShortcutIcon(type: .play)
                        
                        let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.sharedInstance().name(forSystemIdentifier: game.systemIdentifier), icon: icon, userInfo: ["PVGameHash": game.md5Hash])
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

