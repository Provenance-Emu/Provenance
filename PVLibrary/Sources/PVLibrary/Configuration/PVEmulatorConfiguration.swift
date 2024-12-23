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
import PVRealm
import PVFileSystem
import PVPrimitives

@objc
public final class PVEmulatorConfiguration: NSObject {

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

    // MARK: BIOS

    public static let supportedBIOSFileExtensions: [String] = {
        biosEntries.map({ (bios) -> String in
            bios.expectedFilename.components(separatedBy: ".").last!.lowercased()
        })
    }()

    public static var biosEntries: Results<PVBIOS> {
        return PVBIOS.all
    }
    
    public static var biosArray: [PVBIOS] {
        return Array(RomDatabase.sharedInstance.all(PVBIOS.self))
    }

    public static func initICloud() {
        DispatchQueue.global(qos: .background).async {
            let dir = URL.iCloudContainerDirectory
            DLOG("iCloudContainerDirectory: \(String(describing: dir))")
        }
    }

    @objc
    public class func systemIDWantsStartAndSelectInMenu(_ systemID: String) -> Bool {
        let systems: [String] = [SystemIdentifier.PSX.rawValue, SystemIdentifier.PS2.rawValue, SystemIdentifier.PSP.rawValue]
        if systems.contains(systemID) {
            return true
        }
        return false
    }

    public class func databaseID(forSystemID systemID: String) -> Int? {
        return (system(forIdentifier: systemID) as System?)?.openvgDatabaseID
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

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return df
    }()

    public class func string(fromDate date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}

// MARK: - Realm queries

public extension PVEmulatorConfiguration {

