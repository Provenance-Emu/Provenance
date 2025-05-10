//
//  RomDatabase+Saves.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/30/24.
//

import PVCoreBridge
import PVFileSystem
import PVLogging
import RealmSwift

/// Save state purging and recoovery
public extension RomDatabase {

    func recoverAllSaveStates() {
        // Get the base directory for saves
        let saveStatesDirectory: URL = Paths.saveSavesPath
        // iterate sub-dirs calling recoverSaveStates(forPath: path)
        let fm = FileManager.default
        guard let subdirectories = try? fm.contentsOfDirectory(at: saveStatesDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }
        for subdirectory in subdirectories {
            recoverSaveStates(forPath: subdirectory)
        }
    }

    func recoverSaveStates(forPath path: URL) {
        let fileManager = FileManager.default

        // Get all .svs.json files in the directory
        guard let jsonFiles = try? fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" && $0.lastPathComponent.contains(".svs.") }) else {
            ELOG("Failed to read directory contents at \(path)")
            return
        }
        
#if DEBUG
//        // For testing, remove all PVSaveState imges
//        let allSaves = RomDatabase.sharedInstance.all(PVSaveState.self)
//        if !allSaves.isEmpty {
//            for save in allSaves {
//                try? realm.write {
//                    save.image = nil
//                }
//            }
//        }
#endif

        // Collect save states to be added
        var saveStatesToAdd: [PVSaveState] = []

        for jsonURL in jsonFiles {
            do {
                // 1. Read and decode the JSON file
                let jsonData = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                let saveStateMetadata = try decoder.decode(SaveStateMetadata.self, from: jsonData)

                // 2. Check if this save state already exists in the database
                if let existingSave = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateMetadata.id) {
                    DLOG("Save state already exists: \(existingSave.id)")

                    // Check if the existing save state's image needs to be updated
                    if existingSave.image == nil || !fileManager.fileExists(atPath: existingSave.image!.url!.path) {

                        // Look for the image in the same directory as the save state
                        let localImageURL = jsonURL.deletingPathExtension().deletingPathExtension()
                            .appendingPathExtension("jpg")

                        if fileManager.fileExists(atPath: localImageURL.path) {
                            let imgFile = PVImageFile(withURL:  localImageURL.standardizedFileURL)

                            DLOG("Found image file at alternate location for existing save: \(localImageURL.path)")
                            try? realm.write {
                                existingSave.image = imgFile
                                ILOG("Updated image path for existing save state: \(existingSave.id) to \(imgFile.url!.path(percentEncoded: false))")
                            }
                        } else {
                            WLOG("No valid image found for existing save state: \(existingSave.id)")
                        }
                    }
                    continue
                }

                // 3. Find the matching game using MD5
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: saveStateMetadata.game.md5) else {
                    WLOG("No matching game found for save state: \(saveStateMetadata.id)")
                    continue
                }

