//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
@_exported import PVSupport
import RealmSwift
import PVLogging
import PVPlists

@objc
public final class PVEmulatorConfiguration: NSObject {
    /*
     TODO: It really makes more sense for each core to have it's own plist file in it's framework
     and iterate those and create SystemConfiguration structions based off of parsing them
     instead of key / value matching a single plist
     */
    fileprivate static var systems: [PVSystem] {
        return Array(RomDatabase.sharedInstance.all(PVSystem.self))
    }

    @objc
    public static let availableSystemIdentifiers: [String] = {
        systems.map({ (system) -> String in
            system.identifier
        })
    }()

    // MARK: ROM IOS etc

    public static let supportedROMFileExtensions: [String] = {
        systems.map({ (system) -> List<String> in
            system.supportedExtensions
        }).joined().map { $0 }
    }()

    public static let supportedCDFileExtensions: Set<String> = {
        return Set(systems.compactMap({ (system) -> [String]? in
            guard system.usesCDs else {
                return nil
            }

            return Array(system.supportedExtensions)
        }).joined())
    }()

    public static var cdBasedSystems: [PVSystem] {
        return systems.compactMap({ (system) -> PVSystem? in
            guard system.usesCDs else {
                return nil
            }
            return system
        })
    }

    // MARK: BIOS

    public static let supportedBIOSFileExtensions: [String] = {
        biosEntries.map({ (bios) -> String in
            bios.expectedFilename.components(separatedBy: ".").last!.lowercased()
        })
    }()

    public static var biosEntries: Results<PVBIOS> {
        return PVBIOS.all
    }

    // MARK: - Filesystem Helpers

    public static let documentsPath: URL = {
        #if os(tvOS)
            return cachesPath
        #else
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            return URL(fileURLWithPath: paths.first!, isDirectory: true)
        #endif
    }()

    @objc
    public static let cachesPath: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()

    public static func initICloud() {
        DispatchQueue.global(qos: .background).async {
            let dir = PVEmulatorConfiguration.iCloudContainerDirectory
            DLOG("iCloudContainerDirectory: \(String(describing: dir))")
        }
    }

    private
    static var iCloudContainerDirectoryCached: URL? = {
        if Thread.isMainThread {
            var container: URL?
            DispatchQueue.global(qos: .background).sync {
                container = FileManager.default.url(forUbiquityContainerIdentifier: Constants.iCloud.containerIdentifier)
            }
            return container
        } else {
            let container = FileManager.default.url(forUbiquityContainerIdentifier: Constants.iCloud.containerIdentifier)
            return container
        }
    }()

    /// This should be called on a background thread
    static var iCloudContainerDirectory: URL? {
        get {
            return iCloudContainerDirectoryCached
        }
    }

    /// This should be called on a background thread
    public static var iCloudDocumentsDirectory: URL? { get {
        let iCloudSync = Defaults[.iCloudSync]
        
        guard iCloudSync else {
            return nil
        }

        let documentsURL = iCloudContainerDirectory?.appendingPathComponent("Documents")
        if let documentsURL = documentsURL {
            if !FileManager.default.fileExists(atPath: documentsURL.path, isDirectory: nil) {
                do {
                    try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    ELOG("Failed creating dir on iCloud: \(error)")
                }
            }
        }

        return documentsURL
    }}

    public static var supportsICloud: Bool {
        return iCloudContainerDirectory != nil
    }

    /// This should be called on a background thread
    public static var documentsiCloudOrLocalPath: URL { get {
        return iCloudDocumentsDirectory ?? documentsPath
    }}

    public struct Paths {
        public struct Legacy {
            public static var batterySavesPath: URL {
                documentsPath.appendingPathComponent("Battery States", isDirectory: true)
            }

            public static var saveSavesPath: URL {
                documentsPath.appendingPathComponent("Save States", isDirectory: true)
            }

            public static var screenShotsPath: URL {
                documentsPath.appendingPathComponent("Screenshots", isDirectory: true)
            }

