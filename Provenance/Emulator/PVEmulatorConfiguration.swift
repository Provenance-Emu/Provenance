//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import UIKit

public struct BIOSEntry {
    let systemID : String
    let filename : String
    let desctription : String
    
    var expectedMD5 : String {
        didSet {
            self.expectedMD5 = expectedMD5.uppercased()
        }
    }
    
    let expectedFileSize: UInt
    let optional : Bool

    init(systemID: String, filename: String, desctription: String, expectedMD5: String, expectedFileSize: UInt, optional: Bool = false) {
        self.systemID = systemID
        self.filename = filename
        self.desctription = desctription
        self.expectedMD5 = expectedMD5.uppercased()
        self.expectedFileSize = expectedFileSize
        self.optional = optional
    }
}

public struct SystemDictionaryKeys {
    static let BIOSEntries         = "PVBIOSNames"
    static let ControlLayout       = "PVControlLayout"
    static let DatabaseID          = "PVDatabaseID"
    static let RequiresBIOS        = "PVRequiresBIOS"
    static let ShortSystemName     = "PVShortSystemName"
    static let SupportedExtensions = "PVSupportedExtensions"
    static let SystemIdentifier    = "PVSystemIdentifier"
    static let SystemName          = "PVSystemName"
    static let UsesCDs             = "PVUsesCDs"
    
    struct ControllerLayoutKeys {
        static let Button              = "PVButton"
        static let ButtonGroup         = "PVButtonGroup"
        static let ControlFrame        = "PVControlFrame"
        static let ControlSize         = "PVControlSize"
        static let ControlTitle        = "PVControlTitle"
        static let ControlType         = "PVControlType"
        static let DPad                = "PVDPad"
        static let GroupedButtons      = "PVGroupedButtons"
        static let LeftShoulderButton  = "PVLeftShoulderButton"
        static let RightShoulderButton = "PVRightShoulderButton"
        static let SelectButton        = "PVSelectButton"
        static let StartButton = "PVStartButton"
    }
}

public enum SystemIdentifier : String {
    case Atari2600    = "com.provenance.2600"
    case Atari5200    = "com.provenance.5200"
    case Atari7800    = "com.provenance.7800"
    case FDS          = "com.provenance.fds"
    case GB           = "com.provenance.gb"
    case GBA          = "com.provenance.gba"
    case GBC          = "com.provenance.gbc"
    case GameGear     = "com.provenance.gamegear"
    case Genesis      = "com.provenance.genesis"
    case Lynx         = "com.provenance.lynx"
    case MasterSystem = "com.provenance.mastersystem"
    case N64          = "com.provenance.n64"
    case NES          = "com.provenance.nes"
    case NGP          = "com.provenance.ngp"
    case NGPC         = "com.provenance.ngpc"
    case PCE          = "com.provenance.pce"
    case PCECD        = "com.provenance.pcecd"
    case PCFX         = "com.provenance.pcfx"
    case PSX          = "com.provenance.psx"
    case PokemonMini  = "com.provenance.pokemonmini"
    case SG1000       = "com.provenance.sg1000"
    case SGFX         = "com.provenance.sgfx"
    case SNES         = "com.provenance.snes"
    case Sega32X      = "com.provenance.32X"
    case SegaCD       = "com.provenance.segacd"
    case VirtualBoy   = "com.provenance.vb"
    case WonderSwan   = "com.provenance.ws"
    case WonderSwanColor = "com.provenance.wsc"
    
 
    // MARK: Assistance accessors for properties
    
    var system : SystemDictionary? {
        return PVEmulatorConfiguration.system(forIdentifier: self)
    }
    
    var name : String {
        return PVEmulatorConfiguration.name(forSystemIdentifier: self)!
    }
    
    var shortName : String {
        return PVEmulatorConfiguration.shortName(forSystemIdentifier: self)!
    }
    
    var controllerLayout : [ControllerLayoutDictionary] {
        return PVEmulatorConfiguration.controllerLayout(forSystemIdentifier: self)!
    }
    
    var biosPath : URL {
        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: self)
    }
    
    var requiresBIOS : Bool {
        return PVEmulatorConfiguration.requiresBIOS(forSystemIdentifier: self)
    }

    var biosEntries : [BIOSEntry]? {
        return PVEmulatorConfiguration.biosEntries(forSystemIdentifier: self)
    }
    
    var fileExtensions : [String] {
        return PVEmulatorConfiguration.fileExtensions(forSystemIdentifier: self)!
    }
    
    // TODO: Eventaully wouldl make sense to add batterSavesPath, savesStatePath that
    // are a sub-directory of the current paths. Right now those are just a folder
    // for all games by the game filename - extensions. Even then would be better
    // to use the ROM md5 not the name, since names might have collisions - jm
}

