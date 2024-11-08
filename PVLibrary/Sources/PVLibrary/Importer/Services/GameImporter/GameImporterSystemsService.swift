//
//  GameImporterSystemsService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/7/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVCoreLoader
import AsyncAlgorithms
import PVPlists
import PVLookup
import Systems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm
import Perception
import SwiftUI

protocol GameImporterSystemsServicing {
    func setOpenVGDB(_ vgdb: OpenVGDB)
    func setExtensionsToSystemMapping(_ mapping: [String: [String]])
    func determineSystems(for queueItem: ImportQueueItem) async throws -> [PVSystem]
    func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem]?, romFilename: String) -> [PVGame]?
}

class GameImporterSystemsService : GameImporterSystemsServicing {
    var openVGDB: OpenVGDB?
    /// Map of ROM extensions to their corresponding system identifiers
    var romExtensionToSystemsMap = [String: [String]]()
    
    init() {
        
    }
    
    func setOpenVGDB(_ vgdb: OpenVGDB) {
        openVGDB = vgdb
    }
    
    func setExtensionsToSystemMapping(_ mapping: [String: [String]]) {
        romExtensionToSystemsMap = mapping
    }
    
    /// Determines the system for a given candidate file
    public func determineSystems(for queueItem: ImportQueueItem) async throws -> [PVSystem] {
        guard let md5 = queueItem.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        let fileExtension = queueItem.url.pathExtension.lowercased()
        
        DLOG("Checking MD5: \(md5) for possible BIOS match")
        
        // First check if this is a BIOS file by MD5
        if queueItem.fileType == .bios {
            let biosMatches = PVEmulatorConfiguration.biosEntries.filter("expectedMD5 == %@", md5).map({ $0 })
            var biosSystemMatches:[PVSystem] = []
            for bios in biosMatches {
                biosSystemMatches.append(bios.system)
            }
            DLOG("BIOS Match found, returning \(biosSystemMatches.count) valid systems")
            return biosSystemMatches
        }
        
        //not bios or artwork, start narrowing it down.
        
        if PVEmulatorConfiguration.supportedCDFileExtensions.contains(fileExtension) {
            DLOG("Possible CD ROM - checking valid systems...")
            if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
                DLOG("Possible CD ROM - checking valid systems...found \(systems.count) matches")
                if systems.count == 1 {
                    return [systems[0]]
                } else if systems.count > 1 {
                    return try determineSystemsFromContent(for: queueItem, possibleSystems: systems)
                }
            }
        }
        
        // Try to find system by MD5 using OpenVGDB
        if let results = try openVGDB?.searchDatabase(usingKey: "romHashMD5", value: md5),
           let _ = results.first{
            
            // Get all matching systems
            let matchingSystems = results.compactMap { result -> PVSystem? in
                guard let sysID = (result["systemID"] as? NSNumber) else { return nil }
                return PVEmulatorConfiguration.system(forDatabaseID: sysID.intValue)
            }
            
            //temporarily removing this logic - if we have multiple valid systems, we'll reconcile later.
            
//            if !matchingSystems.isEmpty {
//                // Sort by release year and take the oldest
//                //TODO: consider whether this is a good idea?
//                if let oldestSystem = matchingSystems.sorted(by: { $0.releaseYear < $1.releaseYear }).first {
//                    //TODO: is this the right move, i'm not sure - might be better to consider a conflict here
//                    DLOG("System determined by MD5 match (oldest): \(oldestSystem.name) (\(oldestSystem.releaseYear))")
//                    return [oldestSystem]
//                }
//            }
            
//            // Fallback to original single system match if sorting fails
//            if let system = PVEmulatorConfiguration.system(forIdentifier: String(systemID.intValue)) {
//                DLOG("System determined by MD5 match (fallback): \(system.name)")
//                return [system]
//            }
            return matchingSystems
        }
        
        DLOG("MD5 lookup failed, trying filename matching")
        
        // Try filename matching next
        let fileName = queueItem.url.lastPathComponent
        