            public static var biosesPath: URL {
                documentsPath.appendingPathComponent("BIOS", isDirectory: true)
            }
        }

        public static var romsImportPath: URL {
            return documentsPath.appendingPathComponent("Imports", isDirectory: true)
        }

        /// Should be called on BG Thread, iCloud blocks
        public static var romsPath: URL { get {
            return documentsiCloudOrLocalPath.appendingPathComponent("ROMs", isDirectory: true)
        }}

        /// Should be called on BG Thread, iCloud blocks
        public static var batterySavesPath: URL { get {
            return documentsiCloudOrLocalPath.appendingPathComponent("Battery States", isDirectory: true)
        }}

        /// Should be called on BG Thread, iCloud blocks
        public static var saveSavesPath: URL { get {
            return documentsiCloudOrLocalPath.appendingPathComponent("Save States", isDirectory: true)
        }}

        /// Should be called on BG Thread, iCloud blocks
        public static var screenShotsPath: URL { get {
            return documentsiCloudOrLocalPath.appendingPathComponent("Screenshots", isDirectory: true)
        }}

        /// Should be called on BG Thread, iCloud blocks
        public static var biosesPath: URL { get {
            return documentsiCloudOrLocalPath.appendingPathComponent("BIOS", isDirectory: true)
        }}
    }
    
    public static let archiveExtensions: [String] = ["7z", "gzip", "gz", "rar", "zip", "7zip"]
    public static let artworkExtensions: [String] = ["png", "jpg", "jpeg"]
    public static let specialExtensions: [String] = ["cue", "m3u", "svs", "mcr", "plist", "ccd", "img", "iso", "sub", "bin", "chd"]
    public static let allKnownExtensions: [String] = {
        archiveExtensions + supportedROMFileExtensions + artworkExtensions + supportedBIOSFileExtensions + Array(supportedCDFileExtensions) + specialExtensions
    }()

    @objc
    public class func systemIDWantsStartAndSelectInMenu(_ systemID: String) -> Bool {
        let systems: [String] = [SystemIdentifier.PSX.rawValue, SystemIdentifier.PS2.rawValue, SystemIdentifier.PSP.rawValue]
        if systems.contains(systemID) {
            return true
        }
        return false
    }

    public class func databaseID(forSystemID systemID: String) -> Int? {
        return system(forIdentifier: systemID)?.openvgDatabaseID
    }

    public class func systemID(forDatabaseID databaseID: Int) -> String? {
        return systems.first { $0.openvgDatabaseID == databaseID }?.identifier
    }

    @objc
    public class func systemIdentifiers(forFileExtension fileExtension: String) -> [String]? {
        return systems(forFileExtension: fileExtension)?.compactMap({ (system) -> String? in
            system.identifier
        })
    }

    public class func systems(forFileExtension fileExtension: String) -> [PVSystem]? {
        return systems.reduce(nil as [PVSystem]?, { (systems, system) -> [PVSystem]? in
            if system.supportedExtensions.contains(fileExtension.lowercased()) {
                var newSystems: [PVSystem] = systems ?? [PVSystem]() // Create initial if doesn't exist
                newSystems.append(system)
                return newSystems
            } else {
                return systems
            }
        })
    }
    
    public class func systemsFromCache(forFileExtension fileExtension: String) -> [PVSystem]? {
        let systems = RomDatabase.sharedInstance.getSystemCache().values
        return systems.reduce(nil as [PVSystem]?, { (systems, system) -> [PVSystem]? in
            if system.supportedExtensions.contains(fileExtension.lowercased()) {
                var newSystems: [PVSystem] = systems ?? [PVSystem]() // Create initial if doesn't exist
                newSystems.append(system)
                return newSystems
            } else {
                return systems
            }
        })
    }

    public class func biosEntry(forMD5 md5: String) -> PVBIOS? {
        return RomDatabase.sharedInstance.all(PVBIOS.self, where: "expectedMD5", value: md5).first
    }