public extension PVGame {
    var system : SystemIdentifier? {
        return SystemIdentifier(rawValue: self.systemIdentifier)
    }
    
    // TODO: See above TODO, this should be based on the ROM systemid/md5
    var batterSavesPath : URL {
        return PVEmulatorConfiguration.batterySavesPath(forGame: self)
    }
    
    var saveStatePath : URL {
        return PVEmulatorConfiguration.saveStatePath(forGame: self)
    }
}

public typealias ControllerLayoutDictionary = [String:Any]
public typealias SystemDictionary = [String:Any]

// Assistance extension to get values out of the plist dictionary systems easier
fileprivate extension Dictionary where Key == String, Value == Any {

    var identifier : String {
        guard let systemID = self[SystemDictionaryKeys.SystemIdentifier] as? String else {
            fatalError("System missing \(SystemDictionaryKeys.SystemIdentifier    ). \(self.debugDescription)")
        }
        return systemID
    }
    
    var name : String {
        guard let name = self[SystemDictionaryKeys.SystemName] as? String else {
            fatalError("System missing \(SystemDictionaryKeys.SystemName). \(self.debugDescription)")
        }
        return name
    }
    
    var shortName : String {
        guard let shortName = self[SystemDictionaryKeys.ShortSystemName] as? String else {
            fatalError("System missing \(SystemDictionaryKeys.ShortSystemName). \(self.debugDescription)")
        }
        return shortName
    }
    
    var databaseId : String {
        guard let databaseId = self[SystemDictionaryKeys.DatabaseID] as? String else {
            fatalError("System missing \(SystemDictionaryKeys.DatabaseID). \(self.debugDescription)")
        }
        return databaseId
    }
    
    var usesCDs : Bool {
        if let usesCDs = self[SystemDictionaryKeys.UsesCDs] as? Bool {
            return usesCDs
        }
        return false
    }
    
    var supportedExtensions : [String] {
        guard let extensions = self[SystemDictionaryKeys.SupportedExtensions] as? [String] else {
            fatalError("System missing \(SystemDictionaryKeys.SupportedExtensions). \(self.debugDescription)")
        }
        return extensions.map { $0.lowercased() }
    }
    
    var controllerLayout : [ControllerLayoutDictionary] {
        guard let controllerLayout = self[SystemDictionaryKeys.ControlLayout] as? [ControllerLayoutDictionary] else {
            fatalError("System missing \(SystemDictionaryKeys.ControlLayout). \(self.debugDescription)")
        }
        return controllerLayout
    }
    
    var bioses : [BIOSEntry]? {
        guard let bs = self[SystemDictionaryKeys.BIOSEntries] as? [[String:Any]] else {
            return nil
        }
        
        return bs.map({ (biosDict : [String:Any]) -> BIOSEntry in
            guard let md5 = biosDict["MD5"] as? String, let name = biosDict["Name"] as? String, let desc = biosDict["Description"] as? String, let size = biosDict["Size"] as? NSNumber else {
                fatalError("BIOS entry missing critical data. \(biosDict.debugDescription)")
            }

            var optional = false
            if let o = biosDict["Name"] as? Bool {
                optional = o
            }
            
            return BIOSEntry(systemID: self.identifier, filename: name, desctription: desc, expectedMD5: md5.uppercased(), expectedFileSize: size.uintValue, optional: optional)
        })
    }
    
    var requiresBIOS : Bool {
        guard let bioses = bioses else { return false }
        // If any entries aren't marked optional, then we need a bios!
        return bioses.contains { !$0.optional }
    }
}

public enum PVEmulatorConfigurationError : Error {
    case systemNotFound
}

@objc
public class PVEmulatorConfiguration : NSObject {

    /*
     TODO: It really makes more sense for each core to have it's own plist file in it's framework
     and iterate those and create SystemConfiguration structions based off of parsing them
     instead of key / value matching a single plist
     */
    fileprivate static let systems : [SystemDictionary] = {
        guard let systemsPlist = Bundle.main.url(forResource: "systems", withExtension: "plist") else {
            fatalError("Missing systems.plist in main bundle")
        }
        
        guard let systemsArray = NSArray(contentsOf: systemsPlist) as? [[String:Any]] else {
            fatalError("Failed to convert systems.plist to array")
        }
        
        return systemsArray
    }()
    
    @objc
    static let availableSystemIdentifiers: [String] = {
        return systems.map({ (system) -> String in
            return system.identifier
        })
    }()
    
    // MARK: ROM IOS etc
    static let supportedROMFileExtensions: [String] = {
        return Array(systems.map({ (system) -> [String] in
            return system.supportedExtensions
        }).joined())
    }()
    
