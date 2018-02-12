//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import Foundation

import CoreSpotlight

public extension PVGameImporter {
    
    /**
     Import a specifically named image file to the matching game.
     
     To update “Kart Fighter.nes”, use an image named “Kart Fighter.nes.png”.
     
     @param imageFullPath The artwork image path
     @return The game that was updated
     */
    @objc
    class func importArtwork(fromPath imageFullPath: String) -> PVGame? {
        
        // Check the file exists (and is not a directory for some reason)
        var isDirectory :ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: imageFullPath, isDirectory: &isDirectory)
        if !fileExists || isDirectory.boolValue {
            ELOG("File doesn't exist or is directory at \(imageFullPath)")
            return nil
        }
        
        // Make sure we always delete the image even on early error returns
        defer {
            do {
                try FileManager.default.removeItem(atPath: imageFullPath)
            } catch {
                ELOG("Failed to delete image at path \(imageFullPath) \n \(error.localizedDescription)")
            }
        }
        
        let urlPath =  URL(fileURLWithPath: imageFullPath)
        
        // Read the data
        let coverArtFullData : Data
        do {
            coverArtFullData = try Data.init(contentsOf: urlPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath)\n\(error.localizedDescription)")
            return nil
        }
        
        // Create a UIImage from the Data
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        
        // Scale the UIImage to our desired max size
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }

        // Create new Data from scaled image
        guard let coverArtScaledData = UIImagePNGRepresentation(coverArtScaledImage) else {
            ELOG("Failed to create data respresentation of scaled image")
            return nil
        }
        
        // Hash the image and save to cache
        let hash: String = (coverArtScaledData as NSData).md5Hash
        PVMediaCache.writeData(toDisk: coverArtScaledData, withKey: hash)
        
        let imageFileExtension: String = "." + urlPath.pathExtension
        
        // Trim the extension off the filename
        let imageFilename: String = urlPath.lastPathComponent
        let gameFilename: String = imageFilename.replacingOccurrences(of: imageFileExtension, with: "")
        
        // Figure out what system this belongs to by extension
        // Hey, how is this going to work if we just stripped it?
        let gameExtension = URL(fileURLWithPath: gameFilename).pathExtension
        
        guard let systemID: String = PVEmulatorConfiguration.sharedInstance().systemIdentifier(forFileExtension: gameExtension) else {
            ELOG("No system for extension \(gameExtension)")
            return nil
        }
        
        let cdBasedSystems = PVEmulatorConfiguration.sharedInstance().cdBasedSystemIDs
        let isCDBasedSystem = cdBasedSystems.contains(systemID)
        // Skip CD systems for non special extensions
        if  isCDBasedSystem && (gameExtension.lowercased() != "cue" || gameExtension.lowercased() != "m3u") {
            ELOG("System for extension \(gameExtension) is a CD system and {\(gameExtension)} not the right matching file type of cue or m3u")
            return nil
        }
        
        let gamePartialPath: String = URL(fileURLWithPath: systemID).appendingPathComponent(gameFilename).path
        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }
        
        let database = RomDatabase.temporaryDatabaseContext()
        
        // Find the game in the database
        guard let game = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath).first else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }

        do {
            try database.writeTransaction {
                game.customArtworkURL = hash
            }
        } catch {
            ELOG("Couldn't update game with new artwork URL")
        }
        
        return game
    }
    
    @objc
    func getRomInfoForFiles(atPaths paths: [String], userChosenSystem chosenSystemID: String? = nil) {
        let database = RomDatabase.temporaryDatabaseContext()
        database.refresh()
        
        var spotlightItems = [Any]()

        paths.forEach { (path) in
            let isDirectory: Bool = !path.contains(".")
            if path.hasPrefix(".") || isDirectory {
                VLOG("Skipping file with . as first character or it's a directory")
                return
            }
            autoreleasepool {
                var systemIDMaybe: String? = nil
                
                let urlPath = URL(fileURLWithPath: path)
                let fileExtension = urlPath.pathExtension
                let fileExtensionLower = fileExtension.lowercased()
                
                if let chosenSystemID = chosenSystemID, !chosenSystemID.isEmpty {
                    systemIDMaybe = chosenSystemID
                }
                else {
                    systemIDMaybe = PVEmulatorConfiguration.sharedInstance().systemIdentifier(forFileExtension: fileExtension)
                }
                
                // No system found to match this file
                guard let systemID = systemIDMaybe else {
                    ELOG("No system matched extension {\(fileExtension)}")
                    return
                }
                
                
                // Skip non .m3u/.cue files for CD systems to avoid importing .bins
                let cdBasedSystems = PVEmulatorConfiguration.sharedInstance().cdBasedSystemIDs
                if cdBasedSystems.contains(systemID) && (fileExtensionLower != "cue" || fileExtension != "m3u") {
                    return
                }
                
                let partialPath: String = URL(fileURLWithPath: systemID).appendingPathComponent(urlPath.lastPathComponent).path
                let title: String = urlPath.lastPathComponent.replacingOccurrences(of: "." + fileExtension, with: "")
                
                // Deal with m3u files
                //                if fileExtension == "m3u"
                //                {
                //                    // RegEx pattern match the parentheses e.g. " (Disc 1)" and update dictionary with trimmed gameTitle string
                //                    // Grabbed this from OpenEMU - jm
                //                    let newGameTitle = title.replacingOccurrences(of: "\\ \\(Disc.*\\)", with: "", options: .regularExpression, range: Range(0, title.count))
                //                }
                
                var maybeGame: PVGame? = nil
                
                // Check if we have this game already
                let existingGame = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: partialPath).first
                
                if let existingGame = existingGame {
                    maybeGame = existingGame
                } else {
                    let game = PVGame()
                    game.romPath = partialPath
                    game.title = title
                    game.systemIdentifier = systemID
                    game.requiresSync = true
                    
                    guard let md5 = calculateMD5(for: game) else {
                        ELOG("Couldn't calculate MD5 for game")
                        return
                    }
                    
                    game.md5Hash = md5
                    
                    do {
                        try database.add(object: game)
                        
                        #if os(iOS)
                        // Add to split database
                        if #available(iOS 9.0, *) {
                            let spotlightItem = CSSearchableItem(uniqueIdentifier: "com.provenance-emu.game.\(game.md5Hash)", domainIdentifier: "com.provenance-emu.game", attributeSet: game.spotlightContentSet)
                            spotlightItems.append(spotlightItem)
                        }
                        #endif
                    } catch {
                        ELOG("Couldn't add new game \(title): \(error.localizedDescription)")
                        return
                    }
                    
                    maybeGame = game
                }
                
                guard let game = maybeGame else {
                    ELOG("Shouldn't be here. PVGame is  nil in all cases")
                    return
                }
                
                var modified = false
                if game.requiresSync {
                    if self.importStartedHandler != nil {
                        DispatchQueue.main.async(execute: {() -> Void in
                            self.importStartedHandler?(path)
                        })
                    }
                    lookupInfo(for: game)
                    modified = true
                }
                
                if self.finishedImportHandler != nil {
                    let md5: String = game.md5Hash
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.finishedImportHandler?(md5, modified)
                    })
                }
                getArtworkFromURL(game.originalArtworkURL)
            } // autorelease pool
        } // for each
        
        #if os(iOS)
        if #available(iOS 9.0, *) {
            CSSearchableIndex.default().indexSearchableItems(spotlightItems as! [CSSearchableItem]) { error in
                if let error = error {
                    ELOG("indexing error: \(error)")
                }
            }
        }
        #endif
    }
}

