//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSearchViewController.swift
//  Provenance
//
//  Created by James Addyman on 12/06/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import UIKit
import RealmSwift

class PVSearchViewController: UICollectionViewController {
    var searchResults: Results<PVGame>?

    override func viewDidLoad() {
        super.viewDidLoad()
        RomDatabase.sharedInstance.refresh()
        (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = UIEdgeInsetsMake(20, 0, 20, 0)
        collectionView?.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: "SearchResultCell")
        collectionView?.contentInset = UIEdgeInsetsMake(40, 80, 40, 80)
    }

    var documentsPath : URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return URL(fileURLWithPath:paths.first!)
    }()

    func biosPath(forSystemID systemID: String) -> URL {
        return documentsPath.appendingPathComponent("BIOS", isDirectory: true).appendingPathComponent(systemID, isDirectory: true)
    }

    var romsPath : URL {
        return documentsPath.appendingPathComponent("roms", isDirectory: true)
    }

    func batterySavesPath(forROM romPath: URL) -> URL {

        let romName: String = romPath.deletingPathExtension().lastPathComponent
        
        let batterySavesDirectory: URL = documentsPath.appendingPathComponent("Battery States", isDirectory: true).appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: batterySavesDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DLOG("Error creating battery save directory: \(error.localizedDescription)")
        }

        return batterySavesDirectory
    }

    func saveStatePath(forROM romPath: URL) -> URL {
        let romName: String = romPath.deletingPathExtension().lastPathComponent

        let saveStateDirectory: URL = documentsPath.appendingPathComponent("Save States", isDirectory: true).appendingPathComponent(romName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: saveStateDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DLOG("Error creating save state directory: \(error.localizedDescription)")
        }

        return saveStateDirectory
    }
    
    typealias BiosDictionary = [String: String]
    func canLoad(_ game: PVGame) -> Bool {
        
        guard let system = PVEmulatorConfiguration.sharedInstance().system(forIdentifier: game.systemIdentifier) else {
            ELOG("Unknown system \(game.systemIdentifier)")
            return false
        }
        
        let value = system[PVRequiresBIOSKey] as? NSNumber
        
        let requiresBIOS: Bool = value?.boolValue ?? false

        if requiresBIOS {
            
            // Check dictionary for bios names
            guard let biosEntries = system[PVBIOSNamesKey] as? [BiosDictionary] else {
                ELOG("System \(game.systemIdentifier) specifies it requires bios but doesn't provide a list of names")
                return false
            }

            let biosPath: URL = self.biosPath(forSystemID: game.systemIdentifier)
            
            // Get contents of BIOS directory
            let contentsMaybe : [String]?
            do {
                contentsMaybe = try FileManager.default.contentsOfDirectory(at: biosPath, includingPropertiesForKeys:[], options: .skipsHiddenFiles).map({ (path) -> String in
                    return path.lastPathComponent
                })
            } catch {
                DLOG("Unable to get contents of \(biosPath) because \(error.localizedDescription)")
                return false
            }
            
            // Check if it's not empty first
            guard let contents = contentsMaybe else {
                DLOG("BIOS path was empty \(biosPath.path)")
                return false
            }
            
            // Check we hav all required BIOS files
            var canLoad = true
            var missingBIOSes = [String]()
            for bios: BiosDictionary in biosEntries {
                let name = bios["Name"]!
                if !contents.contains(name) {
                    canLoad = false
                    missingBIOSes.append(name)
                }
            }
            
            if canLoad == false {
                
                
                let message = """
                \(system[PVShortSystemNameKey]!) requires BIOS files to run games. Ensure the following files are inside Documents/BIOS/\(system[PVSystemIdentifierKey]!)/
                
                \(missingBIOSes.joined(separator: ","))
                """
                let alertController = UIAlertController(title: "Missing BIOS Files", message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alertController, animated: true) {() -> Void in }
            }
        }

        return true
    }
    
    func load(_ game: PVGame) {
        if !(presentedViewController is PVEmulatorViewController) {
            if self.canLoad(game) {
                guard let emulatorViewController = PVEmulatorViewController(game: game) else {
                    ELOG("Failed to create PVEmulatorViewController")
                    return
                }
                let romURL = romsPath.appendingPathComponent(game.romPath, isDirectory: false)
                emulatorViewController.batterySavesPath = self.batterySavesPath(forROM: romURL).path
                emulatorViewController.saveStatePath = self.saveStatePath(forROM: romURL).path
                emulatorViewController.biosPath = self.biosPath(forSystemID: game.systemIdentifier).path
                emulatorViewController.modalTransitionStyle = .crossDissolve
                self.present(emulatorViewController, animated: true) {() -> Void in }
                PVControllerManager.shared().iCadeController?.refreshListener()
                self.updateRecentGames(game)
            }
        }
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.sharedInstance
        database.refresh()
        let recents: Results<PVRecentGame> = RomDatabase.sharedInstance.all(PVRecentGame.self)
        
        
        // Shouldn't se just update the date instead? - jm
        if let recentToDelete = database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash).first {
            do {
                try RomDatabase.sharedInstance.delete(object: recentToDelete)
            } catch {
                ELOG("Failed to delte recent entry for game \(game.title)")
            }
        }
 
        if recents.count >= PVMaxRecentsCount() {
            if let oldestRecent = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                try? database.delete(object: oldestRecent)
            }
        }
        
        let newRecent = PVRecentGame(withGame: game)
        do {
            try database.add(object: newRecent, update:false)
        } catch {
            ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchResultCell", for: indexPath) as! PVGameLibraryCollectionViewCell
        
        if let game = searchResults?[indexPath.item] {
            cell.setup(with: game)
        }
        cell.setNeedsLayout()
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = searchResults?[indexPath.item] {
            load(game)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 250, height: 360)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 88
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 30
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(40, 40, 120, 40)
    }
}

extension PVSearchViewController : UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        
        let sorted = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText])).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        searchResults = sorted
        collectionView?.reloadData()
    }
}