                // 4. Find the matching core
                guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: saveStateMetadata.core.identifier) else {
                    WLOG("No matching core found for save state: \(saveStateMetadata.id)")
                    continue
                }

                // 5. Create PVFile for the save state
                let saveFileURL = jsonURL.deletingPathExtension() // Remove .json extension
                guard fileManager.fileExists(atPath: saveFileURL.path) else {
                    WLOG("Save state file not found: \(saveFileURL.path)")
                    continue
                }
                let saveFile = PVFile(withURL: saveFileURL, relativeRoot: .iCloud)

                // 6. Create PVImageFile for the screenshot if it exists
                var imageFile: PVImageFile?
                if let imageURLString = saveStateMetadata.image?.url,
                   let originalImageURL = URL(string: imageURLString) {

                    // First try the original path from JSON
                    if fileManager.fileExists(atPath: originalImageURL.path) {
                        imageFile = PVImageFile(withURL: originalImageURL)
                    } else {
                        // If original path fails, look for the image in the same directory as the save state
                        let localImageURL = jsonURL.deletingPathExtension().deletingPathExtension()
                            .appendingPathExtension("jpg")

                        if fileManager.fileExists(atPath: localImageURL.path) {
                            DLOG("Found image file at alternate location: \(localImageURL.path)")
                            imageFile = PVImageFile(withURL: localImageURL)
                        } else {
                            WLOG("Image file not found at original path (\(originalImageURL.path)) or local path (\(localImageURL.path))")
                        }
                    }
                }

                // 7. Create new PVSaveState
                let newSaveState = PVSaveState(
                    withGame: game,
                    core: core,
                    file: saveFile,
                    date: Date(timeIntervalSinceReferenceDate: saveStateMetadata.date),
                    image: imageFile,
                    isAutosave: saveStateMetadata.isAutosave ?? false,
                    isPinned: saveStateMetadata.isPinned ?? false,
                    isFavorite: saveStateMetadata.isFavorite ?? false,
                    userDescription: saveStateMetadata.userDescription,
                    createdWithCoreVersion: saveStateMetadata.core.project.version
                )

                // Set the original ID
                newSaveState.id = saveStateMetadata.id

                saveStatesToAdd.append(newSaveState)
                ILOG("Prepared save state for recovery: \(newSaveState.id)")

            } catch {
                ELOG("Failed to prepare save state from \(jsonURL): \(error)")
            }
        }

        // Batch write all save states to Realm
        if !saveStatesToAdd.isEmpty {
            do {
                try realm.write {
                    realm.add(saveStatesToAdd)
                    ILOG("Successfully recovered \(saveStatesToAdd.count) save states")
                }
            } catch {
                ELOG("Failed to batch write save states to Realm: \(error)")
            }
        } else {
            DLOG("No save states to recover in \(path)")
        }
    }

    /// Recover save states from the save state directory
    func recoverSaveStates(forGame game: PVGame, core: EmulatorCoreIOInterface) throws {
        let game = game.warmUp()

        let saveStatePath: URL = PVEmulatorConfiguration.saveStatePath(forGame: game)

        do {
            let fileManager = FileManager.default
            let directoryContents = try fileManager.contentsOfDirectory(
                at: saveStatePath,
                includingPropertiesForKeys:[.contentModificationDateKey]
            ).filter { $0.lastPathComponent.hasSuffix(".svs") }
                .sorted(by: {
                    let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                    let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                    return date0.compare(date1) == .orderedAscending
                })
            let realm = try Realm()
            
            var saves:[String:Int]=[:]
            for saveState in game.saveStates {
                saves[saveState.file!.url!.lastPathComponent.lowercased()] = 1;
            }
            for url in directoryContents {
                let file = url.lastPathComponent.lowercased()
                if (fileManager.fileExists(atPath: url.path) &&
                    file.contains("svs") &&
                    !file.contains("json") &&
                    !file.contains("jpg") &&
                    saves.index(forKey: file) == nil) {
                    do {
                        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
                            throw SaveStateError.noCoreFound(core.coreIdentifier ?? "null")
                        }
                        let imgFile = PVImageFile(withURL:  URL(fileURLWithPath: url.path.replacingOccurrences(of: "svs", with: "jpg")), relativeRoot: .iCloud)
                        let saveFile = PVFile(withURL: url, relativeRoot: .iCloud)
                        let newState = PVSaveState(withGame: game, core: core, file: saveFile, image: imgFile, isAutosave: false)
                        try realm.write {
                            realm.add(newState)
                        }
                    } catch {
                        ELOG(error.localizedDescription)
                    }
                }
            }
        } catch {
            ELOG("\(error.localizedDescription)")
            throw error
        }
    }

    func updateSaveStates(forGame game: PVGame) throws {
        let game = game.warmUp()
        do {
            // Clear saves from database that don't have files
            for save in game.saveStates {
                if !FileManager.default.fileExists(atPath: save.file!.url!.path) {
                    try? PVSaveState.delete(save)
                }
            }
            // Clear auto-saves from database that don't have files
            for save in game.autoSaves {
                if !FileManager.default.fileExists(atPath: save.file!.url!.path) {
                    try? PVSaveState.delete(save)
                }
            }
        } catch {
            ELOG("\(error.localizedDescription)")
            throw error
        }
    }
}