    public class func biosEntry(forFilename filename: String) -> PVBIOS? {
        return biosEntries.first { $0.expectedFilename == filename }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return df
    }()

    public class func string(fromDate date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}

// MARK: - System queries

public extension PVEmulatorConfiguration {
    @objc
    class func system(forIdentifier systemID: String) -> PVSystem? {
        let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemID)
        return system
    }

    @objc
    class func name(forSystemIdentifier systemID: String) -> String? {
        return system(forIdentifier: systemID)?.name
    }

    @objc
    class func shortName(forSystemIdentifier systemID: String) -> String? {
        return system(forIdentifier: systemID)?.shortName
    }

    class func controllerLayout(forSystemIdentifier systemID: String) -> [ControlLayoutEntry]? {
        return system(forIdentifier: systemID)?.controllerLayout
    }

    @objc
    class func biosPath(forSystemIdentifier systemID: String) -> URL {
        return Paths.biosesPath.appendingPathComponent(systemID, isDirectory: true)
    }

    class func biosPath(forGame game: PVGame) -> URL {
        return biosPath(forSystemIdentifier: game.systemIdentifier)
    }

    class func biosEntries(forSystemIdentifier systemID: String) -> [PVBIOS]? {
        if let bioses = system(forIdentifier: systemID)?.bioses {
            return Array(bioses)
        } else {
            return nil
        }
    }

    class func requiresBIOS(forSystemIdentifier systemID: String) -> Bool {
        return system(forIdentifier: systemID)?.requiresBIOS ?? false
    }

    @objc
    class func fileExtensions(forSystemIdentifier systemID: String) -> [String]? {
        if let extensions = system(forIdentifier: systemID)?.supportedExtensions {
            return Array(extensions)
        } else {
            return nil
        }
    }
}

// MARK: - System queries Swift specific

public extension PVEmulatorConfiguration {
    class func system(forIdentifier systemID: SystemIdentifier) -> PVSystem? {
        return system(forIdentifier: systemID.rawValue)
    }

    class func name(forSystemIdentifier systemID: SystemIdentifier) -> String? {
        return name(forSystemIdentifier: systemID.rawValue)
    }

    class func shortName(forSystemIdentifier systemID: SystemIdentifier) -> String? {
        return shortName(forSystemIdentifier: systemID.rawValue)
    }

    class func controllerLayout(forSystemIdentifier systemID: SystemIdentifier) -> [ControlLayoutEntry]? {
        return controllerLayout(forSystemIdentifier: systemID.rawValue)
    }

    class func biosPath(forSystemIdentifier systemID: SystemIdentifier) -> URL {
        return biosPath(forSystemIdentifier: systemID.rawValue)
    }

    class func biosEntries(forSystemIdentifier systemID: SystemIdentifier) -> [PVBIOS]? {
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
        let batterySavesDirectory = Paths.batterySavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: Paths.batterySavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(batterySavesDirectory.path) : \(error.localizedDescription)")
        }
        
        return batterySavesDirectory
    }
    
    class func saveStatePath(forGame game: PVGame)  -> URL {
        return saveStatePath(forROM: game.url)
    }
    
    class func saveStatePath(forROM romPath: URL) -> URL {
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let saveSavesPath = Paths.saveSavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }
        
        return saveSavesPath
    }
    
    class func saveStatePath(forROMFilename romName: String) -> URL {
        let saveSavesPath = Paths.saveSavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }
        
        return saveSavesPath
    }
    
    class func screenshotsPath(forGame game: PVGame) -> URL {
        let screenshotsPath = Paths.screenShotsPath.appendingPathComponent(game.system.shortName, isDirectory: true).appendingPathComponent(game.title, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: screenshotsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating screenshots directory: \(screenshotsPath.path) : \(error.localizedDescription)")
        }
        
        return screenshotsPath
    }
    
    class func path(forGame game: PVGame) -> URL {
        return documentsiCloudOrLocalPath.appendingPathComponent(game.systemIdentifier).appendingPathComponent(game.file.url.lastPathComponent)
    }
    class func path(forGame game: PVGame, url:URL) -> URL {
        return documentsiCloudOrLocalPath.appendingPathComponent(game.systemIdentifier).appendingPathComponent(url.lastPathComponent)
    }
}