// The complete but error filled auto-transition is below. Going to pick out parts to use as category extension for now
/*
import Foundation

typealias PVGameImporterImportStartedHandler = (_ path: String) -> Void
typealias PVGameImporterCompletionHandler = (_ encounteredConflicts: Bool) -> Void
typealias PVGameImporterFinishedImportingGameHandler = (_ md5Hash: String, _ modified: Bool) -> Void
typealias PVGameImporterFinishedGettingArtworkHandler = (_ artworkURL: String) -> Void

class PVGameImporter: NSObject {
    private(set) var serialImportQueue: DispatchQueue?
    var importStartedHandler: PVGameImporterImportStartedHandler?
    var completionHandler: PVGameImporterCompletionHandler?
    var finishedImportHandler: PVGameImporterFinishedImportingGameHandler?
    var finishedArtworkHandler: PVGameImporterFinishedGettingArtworkHandler?
    var isEncounteredConflicts = false

    var serialImportQueue: DispatchQueue?
    var systemToPathMap = [AnyHashable: Any]()
    var romToSystemMap = [AnyHashable: Any]()
    private var _openVGDB: OESQLiteDatabase?
    var openVGDB: OESQLiteDatabase? {
        if _openVGDB == nil {
                var error: Error?
                _openVGDB = try? OESQLiteDatabase(url: Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite"))
                if _openVGDB == nil {
                    DLog("Unable to open game database: %@", error?.localizedDescription)
                    return nil
                }
            }
            return _openVGDB
    }

    convenience init(completionHandler: PVGameImporterCompletionHandler) {
        self.init()

        self.completionHandler = completionHandler
    
    }

    func startImport(forPaths paths: [Any]) {
        serialImportQueue.async(execute: {() -> Void in
            let newPaths = self.importFiles(atPaths: paths)
            self.getRomInfoForFiles(atPaths: newPaths, userChosenSystem: nil)
            if self.completionHandler {
                DispatchQueue.main.sync(execute: {() -> Void in
                    self.completionHandler(self.isSelf.isEncounteredConflicts)
                })
            }
        })
    }

    func conflictedFiles() -> [Any] {
        var error: Error? = nil
        let contents = try? FileManager.default.contentsOfDirectory(atPath: conflictPath())
        if contents == nil {
            DLog("Unable to get contents of %@ because %@", conflictPath(), error?.localizedDescription)
        }
        return contents ?? [Any]()
    }

    func resolveConflicts(withSolutions solutions: [AnyHashable: Any]) {
        let filePaths = solutions.keys
        for filePath: String in filePaths {
            let systemID = solutions[filePath] as? String
            let subfolder = systemToPathMap[systemID] as? String
            if !FileManager.default.fileExists(atPath: subfolder) {
                try? FileManager.default.createDirectory(atPath: subfolder, withIntermediateDirectories: true, attributes: nil)
            }
            var error: Error? = nil
            if (try? FileManager.default.moveItem(atPath: URL(fileURLWithPath: conflictPath()).appendingPathComponent(filePath).path, toPath: URL(fileURLWithPath: subfolder).appendingPathComponent(filePath).path)) == nil {
                DLog("Unable to move %@ to %@ because %@", filePath, subfolder, error?.localizedDescription)
            }
                // moved the .cue, now move .bins .imgs etc
            let cueSheetPath: String = URL(fileURLWithPath: subfolder).appendingPathComponent(filePath).path
            let relatedFileName: String = URL(fileURLWithPath: filePath).deletingPathExtension().path
            let contents = try? FileManager.default.contentsOfDirectory(atPath: conflictPath())
            for file: String in contents {
                    // Crop out any extra info in the .bin files, like Game.cue and Game (Track 1).bin, we want to match up to just 'Game'
                var fileWithoutExtension: String = file.replacingOccurrences(of: ".\(URL(fileURLWithPath: file).pathExtension)", with: "")
                if fileWithoutExtension.count > relatedFileName.count {
                    fileWithoutExtension = (fileWithoutExtension as NSString).substring(with: NSRange(location: 0, length: relatedFileName.count))
                }
                if fileWithoutExtension == relatedFileName {
                        // Before moving the file, make sure the cue sheet's reference uses the same case.
                    var cuesheet = try? String(contentsOfFile: cueSheetPath, encoding: .utf8)
                    if cuesheet != nil {
                        let range: NSRange? = (cuesheet as NSString?)?.range(of: file, options: .caseInsensitive)
                        if range?.location != NSNotFound {
                            if let subRange = Range<String.Index>(range ?? NSRange(), in: cuesheet) { cuesheet?.replaceSubrange(subRange, with: file) }
                            if (try? cuesheet?.write(toFile: cueSheetPath, atomically: false, encoding: .utf8)) == nil {
                                DLog("Unable to rewrite cuesheet %@ because %@", cueSheetPath, error?.localizedDescription)
                            }
                        }
                        else {
                            DLog("Range of string <%@> not found in file <%@>", file, cueSheetPath)
                        }
                    }
                    else {
                        DLog("Unable to read cue sheet %@ because %@", cueSheetPath, error?.localizedDescription)
                    }
                    if (try? FileManager.default.moveItem(atPath: URL(fileURLWithPath: conflictPath()).appendingPathComponent(file).path, toPath: URL(fileURLWithPath: subfolder).appendingPathComponent(file).path)) == nil {
                        DLog("Unable to move file from %@ to %@ - %@", filePath, subfolder, error?.localizedDescription)
                    }
                }
            }
            weak var weakSelf: PVGameImporter? = self
            serialImportQueue.async(execute: {() -> Void in
                weakSelf?.getRomInfoForFiles(atPaths: [filePath], userChosenSystem: systemID)
                if weakSelf?.self.completionHandler != nil {
                    DispatchQueue.main.async(execute: {() -> Void in
                        weakSelf?.self.completionHandler(false)
                    })
                }
            })
        }
    }

    func getRomInfoForFiles(atPaths paths: [Any], userChosenSystem systemID: String) {
        let database = RomDatabase.temporaryDatabaseContext()
        database.refresh()
        for path: String in paths {
            let isDirectory: Bool = !path.contains(".")
            if path.hasPrefix(".") || isDirectory {
                continue
            }
            autoreleasepool {
                var systemID: String? = nil
                if chosenSystemID.count == 0 {
                    systemID = PVEmulatorConfiguration.sharedInstance().systemIdentifier(forFileExtension: URL(fileURLWithPath: path).pathExtension)
                }
                else {
                    systemID = chosenSystemID
                }
                let cdBasedSystems = PVEmulatorConfiguration.sharedInstance().cdBasedSystemIDs()
                if cdBasedSystems.contains(systemID ?? "") && ((URL(fileURLWithPath: path).pathExtension == "cue") == false) {
                    continue
                }
                let partialPath: String = URL(fileURLWithPath: systemID ?? "").appendingPathComponent(path.lastPathComponent).path
                let title: String = path.lastPathComponent.replacingOccurrences(of: "." + (URL(fileURLWithPath: path).pathExtension), with: "")
                var game: PVGame? = nil
                let results: RLMResults? = database.objectsOf(PVGame.self, predicate: NSPredicate(format: "romPath == %@", partialPath.count ? partialPath : ""))
                if results?.count() != nil {
                    game = results?.first
                }
                else {
                    if systemID?.count == nil {
                        continue
                    }
                    game = PVGame()
                    game?.romPath = partialPath
                    game?.title = title
                    game?.systemIdentifier = systemID
                    game?.isRequiresSync = true
                    try? database.add(withObject: game)
                }
                var modified = false
                if game?.requiresSync() != nil {
                    if importStartedHandler {
                        DispatchQueue.main.async(execute: {() -> Void in
                            self.importStartedHandler(path)
                        })
                    }
                    lookupInfo(for: game)
                    modified = true
                }
                if finishedImportHandler {
                    let md5: String? = game?.md5Hash()
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.finishedImportHandler(md5, modified)
                    })
                }
                getArtworkFromURL(game?.originalArtworkURL())
            }
        }
    }

    func getArtworkFromURL(_ url: String) {
        if !url.count || PVMediaCache.filePath(forKey: url).length() {
            return
        }
        DLog("Starting Artwork download for %@", url)
        let artworkURL = URL(string: url)
        if artworkURL == nil {
            return
        }
        let request = URLRequest(url: artworkURL!)
        var urlResponse: HTTPURLResponse? = nil
        var error: Error? = nil
        let data: Data? = try? PVSynchronousURLSession.sendSynchronousRequest(request, returning: urlResponse)
        if error != nil {
            DLog("error downloading artwork from: %@ -- %@", url, error?.localizedDescription)
            return
        }
        if urlResponse?.statusCode != 200 {
            DLog("HTTP Error: %zd", urlResponse?.statusCode)
            DLog("Response: %@", urlResponse)
        }
        let artwork = UIImage(data: data ?? Data())
        if artwork != nil {
            PVMediaCache.writeImage(toDisk: artwork, withKey: url)
        }
        if finishedArtworkHandler {
            DispatchQueue.main.sync(execute: {() -> Void in
                self.finishedArtworkHandler(url)
            })
        }
    }

// MARK: -

    override init() {
        super.init()
        
        serialImportQueue = DispatchQueue(label: "com.jamsoftonline.provenance.serialImportQueue")
        systemToPathMap = updateSystemToPathMap()
        romToSystemMap = updateRomToSystemMap()
    
    }

    func importFiles(atPaths paths: [String]) -> [String] {
        var newPaths = [AnyHashable]() as? [String]
        // Reorder .cue's first.this is so we find cue's before their bins.
        paths = ((paths as NSArray).sortedArray(comparator: {(_ obj1: String, _ obj2: String) -> ComparisonResult in
            if (URL(fileURLWithPath: obj1).pathExtension == "cue") {
                return .orderedAscending
            }
            else if (URL(fileURLWithPath: obj2).pathExtension == "cue") {
                return .orderedDescending
            }
            else {
                return obj1.compare(obj2)
            }

        })) as? [String] ?? [String]()
        let canidateFiles = paths.mapObjects(usingBlock: {(_ path: String, _ idx: Int) -> ImportCanidateFile in
                return ImportCanidateFile(filePath: URL(fileURLWithPath: self.romsPath()).appendingPathComponent(path).path)
            }) as? [ImportCanidateFile]
        // do CDs first to avoid the case where an item related to CDs is mistaken as another rom and moved
        // before processing its CD cue sheet or something
        for canidate: ImportCanidateFile in canidateFiles {
            if FileManager.default.fileExists(atPath: canidate.filePath) {
                if isCDROM(canidate) {
                    newPaths.append(contentsOf: moveCDROM(toAppropriateSubfolder: canidate))
                }
            }
        }
        for canidate: ImportCanidateFile in canidateFiles {
            if FileManager.default.fileExists(atPath: canidate.filePath) {
                let newPath: String = moveROM(toAppropriateSubfolder: canidate)
                if newPath.count != 0 {
                    newPaths.append(newPath)
                }
            }
        }
        return newPaths
    }

    func systemId(forROMCanidate rom: ImportCanidateFile) -> String {
        let md5: String = rom.md5
        let fileName: String = rom.filePath.lastPathComponent
        var error: Error?
        var results: [[String: NSObject]]? = nil
        let queryString = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)' OR romFileName = '\(fileName)'"
        results = try? openVGDB?.executeQuery(queryString)
        if results == nil {
            DLog("Unable to find rom by MD5: %@", error?.localizedDescription)
        }
        if results?.count != nil {
            let databaseID: String = results[0]["systemID"].description
            let config = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
            let systemID: String = config.systemID(forDatabaseID: databaseID)
            return systemID
        }
        else {
            return nil
        }
    }

    func moveCDROM(toAppropriateSubfolder canidateFile: ImportCanidateFile) -> [Any] {
        var newPaths = [AnyHashable]()
        let systemsForExtension = systemIDsForRom(atPath: canidateFile.filePath)
        var systemID: String? = nil
        var subfolderPath: String? = nil
        if systemsForExtension.count > 1 {
                // Try to match by MD5 or filename
            var systemID: String = systemId(forROMCanidate: canidateFile)
            if systemID != nil {
                subfolderPath = systemToPathMap[systemID]
            }
            else {
                // No MD5 match, so move to conflict dir
                subfolderPath = conflictPath()
                isEncounteredConflicts = true
            }
        }
        else {
            systemID = systemsForExtension.first ?? ""
            subfolderPath = systemToPathMap[systemID]
        }
        if subfolderPath?.count == nil {
            return nil
        }
        var error: Error? = nil
        if (try? FileManager.default.createDirectory(atPath: subfolderPath ?? "", withIntermediateDirectories: true, attributes: nil)) == nil {
            DLog("Unable to create %@ - %@", subfolderPath, error?.localizedDescription)
            return nil
        }
        if (try? FileManager.default.moveItem(atPath: URL(fileURLWithPath: romsPath()).appendingPathComponent(canidateFile.filePath.lastPathComponent).path, toPath: URL(fileURLWithPath: subfolderPath ?? "").appendingPathComponent(canidateFile.filePath.lastPathComponent).path)) == nil {
            DLog("Unable to move file from %@ to %@ - %@", canidateFile, subfolderPath, error?.localizedDescription)
            return nil
        }
        let cueSheetPath: String = URL(fileURLWithPath: subfolderPath ?? "").appendingPathComponent(canidateFile.filePath).path
        if !isEncounteredConflicts {
            newPaths.append(cueSheetPath)
        }
        // moved the .cue, now move .bins .imgs etc
        moveFilesSimiliar(toFilename: canidateFile.filePath.lastPathComponent, fromDirectory: romsPath(), toDirectory: subfolderPath, cuesheet: cueSheetPath)
        return newPaths
    }

    func moveFilesSimiliar(toFilename filename: String, fromDirectory from: String, toDirectory to: String, cuesheet cueSheetPath: String) {
        var error: Error?
        let relatedFileName: String = filename.replacingOccurrences(of: ".\(URL(fileURLWithPath: filename).pathExtension)", with: "")
        let contents = try? FileManager.default.contentsOfDirectory(atPath: romsPath())
        if contents == nil {
            DLog("Error scanning %@, %@", romsPath(), error?.localizedDescription)
            return
        }
        for file: String in contents {
            var fileWithoutExtension: String = file.replacingOccurrences(of: ".\(URL(fileURLWithPath: file).pathExtension)", with: "")
            // Some cue's have multiple bins, like, Game.cue Game (Track 1).bin, Game (Track 2).bin ....
            // Clip down the file name to the length of the .cue to see if they start to match
            if fileWithoutExtension.count > relatedFileName.count {
                fileWithoutExtension = (fileWithoutExtension as NSString).substring(with: NSRange(location: 0, length: relatedFileName.count))
            }
            if fileWithoutExtension == relatedFileName {
                // Before moving the file, make sure the cue sheet's reference uses the same case.
                if cueSheetPath != "" {
                    var cuesheet = try? String(contentsOfFile: cueSheetPath, encoding: .utf8)
                    if cuesheet != nil {
                        let range: NSRange? = (cuesheet as NSString?)?.range(of: file, options: .caseInsensitive)
                        if let subRange = Range<String.Index>(range ?? NSRange(), in: cuesheet) { cuesheet?.replaceSubrange(subRange, with: file) }
                        if (try? cuesheet?.write(toFile: cueSheetPath, atomically: false, encoding: .utf8)) == nil {
                            DLog("Unable to rewrite cuesheet %@ because %@", cueSheetPath, error?.localizedDescription)
                        }
                    }
                    else {
                        DLog("Unable to read cue sheet %@ because %@", cueSheetPath, error?.localizedDescription)
                    }
                }
                if (try? FileManager.default.moveItem(atPath: URL(fileURLWithPath: romsPath()).appendingPathComponent(file).path, toPath: URL(fileURLWithPath: to).appendingPathComponent(file).path)) == nil {
                    DLog("Unable to move file from %@ to %@ - %@", filename, to, error?.localizedDescription)
                }
                else {
                    DLog("Moved file from %@ to %@", filename, to)
                }
            }
        }
    }

    func moveIfBIOS(_ canidateFile: ImportCanidateFile) -> BIOSEntry {
        let config = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
        var bios: BIOSEntry?
        // Check if BIOS by filename - should possibly just only check MD5?
        if (bios = config.biosEntry(forFilename: canidateFile.filePath.lastPathComponent)) != nil {
            return bios ?? BIOSEntry()
        }
        else {
                // Now check by MD5
            let fileMD5: String = canidateFile.md5
            if (bios = config.biosEntry(forMD5: fileMD5)) != nil {
                return bios ?? BIOSEntry()
            }
        }
        return nil
    }

    func moveROM(toAppropriateSubfolder canidateFile: ImportCanidateFile) -> String {
        let filePath: String = canidateFile.filePath
        var newPath: String? = nil
        let systemsForExtension = systemIDsForRom(atPath: filePath)
        var systemID: String? = nil
        var subfolderPath: String? = nil
        let fm = FileManager.default
            // Check first if known BIOS
        let biosEntry: BIOSEntry? = moveIfBIOS(canidateFile)
        if biosEntry != nil {
            let config = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
            let biosDirectory: String = config.biosPath(forSystemID: biosEntry?.systemID)
            let destiaionPath: String = URL(fileURLWithPath: biosDirectory).appendingPathComponent(biosEntry?.filename).path
            var error: Error? = nil
            if !fm.fileExists(atPath: biosDirectory) {
                try? fm.createDirectory(atPath: biosDirectory, withIntermediateDirectories: true, attributes: nil)
                if error != nil {
                    DLog("Unable to create BIOS directory %@, %@", biosDirectory, error?.localizedDescription)
                }
            }
            if (try? fm.moveItem(atPath: filePath, toPath: destiaionPath)) == nil {
                if (error as NSError?)?.code == NSFileWriteFileExistsError {
                    DLog("Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, error?.localizedDescription)
                }
            }
            return nil
        }
        if systemsForExtension.count > 1 {
                // Check by MD5
            let fileMD5: String = canidateFile.md5.uppercased()
            var results: [Any]
            for system: String in systemsForExtension {
                var error: Error?
                // TODO: Would be better performance to search EVERY system MD5 in a single query?
                results = (try? self.searchDatabase(usingKey: "romHashMD5", value: fileMD5, systemID: system)) ?? [Any]()
                break
            }
            if results.count != 0 {
                var chosenResult: [AnyHashable: Any]? = nil
                for result: [AnyHashable: Any] in results {
                    if (result["region"] == "USA") {
                        chosenResult = result
                        break
                    }
                }
                if chosenResult == nil {
                    chosenResult = results.first
                }
            }
            subfolderPath = conflictPath()
            isEncounteredConflicts = true
        }
        else {
            systemID = systemsForExtension.first
            subfolderPath = systemToPathMap[systemID]
        }
        if subfolderPath?.count == nil {
            return nil
        }
        var error: Error? = nil
        if (try? fm.createDirectory(atPath: subfolderPath ?? "", withIntermediateDirectories: true, attributes: nil)) == nil {
            DLog("Unable to create %@ - %@", subfolderPath, error?.localizedDescription)
            return nil
        }
        if (try? fm.moveItem(atPath: filePath, toPath: URL(fileURLWithPath: subfolderPath ?? "").appendingPathComponent(filePath.lastPathComponent).path)) == nil {
            if (error as NSError?)?.code == NSFileWriteFileExistsError {
                if (try? fm.removeItem(atPath: filePath)) == nil {
                    DLog("Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, error?.localizedDescription)
                }
            }
            DLog("Unable to move file from %@ to %@ - %@", filePath, subfolderPath, error?.localizedDescription)
            return nil
        }
        if !isEncounteredConflicts {
            newPath = URL(fileURLWithPath: subfolderPath ?? "").appendingPathComponent(filePath.lastPathComponent).path
        }
        return newPath ?? ""
    }

// MARK: - ROM Lookup

    func lookupInfo(for game: PVGame) {
        RomDatabase.sharedInstance.refresh()
        if !game.md5Hash().length() {
            var offset: Int = 0
            if (game.systemIdentifier() == PVNESSystemIdentifier) {
                offset = 16
                // make this better
            }
            let md5Hash: String = FileManager.default.md5ForFile(atPath: URL(fileURLWithPath: documentsPath()).appendingPathComponent(game.romPath()).path, fromOffset: offset)
            RomDatabase.sharedInstance.writeTransactionAndReturnError(nil, {() -> Void in
                game.md5Hash = md5Hash
            })
        }
        var error: Error? = nil
        var results: [Any]? = nil
        if game.md5Hash().length() {
            results = try? self.searchDatabase(usingKey: "romHashMD5", value: game.md5Hash().uppercased(), systemID: game.systemIdentifier())
        }
        if results?.count == nil {
            var fileName: String = game.romPath().lastPathComponent
                // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
            var charSet: CharacterSet? = nil
            var onceToken: Int
            if (onceToken == 0) {
            /* TODO: move below code to a static variable initializer (dispatch_once is deprecated) */
                charSet = CharacterSet.punctuationCharacters
                charSet?.removeCharacters(in: "-+&.'")
            }
        onceToken = 1
            let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: charSet!)
            var gameTitleLen: Int
            if nonCharRange.length > 0 && nonCharRange.location > 1 {
                gameTitleLen = nonCharRange.location - 1
            }
            else {
                gameTitleLen = fileName.count
            }
            fileName = ((fileName as? NSString)?.substring(to: gameTitleLen)) ?? ""
            results = try? self.searchDatabase(usingKey: "romFileName", value: fileName, systemID: game.systemIdentifier())
        }
        if results?.count == nil {
            DLog("Unable to find ROM (%@) in DB", game.romPath())
            RomDatabase.sharedInstance.writeTransactionAndReturnError(nil, {() -> Void in
                game.isRequiresSync = false
            })
            return
        }
        var chosenResult: [AnyHashable: Any]? = nil
        for result: [AnyHashable: Any] in results {
            if (result["region"] == "USA") {
                chosenResult = result
                break
            }
        }
        if chosenResult == nil {
            chosenResult = results?.first
        }
        RomDatabase.sharedInstance.writeTransactionAndReturnError(nil, {() -> Void in
            game.isRequiresSync = false
            if chosenResult["gameTitle"].length() {
                game.title = chosenResult["gameTitle"]
            }
            if chosenResult["boxImageURL"].length() {
                game.originalArtworkURL = chosenResult["boxImageURL"]
            }
        })
    }

    func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [Any] {
        if openVGDB == nil {
            openVGDB = try? OESQLiteDatabase(url: Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite"))
        }
        if openVGDB == nil {
            DLog("Unable to open game database: %@", error?.localizedDescription)
            return nil
        }
        var results: [Any]? = nil
        let exactQuery = "SELECT DISTINCT releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE %@ = '%@'"
        let likeQuery = "SELECT DISTINCT romFileName, releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', regionName as 'region', systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE %@ LIKE \"%%%@%%\" AND systemID=\"%@\" ORDER BY case when %@ LIKE \"%@%%\" then 1 else 0 end DESC"
        var queryString: String? = nil
        let dbSystemID: String = PVEmulatorConfiguration.sharedInstance().databaseID(forSystemID: systemID)
        if (key == "romFileName") {
            queryString = String(format: likeQuery, key, value, dbSystemID, key, value)
        }
        else {
            queryString = String(format: exactQuery, key, value)
        }
        results = try? openVGDB?.executeQuery(queryString)
        return results ?? [Any]()
    }

// MARK: - Utils
    func documentsPath() -> String {
#if TARGET_OS_TV
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
#else
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
#endif
        return paths.first ?? ""
    }

    func romsPath() -> String {
        return URL(fileURLWithPath: documentsPath()).appendingPathComponent("roms").path
    }

    func conflictPath() -> String {
        return URL(fileURLWithPath: documentsPath()).appendingPathComponent("conflict").path
    }

    func updateSystemToPathMap() -> [AnyHashable: Any] {
        var map = [AnyHashable: Any]()
        let emuConfig = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
        for systemID: String in emuConfig.availableSystemIdentifiers() {
            let path: String = URL(fileURLWithPath: documentsPath()).appendingPathComponent(systemID).path
            map[systemID] = path
        }
        return map
    }

    func updateRomToSystemMap() -> [AnyHashable: Any] {
        var map = [AnyHashable: Any]()
        let emuConfig = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
        for systemID: String in emuConfig.availableSystemIdentifiers() {
            for fileExtension: String in emuConfig.fileExtensions(forSystemIdentifier: systemID) {
                var systems = map[fileExtension] as? [AnyHashable]
                if systems.isEmpty {
                    systems = [AnyHashable]()
                }
                systems.append(systemID)
                map[fileExtension] = systems
            }
        }
        return map
    }

    func path(forSystemID systemID: String) -> String {
        return systemToPathMap[systemID]
    }

    func systemIDsForRom(atPath path: String) -> [Any] {
        let fileExtension: String = URL(fileURLWithPath: path).pathExtension.lowercased()
        return romToSystemMap[fileExtension]
    }

    func isCDROM(_ romFile: ImportCanidateFile) -> Bool {
        var isCDROM = false
        let emuConfig = PVEmulatorConfiguration.sharedInstance() as? PVEmulatorConfiguration
        let cdExtensions = emuConfig.supportedCDFileExtensions()
        let `extension`: String = URL(fileURLWithPath: romFile.filePath).pathExtension
        if cdExtensions.contains(`extension`) {
            isCDROM = true
        }
        return isCDROM
    }
}

class ImportCanidateFile: NSObject {
    var filePath = ""
    var md5: String {
        if (hashToken == 0) {
                /* TODO: move below code to a static variable initializer (dispatch_once is deprecated) */
                if self.hastStore == nil {
                    let fm = FileManager.default
                    self.hastStore = fm.md5ForFile(atPath: filePath, fromOffset: 0)
                }
            }
            hashToken = 1
            return hastStore
    }

    private var hastStore = ""
    private var hashToken: Int = 0

    init(filePath: String) {
        super.init()
        
        self.filePath = filePath
    
    }
}

extension PVGameImporter {
    func documentsPath() -> String {
    }
}

extension NSArray {
    func mapObjects(usingBlock block: @escaping (_ obj: Any, _ idx: Int) -> Any) -> [Any] {
        var result = [AnyHashable]() /* TODO: .reserveCapacity(count) */
        (self as NSArray).enumerateObjects({(_ obj: Any, _ idx: Int, _ stop: Bool) -> Void in
            result.append(block(obj, idx))
        })
        return result
    }
}
 
*/