/* Example saves json

 ```json
 {
   "isAutosave": false,
   "game": {
     "systemShortName": "GBA",
     "crc": "",
     "lastPlayed": 752119302.780123,
     "title": "Kingdom Hearts: Chain of Memories",
     "file": {
       "md5": "f7b81e3f3bb3b02d973fc6f145ad4416",
       "local": true,
       "size": 33554432,
       "online": true,
       "fileName": "Kingdom Hearts - Chain of Memories (U) (1).gba"
     },
     "publishDate": "Dec7, 2004",
     "developer": "Jupiter Corporation",
     "releaseID": "51672",
     "isFavorite": false,
     "md5": "F7B81E3F3BB3B02D973FC6F145AD4416",
     "boxBackArtworkURL": "https:\/\/gamefaqs.gamespot.com\/a\/box\/4\/9\/4\/57494_back.jpg",
     "gameDescription": "KINGDOM HEARTS® CHAIN OF MEMORIES delivers an entirely new adventure and sets the stage for KINGDOM HEARTS II. Sora, Donald and Goofy travel through many vast and colorful worlds in search of their missing companions.",
     "systemIdentifier": "com.provenance.gba",
     "genres": "Role-Playing,Action RPG",
     "referenceURL": "http:\/\/www.gamefaqs.com\/gba\/919011-kingdom-hearts-chain-of-memories",
     "id": "6A5DAE83-EF74-4E80-93FB-590B2E840076",
     "regionName": "USA",
     "regionID": 21,
     "playCount": 1
   },
   "file": {
     "local": true,
     "md5": "b80f99dd5590603e00e16abf3afea35c",
     "fileName": "F7B81E3F3BB3B02D973FC6F145AD4416.752119311.126136.svs",
     "online": true,
     "size": 118861
   },
   "date": 752119311.185537,
   "image": {
     "url": "file:\/\/\/var\/mobile\/Containers\/Data\/Application\/759855AC-1A54-4BFF-B089-9CF7212EEBF8\/Documents\/Save%20States\/Kingdom%20Hearts%20-%20Chain%20of%20Memories%20(U)%20(1)\/F7B81E3F3BB3B02D973FC6F145AD4416.752119311.126136.jpg"
   },
   "id": "000C90A2-7F66-46E6-88B5-889283E290FE",
   "core": {
     "systems": [{
       "releaseYear": 2001,
       "bits": 32,
       "usesCDs": false,
       "portableSystem": true,
       "manufacturer": "Nintendo",
       "options": 2,
       "name": "Game Boy Advance",
       "supported": true,
       "openvgDatabaseID": 20,
       "identifier": "com.provenance.gba",
       "headerByteSize": 0,
       "requiresBIOS": false,
       "BIOSes": [{
         "optional": true,
         "expectedSize": 16384,
         "descriptionText": "Game Boy Advance BIOS",
         "status": {
           "state": {
             "rawValue": 0
           },
           "required": false,
           "available": false
         },
         "expectedFilename": "GBA.BIOS",
         "expectedMD5": "A860E8C0B6D573D191E4EC7DB1B1E4F6",
         "version": "",
         "regions": 1048576
       }],
       "extensions": ["gba", "agb", "bin", "zip"],
       "shortName": "GBA",
       "supportsRumble": false,
       "screenType": "ColorLCD"
     }],
     "identifier": "com.provenance.core.visualboyadvance",
     "disabled": false,
     "project": {
       "url": "https:\/\/sourceforge.net\/projects\/vba\/",
       "version": "1.8.0",
       "name": "VisualBoyAdvance"
     },
     "principleClass": "PVVisualBoyAdvance.PVVisualBoyAdvanceCore"
   }
 }
```

 */

// MARK: - Save State Metadata Structs
private struct SaveStateMetadata: Codable {
    let id: String
    let isAutosave: Bool?
    let isPinned: Bool?
    let isFavorite: Bool?
    let date: TimeInterval
    let game: GameMetadata
    let core: CoreMetadata
    let file: FileMetadata
    let image: ImageMetadata?
    let userDescription: String?
}

private struct GameMetadata: Codable {
    let md5: String
    let systemIdentifier: String
    let title: String
}

private struct CoreMetadata: Codable {
    let identifier: String
    let project: ProjectMetadata
}

private struct ProjectMetadata: Codable {
    let version: String
    let name: String
}

private struct FileMetadata: Codable {
    let md5: String
    let fileName: String
    let size: UInt64
}

private struct ImageMetadata: Codable {
    let url: String
}