    static let supportedCDFileExtensions: [String] = {
        return Array(systems.flatMap({ (system) -> [String]? in
            guard system.usesCDs else {
                return nil
            }
            
            return system.supportedExtensions
        }).joined())
    }()
    
    static let cdBasedSystemIDs: [String] = {
        return systems.flatMap({ (system) -> String? in
            guard system.usesCDs else {
                return nil
            }
            return system.identifier
        })
    }()
    
    // MARK: BIOS
    static let supportedBIOSFileExtensions: [String] = {
        return biosEntries.map({ (bios) -> String in
            return bios.filename.components(separatedBy: ".").last!.lowercased()
        })
    }()
    
    static let biosEntries: [BIOSEntry] = {
        return Array(systems.flatMap({ (system) -> [BIOSEntry]? in
            return system.bioses
        }).joined())
    }()
    
    // MARK: - Filesystem Helpers
    static let documentsPath: URL = {
        #if os(tvOS)
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        #else
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        #endif

        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()
    
    @objc
    static let romsImportPath: URL = {
        return documentsPath.appendingPathComponent("roms", isDirectory: true)
    }()
    
    static let coverArtPath: URL = {
        return documentsPath.appendingPathComponent("Cover Art", isDirectory: true)
    }()
    
    static let batterySavesPath : URL = {
        return documentsPath.appendingPathComponent("Battery States", isDirectory: true)
    }()
    
    static let saveSavesPath : URL = {
        return documentsPath.appendingPathComponent("Save States", isDirectory: true)
    }()
    
    static let biosesPath : URL = {
        return documentsPath.appendingPathComponent("BIOS", isDirectory: true)
    }()
    
    static let archiveExtensions : [String] = ["zip", "7z"]

    @objc
    class func systemIDWantsStartAndSelectInMenu(_ systemID: String) -> Bool {
        if systemID == SystemIdentifier.PSX.rawValue {
            return true
        }
        return false
    }
    
    class func databaseID(forSystemID systemID: String) -> String? {
        return system(forIdentifier: systemID)?.databaseId
    }
    
    class func systemID(forDatabaseID databaseID: String) -> String? {
        return systems.first{ $0.databaseId == databaseID }?.identifier
    }
    
    @objc
    class func systemIdentifiers(forFileExtension fileExtension: String) -> [String]? {
        return systems.reduce(nil as [String]?, { (systems, system) -> [String]? in
            if system.supportedExtensions.contains(fileExtension.lowercased()) {
                var newSystems : [String] = systems ?? [String]() // Create initial if doesn't exist
                newSystems.append(system.identifier)
                return newSystems
            } else {
                return systems
            }
        })
    }
    
    class func biosEntry(forMD5 md5: String) -> BIOSEntry? {
        return biosEntries.first { $0.expectedMD5 == md5 }
    }
    
    class func biosEntry(forFilename filename: String) -> BIOSEntry? {
        return biosEntries.first { $0.filename == filename }
    }
}

// MARK: - System queries
public extension PVEmulatorConfiguration {
    
    @objc
    class func system(forIdentifier systemID: String) -> SystemDictionary? {
        return systems.first{ $0.identifier == systemID }
    }
    
    @objc
    class func name(forSystemIdentifier systemID: String) -> String? {
        return system(forIdentifier: systemID)?.name
    }
    
    @objc
    class func shortName(forSystemIdentifier systemID: String) -> String? {
        return system(forIdentifier: systemID)?.shortName
    }
    
    @objc
    class func controllerLayout(forSystemIdentifier systemID: String) -> [[String: Any]]? {
        return system(forIdentifier: systemID)?.controllerLayout
    }
    
    @objc
    class func biosPath(forSystemIdentifier systemID: String) -> URL {
        return biosesPath.appendingPathComponent(systemID, isDirectory: true)
    }
    
    class func biosPath(forGame game: PVGame) -> URL {
        return biosPath(forSystemIdentifier: game.systemIdentifier)
    }
    
    class func biosEntries(forSystemIdentifier systemID: String) -> [BIOSEntry]? {
        return system(forIdentifier: systemID)?.bioses
    }
    
    class func requiresBIOS(forSystemIdentifier systemID: String) -> Bool {
        return system(forIdentifier: systemID)?.requiresBIOS ?? false
    }
    
    @objc
    class func fileExtensions(forSystemIdentifier systemID: String) -> [String]? {
        return system(forIdentifier: systemID)?.supportedExtensions
    }
}

// MARK: - System queries Swift specific
public extension PVEmulatorConfiguration {
    class func system(forIdentifier systemID: SystemIdentifier) -> SystemDictionary? {
        return system(forIdentifier: systemID.rawValue)
    }
    
    class func name(forSystemIdentifier systemID: SystemIdentifier) -> String? {
        return name(forSystemIdentifier: systemID.rawValue)
    }
    