    @MainActor
    static var pvSystems: Results<PVSystem> = {
        let sortedSystems = RomDatabase.sharedInstance.all(PVSystem.self, sortedByKeyPath: #keyPath(PVSystem.name))
        return sortedSystems
    }()
    
    
    static var systems: [PVSystem] {
        return Array(RomDatabase.sharedInstance.all(PVSystem.self).sorted(by: { $0.name < $1.name }))
    }

    static var cdBasedSystems: [PVSystem] {
        return systems.filter {
            $0.usesCDs
        }
    }

    class func systems(forFileExtension fileExtension: String) -> [PVSystem]? {
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

    class func core(forSystem system: PVSystem) -> [PVCore] {
        system.cores.map { $0 }
    }

    class func games(forSystem system: PVSystem) -> [PVGame] {
        system.games.map { $0 }
    }

    class func cores(forSystem system: any SystemProtocol) -> [PVCore] {
        guard let system = RomDatabase.systemCache[system.identifier] else {
            ELOG("No system cached for id \(system.identifier)")
            return []
        }
        return system.cores.map{ $0 }
    }

    class func games(forSystem system: any SystemProtocol) -> [PVGame] {
        guard let system = RomDatabase.systemCache[system.identifier] else {
            ELOG("No system cached for id \(system.identifier)")
            return []
        }
        return system.games.map(\.self)
    }

    class func gamesCount(forSystem system: any SystemProtocol) -> Int {
        guard let system = RomDatabase.systemCache[system.identifier] else {
            ELOG("No system cached for id \(system.identifier)")
            return 0
        }
        return system.games.count
    }

    class func systemsFromCache(forFileExtension fileExtension: String) -> [PVSystem]? {
        let systems = RomDatabase.systemCache.values
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

    class func biosEntry(forMD5 md5: String) -> PVBIOS? {
        return RomDatabase.sharedInstance.all(PVBIOS.self, where: "expectedMD5", value: md5).first
    }

    class func biosEntry(forFilename filename: String) -> PVBIOS? {
        return biosEntries.first { $0.expectedFilename == filename }
    }
}

// MARK: - System queries

public extension PVEmulatorConfiguration {


    @objc
    class func system(forDatabaseID databaseID : Int) -> PVSystem? {
        guard let systemID = systemID(forDatabaseID: databaseID) else { return nil }
        let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemID)
        return system
    }
    
    class func system(forDatabaseID databaseID : Int) -> System? {
        let pvsystem: PVSystem? = system(forDatabaseID: databaseID)
        return pvsystem?.asDomain()
    }

    @objc
    class func system(forIdentifier systemID: String) -> PVSystem? {
        let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: systemID)
        return system
    }
    
    class func system(forIdentifier systemID: String) -> System? {
        let pvsystem: PVSystem? = system(forIdentifier: systemID)
        return pvsystem?.asDomain()
    }

    @objc
    class func name(forSystemIdentifier systemID: String) -> String? {
        return (system(forIdentifier: systemID) as System?)?.name
    }

    @objc
    class func shortName(forSystemIdentifier systemID: String) -> String? {
        return (system(forIdentifier: systemID) as System?)?.shortName
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
        return (system(forIdentifier: systemID) as System?)?.requiresBIOS ?? false
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
        return Paths.batterySavesPath(forROM: game.url)
    }

    class func saveStatePath(forGame game: PVGame)  -> URL {
        return Paths.saveStatePath(forROM: game.url)
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
        return
        PVEmulatorConfiguration.romDirectory(forSystemIdentifier: game.systemIdentifier).appendingPathComponent(game.file.url.lastPathComponent)
    }
    class func path(forGame game: PVGame, url:URL) -> URL {
        return PVEmulatorConfiguration.romDirectory(forSystemIdentifier: game.systemIdentifier).appendingPathComponent(url.lastPathComponent)
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
}

// MARK: System queries
import PVSystems

public extension PVEmulatorConfiguration {
    class func romDirectory(forSystemIdentifier system: SystemIdentifier) -> URL {
        return romDirectory(forSystemIdentifier: system.rawValue)
    }

    class func romDirectory(forSystemIdentifier system: String) -> URL {
        return Paths.romsPath.appendingPathComponent(system, isDirectory: true)
    }
}

public extension PVEmulatorConfiguration {
    enum BIOSError: Error {
        case unknownBIOSFile
        case invalidMD5Hash
        case systemNotFound
        case biosAlreadyExists
    }

    static func validateAndImportBIOS(at url: URL) async throws {
        let fileName = url.lastPathComponent
        let fileData = try Data(contentsOf: url)
        let md5Hash = fileData.md5

        // First check if we have a known BIOS entry for this filename
        let database = RomDatabase.sharedInstance
        if let existingBIOS = database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: fileName) {
            // Validate MD5
            if existingBIOS.expectedMD5 != md5Hash {
                throw BIOSError.invalidMD5Hash
            }

            // Move file to correct location if needed
            if let system = existingBIOS.system {
                let destinationPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
                    .appendingPathComponent(fileName)

                if url.path != destinationPath.path {
                    try FileManager.default.moveItem(at: url, to: destinationPath)
                }
            }

            return // BIOS already exists and is valid
        }

        // If no existing entry, look for matching BIOS definition
        guard let biosEntry = biosEntry(forFilename: fileName) else {
            throw BIOSError.unknownBIOSFile
        }

        guard biosEntry.expectedMD5 == md5Hash else {
            throw BIOSError.invalidMD5Hash
        }

        guard let system = biosEntry.system else {
            throw BIOSError.systemNotFound
        }

        // Create new BIOS entry
        let newBIOS = PVBIOS(withSystem: system,
                            descriptionText: biosEntry.descriptionText,
                            optional: biosEntry.optional,
                            expectedMD5: biosEntry.expectedMD5,
                            expectedSize: biosEntry.expectedSize,
                            expectedFilename: biosEntry.expectedFilename)

        try await database.addAsync(newBIOS)
        RomDatabase.reloadBIOSCache()

        // Move file to correct system BIOS directory
        let destinationPath = PVEmulatorConfiguration.biosPath(forSystemIdentifier: system.identifier)
            .appendingPathComponent(fileName)
        try FileManager.default.moveItem(at: url, to: destinationPath)
    }
}