        let matchedSystems = await matchSystemByFileName(fileName)
        if !matchedSystems.isEmpty {
            return matchedSystems
        }
            
        // If MD5 lookup fails, try to determine the system based on file extension
        if let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systems.count == 1 {
                return systems
            } else if systems.count > 1 {
                return try determineSystemsFromContent(for: queueItem, possibleSystems: systems)
            }
        }
        
        ELOG("No System matched for this rom: \(fileName)")
        throw GameImporterError.noSystemMatched
    }
    
    /// Determines the system for a given candidate file
    private func determineSystemsFromContent(for queueItem: ImportQueueItem, possibleSystems: [PVSystem]) throws -> [PVSystem] {
        // Implement logic to determine system based on file content or metadata
        // This could involve checking file headers, parsing content, or using a database of known games
        
        let fileName = queueItem.url.deletingPathExtension().lastPathComponent
        
        var matchedSystems:[PVSystem] = []
        for system in possibleSystems {
            do {
                if let results = try openVGDB?.searchDatabase(usingFilename: fileName, systemID: system.openvgDatabaseID),
                   !results.isEmpty {
                    DLOG("System determined by filename match in OpenVGDB: \(system.name)")
                    matchedSystems.append(system)
                }
            } catch {
                ELOG("Error searching OpenVGDB for system \(system.name): \(error.localizedDescription)")
            }
        }
        
        if (!matchedSystems.isEmpty) {
            return matchedSystems
        }
        
        // If we couldn't determine the system, try a more detailed search
        if let fileMD5 = queueItem.md5?.uppercased(), !fileMD5.isEmpty {
            do {
                if let results = try openVGDB?.searchDatabase(usingKey: "romHashMD5", value: fileMD5) {
                    for result in results {
                        if let systemID = result["systemID"] as? Int,
                           let system = possibleSystems.first(where: { $0.openvgDatabaseID == systemID }) {
                            matchedSystems.append(system)
                        }
                    }
                    DLOG("Number of Systems matched by MD5 match in OpenVGDB: \(matchedSystems.count)")
                    return matchedSystems
                }
            } catch {
                //what to do here, since this results in no system?
                ELOG("Error searching OpenVGDB by MD5: \(error.localizedDescription)")
            }
        }
        
        // If still no match, try to determine based on file content
        // This is a placeholder for more advanced content-based detection
        // You might want to implement system-specific logic here
        for system in possibleSystems {
            if doesFileContentMatch(queueItem, forSystem: system) {
                DLOG("System determined by file content match: \(system.name)")
                matchedSystems.append(system)
            }
        }
        
        // If we still couldn't determine the system, return the first possible system as a fallback
        WLOG("Could not determine system from content, return anything we matched so far - if nothing, return all possible systems")
        return matchedSystems.isEmpty ? possibleSystems : matchedSystems
    }
    
    //TODO: is this called?
    /// Retrieves the system ID from the cache for a given ROM candidate
    internal func systemIdFromCache(forQueueItem queueItem: ImportQueueItem) -> String? {
        guard let md5 = queueItem.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        let result = RomDatabase.artMD5DBCache[md5] ?? RomDatabase.getArtCacheByFileName(queueItem.url.lastPathComponent)
        
        if let _res = result,
           let databaseID = _res["systemID"] as? Int,
           let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
            return systemID
        }
        return nil
    }
    
    //TODO: is this called?
    /// Matches a system based on the ROM candidate
    internal func systemId(forQueueItem queueItem: ImportQueueItem) -> String? {
        guard let md5 = queueItem.md5 else {
            ELOG("MD5 was blank")
            return nil
        }
        
        let fileName: String = queueItem.url.lastPathComponent
        
        do {
            if let databaseID = try openVGDB?.system(forRomMD5: md5, or: fileName),
               let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
                return systemID
            } else {
                ILOG("Could't match \(queueItem.url.lastPathComponent) based off of MD5 {\(md5)}")
                return nil
            }
        } catch {
            DLOG("Unable to find rom by MD5: \(error.localizedDescription)")
            return nil
        }
    }
    
    //TODO: is this called?
    internal func determineSystemByMD5(_ queueItem: ImportQueueItem) async throws -> PVSystem? {
        guard let md5 = queueItem.md5?.uppercased() else {
            throw GameImporterError.couldNotCalculateMD5
        }
        
        DLOG("Attempting MD5 lookup for: \(md5)")
        
        // Try to find system by MD5 using OpenVGDB
        if let results = try openVGDB?.searchDatabase(usingKey: "romHashMD5", value: md5),
           let firstResult = results.first,
           let systemID = firstResult["systemID"] as? NSNumber,
           let system = PVEmulatorConfiguration.system(forDatabaseID: systemID.intValue) {
            DLOG("System determined by MD5 match: \(system.name)")
            return system
        }
        
        DLOG("No system found by MD5")
        return nil
    }
    
    //TODO: is this called?
    /// Determines the systems for a given path
    internal func determineSystems(for path: URL, chosenSystem: System?) throws -> [PVSystem] {
        if let chosenSystem = chosenSystem {
            if let system = RomDatabase.systemCache[chosenSystem.identifier] {
                return [system]
            }
        }
        
        let fileExtensionLower = path.pathExtension.lowercased()
        return PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtensionLower) ?? []
    }
    
    /// Finds any current game that could belong to any of the given systems
    func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem]?, romFilename: String) -> [PVGame]? {
        // Check if existing ROM
        
        let allGames = RomDatabase.gamesCache.values.filter ({
            $0.romPath.lowercased() == romFilename.lowercased()
        })
        /*
         let database = RomDatabase.sharedInstance
         
         let predicate = NSPredicate(format: "romPath CONTAINS[c] %@", PVEmulatorConfiguration.stripDiscNames(fromFilename: romFilename))
         let allGames = database.all(PVGame.self, filter: predicate)
         */
        // Optionally filter to specfici systems
        if let systems = systems {
            //let filteredGames = allGames.filter { systems.contains($0.system) }
            var sysIds:[String:Bool]=[:]
            systems.forEach({ sysIds[$0.identifier] = true })
            let filteredGames = allGames.filter { sysIds[$0.systemIdentifier] != nil }
            return filteredGames.isEmpty ? nil : Array(filteredGames)
        } else {
            return allGames.isEmpty ? nil : Array(allGames)
        }
    }
    
    /// Returns the system identifiers for a given ROM path
    public func systemIDsForRom(at path: URL) -> [String]? {
        let fileExtension: String = path.pathExtension.lowercased()
        return romExtensionToSystemsMap[fileExtension]
    }
    
    
    //MARK: Utilities
    
    /// Checks if a file name matches a given system
    private func doesFileNameMatch(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        // Check if the filename contains the system's name or abbreviation
        if lowercasedFileName.contains(system.name.lowercased()) ||
            lowercasedFileName.contains(system.shortName.lowercased()) {
            return true
        }
        
        // Check against known filename patterns for the system
        let patterns = filenamePatterns(forSystem: system)
        for pattern in patterns {
            if lowercasedFileName.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Check against a list of known game titles for the system
        if await isKnownGameTitle(lowercasedFileName, forSystem: system) {
            return true
        }
        
        return false
    }
    
    /// Checks if a file name matches a known game title for a given system
    private func isKnownGameTitle(_ lowercasedFileName: String, forSystem system: PVSystem) async -> Bool {
        do {
            // Remove file extension and common parenthetical information
            let cleanedFileName = cleanFileName(lowercasedFileName)
            
            // Search the database using the cleaned filename
            if let results = try openVGDB?.searchDatabase(usingFilename: cleanedFileName, systemID: system.openvgDatabaseID) {
                // Check if we have any results
                if !results.isEmpty {
                    // Optionally, you can add more strict matching here
                    for result in results {
                        if let gameTitle = result["gameTitle"] as? String,
                           cleanFileName(gameTitle.lowercased()) == cleanedFileName {
                            return true
                        }
                    }
                }
            }
        } catch {
            ELOG("Error searching OpenVGDB for known game title: \(error.localizedDescription)")
        }
        return false
    }
    
    /// Cleans a file name
    private func cleanFileName(_ fileName: String) -> String {
        var cleaned = fileName.lowercased()
        
        // Remove file extension
        if let dotIndex = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<dotIndex])
        }
        
        // Remove common parenthetical information
        let parentheticalPatterns = [
            "\\(.*?\\)",           // Matches anything in parentheses
            "\\[.*?\\]",           // Matches anything in square brackets
            "\\(u\\)",             // Common ROM notation for USA
            "\\(e\\)",             // Common ROM notation for Europe
            "\\(j\\)",             // Common ROM notation for Japan
            "\\(usa\\)",
            "\\(europe\\)",
            "\\(japan\\)",
            "\\(world\\)",
            "v1\\.0",
            "v1\\.1",
            // Add more patterns as needed
        ]
        
        for pattern in parentheticalPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove extra spaces and trim
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Retrieves filename patterns for a given system
    private func filenamePatterns(forSystem system: PVSystem) -> [String] {
        let systemName = system.name.lowercased()
        let shortName = system.shortName.lowercased()
        
        var patterns: [String] = []
        
        // Add pattern for full system name
        patterns.append("\\b\(systemName)\\b")
        
        // Add pattern for short name
        patterns.append("\\b\(shortName)\\b")
        // Add some common variations and abbreviations
        switch system.identifier {
        case "com.provenance.nes":
            patterns.append("\\b(nes|nintendo)\\b")
        case "com.provenance.snes":
            patterns.append("\\b(snes|super\\s*nintendo)\\b")
        case "com.provenance.genesis":
            patterns.append("\\b(genesis|mega\\s*drive|md)\\b")
        case "com.provenance.gba":
            patterns.append("\\b(gba|game\\s*boy\\s*advance)\\b")
        case "com.provenance.n64":
            patterns.append("\\b(n64|nintendo\\s*64)\\b")
        case "com.provenance.psx":
            patterns.append("\\b(psx|playstation|ps1)\\b")
        case "com.provenance.ps2":
            patterns.append("\\b(ps2|playstation\\s*2)\\b")
        case "com.provenance.gb":
            patterns.append("\\b(gb|game\\s*boy)\\b")
        case "com.provenance.3DO":
            patterns.append("\\b(3do|panasonic\\s*3do)\\b")
        case "com.provenance.3ds":
            patterns.append("\\b(3ds|nintendo\\s*3ds)\\b")
        case "com.provenance.2600":
            patterns.append("\\b(2600|atari\\s*2600|vcs)\\b")
        case "com.provenance.5200":
            patterns.append("\\b(5200|atari\\s*5200)\\b")
        case "com.provenance.7800":
            patterns.append("\\b(7800|atari\\s*7800)\\b")
        case "com.provenance.jaguar":
            patterns.append("\\b(jaguar|atari\\s*jaguar)\\b")
        case "com.provenance.colecovision":
            patterns.append("\\b(coleco|colecovision)\\b")
        case "com.provenance.dreamcast":
            patterns.append("\\b(dc|dreamcast|sega\\s*dreamcast)\\b")
        case "com.provenance.ds":
            patterns.append("\\b(nds|nintendo\\s*ds)\\b")
        case "com.provenance.gamegear":
            patterns.append("\\b(gg|game\\s*gear|sega\\s*game\\s*gear)\\b")
        case "com.provenance.gbc":
            patterns.append("\\b(gbc|game\\s*boy\\s*color)\\b")
        case "com.provenance.lynx":
            patterns.append("\\b(lynx|atari\\s*lynx)\\b")
        case "com.provenance.mastersystem":
            patterns.append("\\b(sms|master\\s*system|sega\\s*master\\s*system)\\b")
        case "com.provenance.neogeo":
            patterns.append("\\b(neo\\s*geo|neogeo|neo-geo)\\b")
        case "com.provenance.ngp":
            patterns.append("\\b(ngp|neo\\s*geo\\s*pocket)\\b")
        case "com.provenance.ngpc":
            patterns.append("\\b(ngpc|neo\\s*geo\\s*pocket\\s*color)\\b")
        case "com.provenance.psp":
            patterns.append("\\b(psp|playstation\\s*portable)\\b")
        case "com.provenance.saturn":
            patterns.append("\\b(saturn|sega\\s*saturn)\\b")
        case "com.provenance.32X":
            patterns.append("\\b(32x|sega\\s*32x)\\b")
        case "com.provenance.segacd":
            patterns.append("\\b(scd|sega\\s*cd|mega\\s*cd)\\b")
        case "com.provenance.sg1000":
            patterns.append("\\b(sg1000|sg-1000|sega\\s*1000)\\b")
        case "com.provenance.vb":
            patterns.append("\\b(vb|virtual\\s*boy)\\b")
        case "com.provenance.ws":
            patterns.append("\\b(ws|wonderswan)\\b")
        case "com.provenance.wsc":
            patterns.append("\\b(wsc|wonderswan\\s*color)\\b")
        default:
            // For systems without specific patterns, we'll just use the general ones created above
            break
        }
        
        return patterns
    }
    
    
    
    /// Checks if a file content matches a given system
    private func doesFileContentMatch(_ queueItem: ImportQueueItem, forSystem system: PVSystem) -> Bool {
        // Implement system-specific file content matching logic here
        // This could involve checking file headers, file structure, or other system-specific traits
        // For now, we'll return false as a placeholder
        return false
    }
    
    //TODO: this isn't used remove?
    internal func matchSystemByPartialName(_ fileName: String, possibleSystems: [PVSystem]) -> PVSystem? {
        let cleanedName = fileName.lowercased()
        
        for system in possibleSystems {
            let patterns = filenamePatterns(forSystem: system)
            
            for pattern in patterns {
                if (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
                    .firstMatch(in: cleanedName, options: [], range: NSRange(cleanedName.startIndex..., in: cleanedName)) != nil {
                    DLOG("Found system match by pattern '\(pattern)' for system: \(system.name)")
                    return system
                }
            }
        }
        
        return nil
    }
    
    /// Matches a system based on the file name
    /// Can return multiple possible matches
    internal func matchSystemByFileName(_ fileName: String) async -> [PVSystem] {
//        let systems = PVEmulatorConfiguration.systems
        let lowercasedFileName = fileName.lowercased()
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        var validSystems:[PVSystem] = []
        
        // First, try to match based on file extension
        if let systemsForExtension = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) {
            if systemsForExtension.count == 1 {
                return [systemsForExtension[0]]
            } else if systemsForExtension.count > 1 {
                // If multiple systems match the extension, try to narrow it down
                for system in systemsForExtension {
                    if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
                        validSystems.append(system)
                    }
                }
                return validSystems
            }
        }
        
//        //TODO: consider if this is useful
//        // If extension matching fails, try checking EVERY system
//        for system in systems {
//            var validSystems:[PVSystem] = []
//            for system in systemsForExtension {
//                if await doesFileNameMatch(lowercasedFileName, forSystem: system) {
//                    validSystems.append(system)
//                }
//            }
//            return validSystems
//        }
        
        // If no match found, try querying the OpenVGDB
        do {
            if let results = try openVGDB?.searchDatabase(usingFilename: fileName) {
                for result in results {
                    if let systemID = result["systemID"] as? Int,
                       let system = PVEmulatorConfiguration.system(forDatabaseID: systemID) {
                        validSystems.append(system)
                    }
                }
            }
        } catch {
            ELOG("Error querying OpenVGDB for filename: \(error.localizedDescription)")
        }
        
        return validSystems
    }
}
    