    class func shortName(forSystemIdentifier systemID: SystemIdentifier) -> String? {
        return shortName(forSystemIdentifier: systemID.rawValue)
    }
    
    class func controllerLayout(forSystemIdentifier systemID: SystemIdentifier) -> [[String: Any]]? {
        return controllerLayout(forSystemIdentifier: systemID.rawValue)
    }
    
    class func biosPath(forSystemIdentifier systemID: SystemIdentifier) -> URL {
        return biosPath(forSystemIdentifier: systemID.rawValue)
    }
    
    class func biosEntries(forSystemIdentifier systemID: SystemIdentifier) -> [BIOSEntry]? {
        return biosEntries(forSystemIdentifier: systemID.rawValue)
    }
    
    class func requiresBIOS(forSystemIdentifier systemID: SystemIdentifier) -> Bool {
        return requiresBIOS(forSystemIdentifier: systemID.rawValue)
    }

    class func fileExtensions(forSystemIdentifier systemID: SystemIdentifier) -> [String]? {
        return fileExtensions(forSystemIdentifier: systemID.rawValue)
    }
}

// MARK: - Rom queries
public extension PVEmulatorConfiguration {
    
    class func batterySavesPath(forGame game: PVGame) -> URL {
        return batterySavesPath(forROM: game.url)
    }

    class func batterySavesPath(forROM romPath: URL) -> URL {
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let batterySavesDirectory = self.batterySavesPath.appendingPathComponent(romName, isDirectory:true)
        
        do {
            try FileManager.default.createDirectory(at: batterySavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(batterySavesDirectory.path) : \(error.localizedDescription)")
        }
        
        return batterySavesDirectory
    }
    
    class func saveStatePath(forGame game: PVGame) -> URL {
        return saveStatePath(forROM: game.url)
    }
    
    class func saveStatePath(forROM romPath: URL) -> URL {
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let saveSavesPath = self.saveSavesPath.appendingPathComponent(romName, isDirectory:true)
        
        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }
        
        return saveSavesPath
    }
    
    class func path(forGame game :PVGame) -> URL {
        let url = documentsPath.appendingPathComponent(game.romPath, isDirectory: false)
        return url
    }
}

// MARK: m3u
public extension PVEmulatorConfiguration {
    @objc
    class func m3uFile(forGame game: PVGame) -> URL? {
        let gamePath = self.path(forGame: game)
        let gameDirectory = self.romDirectory(forSystemIdentifier: game.system!)
        let filenameWithoutExtension =  gamePath.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "\\ \\(Disc.*\\)", with: "", options: .regularExpression)
        
        do {
            let m3uFile = try FileManager.default.contentsOfDirectory(at: gameDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]).first { (url) -> Bool in
                if url.pathExtension.lowercased() == "m3u" {
                    return url.lastPathComponent.contains(filenameWithoutExtension)
                } else {
                    return false
                }
            }
            
            return m3uFile
        } catch {
            ELOG("Failed looking for .m3u : \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: Helpers
public extension PVEmulatorConfiguration {
    class func createBIOSDirectory(forSystemIdentifier system : SystemIdentifier) {
        let biosPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system)
        let fm = FileManager.default
        if !fm.fileExists(atPath: biosPath.path) {
            do {
                try fm.createDirectory(at: biosPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Error creating BIOS dir: \(error.localizedDescription)")
            }
        }
    }
    
    class func sortImportUURLs(urls : [URL]) -> [URL] {
        let sortedPaths = urls.sorted { (obj1, obj2) -> Bool in
            
            let obj1Filename = obj1.lastPathComponent
            let obj2Filename = obj2.lastPathComponent
            
            let obj1Extension = obj1.pathExtension
            let obj2Extension = obj2.pathExtension
            
            // Check m3u
            if obj1Extension == "m3u" && obj2Extension == "m3u" {
                return obj1Filename > obj2Filename
            }
            else if obj1Extension == "m3u" {
                return true
            }
            else if obj2Extension == "m3u" {
                return false
            }
                // Check cue
            else if obj1Extension == "cue" && obj2Extension == "cue" {
                return obj1Filename > obj2Filename
            }
            else if obj1Extension == "cue" {
                return true
            }
            else if obj2Extension == "cue" {
                return false
            }
                // Standard sort
            else {
                return obj1Filename > obj2Filename
            }
        }
        
        return sortedPaths
    }
}

// MARK: System queries
public extension PVEmulatorConfiguration {
    class func romDirectory(forSystemIdentifier system : SystemIdentifier) -> URL {
        return romDirectory(forSystemIdentifier: system.rawValue)
    }
    
    class func romDirectory(forSystemIdentifier system : String) -> URL {
        return documentsPath.appendingPathComponent(system, isDirectory: true)
    }
}
