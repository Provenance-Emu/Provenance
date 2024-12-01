//
//  RomDatabase+Saves.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/30/24.
//

import PVCoreBridge

/// Save state purging and recoovery
public extension RomDatabase {

    /// Recover save states from the save state directory
    public func recoverSaveStates(forGame game: PVGame, core: EmulatorCoreIOInterface) throws {
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
            let realm = RomDatabase.sharedInstance.realm
            var saves:[String:Int]=[:]
            for saveState in game.saveStates {
                saves[saveState.file.url.lastPathComponent.lowercased()] = 1;
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
                            return
                        }
                        let imgFile = PVImageFile(withURL:  URL(fileURLWithPath: url.path.replacingOccurrences(of: "svs", with: "jpg")))
                        let saveFile = PVFile(withURL: url)
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

    public func updateSaveStates(forGame game: PVGame) throws {
        do {
            // Clear saves from database that don't have files
            for save in game.saveStates {
                if !FileManager.default.fileExists(atPath: save.file.url.path) {
                    try? PVSaveState.delete(save)
                }
            }
            // Clear auto-saves from database that don't have files
            for save in game.autoSaves {
                if !FileManager.default.fileExists(atPath: save.file.url.path) {
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