// MARK: m3u

public extension PVEmulatorConfiguration {
    class func stripDiscNames(fromFilename filename: String) -> String {
        var altName = filename.replacingOccurrences(of: "(Disk|Disc|DISK|DISC|CD|Track|disc|track|cd|disk)[\\s]*[\\d]+", with: "", options: .regularExpression)
        altName = altName.replacingOccurrences(of: "[\\s]*[\\(\\[][\\s]*[\\)\\]]", with: "", options: .regularExpression)
        return altName
    }

    @objc
    class func m3uFile(forGame game: PVGame) -> URL? {
        let gamePath = path(forGame: game)
        return m3uFile(forURL: gamePath, identifier: game.system.identifier)
    }

    @objc
    class func m3uFile(forURL gamePath: URL, identifier: String) -> URL? {
        let gameDirectory = romDirectory(forSystemIdentifier: identifier)
        let filenameWithoutExtension = stripDiscNames(fromFilename: gamePath.deletingPathExtension().lastPathComponent)

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
    class func createBIOSDirectory(forSystemIdentifier system: SystemIdentifier) {
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

    class func cmpSpecialExt(obj1Extension: String, obj2Extension: String) -> Bool {
        if obj1Extension == "m3u" && obj2Extension != "m3u" {
            return obj1Extension > obj2Extension
        } else if obj1Extension == "m3u" {
            return false
        } else if obj2Extension == "m3u" {
            return true
        }
        if artworkExtensions.contains(obj1Extension) {
            return false
        } else if artworkExtensions.contains(obj2Extension) {
            return true
        }
        return obj1Extension > obj2Extension
    }

    class func cmp(obj1: URL, obj2: URL) -> Bool {
        let obj1Filename = obj1.lastPathComponent
        let obj2Filename = obj2.lastPathComponent
        let obj1Extension = obj1.pathExtension.lowercased()
        let obj2Extension = obj2.pathExtension.lowercased()
        let name1=PVEmulatorConfiguration.stripDiscNames(fromFilename: obj1Filename)
        let name2=PVEmulatorConfiguration.stripDiscNames(fromFilename: obj2Filename)
        if name1 == name2 {
             // Standard sort
            if obj1Extension == obj2Extension {
                return obj1Filename < obj2Filename
            }
            return obj1Extension > obj2Extension
        } else {
            return name1 < name2
        }
    }

    class func sortImportURLs(urls: [URL]) -> [URL] {
        var ext:[String:[URL]] = [:]
        // separate array by file extension
        urls.forEach({ (url) in
            if var urls = ext[url.pathExtension.lowercased()] {
                urls.append(url)
                ext[url.pathExtension.lowercased()]=urls
            } else {
                ext[url.pathExtension.lowercased()]=[url]
            }
        })
        // sort
        var sorted: [URL] = []
        ext.keys
            .sorted(by: cmpSpecialExt)
            .forEach {
            if let values = ext[$0] {
                let values = values.sorted { (obj1, obj2) -> Bool in
                    return cmp(obj1: obj1, obj2: obj2)
                }
                sorted.append(contentsOf: values)
                ext[$0] = values
            }
        }
        VLOG(sorted.map { $0.lastPathComponent }.joined(separator: ", "))
        return sorted
    }
}

// MARK: System queries

public extension PVEmulatorConfiguration {
    class func romDirectory(forSystemIdentifier system: SystemIdentifier) -> URL {
        return romDirectory(forSystemIdentifier: system.rawValue)
    }

    class func romDirectory(forSystemIdentifier system: String) -> URL {
        return Paths.romsPath.appendingPathComponent(system, isDirectory: true)
    }
}
