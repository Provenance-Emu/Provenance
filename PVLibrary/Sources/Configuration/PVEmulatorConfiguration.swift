//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift

public struct SystemDictionaryKeys {
    public static let BIOSEntries = "PVBIOSNames"
    public static let ControlLayout = "PVControlLayout"
    public static let DatabaseID = "PVDatabaseID"
    public static let RequiresBIOS = "PVRequiresBIOS"
    public static let SystemShortName = "PVSystemShortName"
    public static let SupportedExtensions = "PVSupportedExtensions"
    public static let SystemIdentifier = "PVSystemIdentifier"
    public static let SystemName = "PVSystemName"
    public static let Manufacturer = "PVManufacturer"
    public static let Bit = "PVBit"
    public static let ReleaseYear = "PVReleaseYear"
    public static let UsesCDs = "PVUsesCDs"
    public static let SupportsRumble = "PVSupportsRumble"
    public static let ScreenType = "PVScreenType"
    public static let Portable = "PVPortable"

    public struct ControllerLayoutKeys {
        public static let Button = "PVButton"
        public static let ButtonGroup = "PVButtonGroup"
        public static let ControlFrame = "PVControlFrame"
        public static let ControlSize = "PVControlSize"
        public static let ControlTitle = "PVControlTitle"
        public static let ControlTint = "PVControlTint"
        public static let ControlType = "PVControlType"
        public static let DPad = "PVDPad"
        public static let GroupedButtons = "PVGroupedButtons"
        public static let LeftShoulderButton = "PVLeftShoulderButton"
        public static let RightShoulderButton = "PVRightShoulderButton"
        public static let LeftAnalogButton = "PVLeftAnalogButton"
        public static let RightAnalogButton = "PVRightAnalogButton"
        public static let ZTriggerButton = "PVZTriggerButton"
        public static let SelectButton = "PVSelectButton"
        public static let StartButton = "PVStartButton"
    }
}

public enum SystemIdentifier: String {
    case Atari2600 = "com.provenance.2600"
    case Atari5200 = "com.provenance.5200"
    case Atari7800 = "com.provenance.7800"
    case AtariJaguar = "com.provenance.jaguar"
    case Dreamcast = "com.provenance.dreamcast"
    case FDS = "com.provenance.fds"
    case GB = "com.provenance.gb"
    case GBA = "com.provenance.gba"
    case GBC = "com.provenance.gbc"
    case GameGear = "com.provenance.gamegear"
    case Genesis = "com.provenance.genesis"
    case Lynx = "com.provenance.lynx"
    case MasterSystem = "com.provenance.mastersystem"
    case N64 = "com.provenance.n64"
    case NES = "com.provenance.nes"
    case NGP = "com.provenance.ngp"
    case NGPC = "com.provenance.ngpc"
    case PCE = "com.provenance.pce"
    case PCECD = "com.provenance.pcecd"
    case PCFX = "com.provenance.pcfx"
    case PSX = "com.provenance.psx"
    case PokemonMini = "com.provenance.pokemonmini"
    case Saturn = "com.provenance.saturn"
    case SG1000 = "com.provenance.sg1000"
    case SGFX = "com.provenance.sgfx"
    case SNES = "com.provenance.snes"
    case Sega32X = "com.provenance.32X"
    case SegaCD = "com.provenance.segacd"
    case VirtualBoy = "com.provenance.vb"
    case WonderSwan = "com.provenance.ws"
    case WonderSwanColor = "com.provenance.wsc"
    case Unknown

    // MARK: Assistance accessors for properties

    public var system: PVSystem? {
        return PVEmulatorConfiguration.system(forIdentifier: self)
    }

//    var name : String {
//        return PVEmulatorConfiguration.name(forSystemIdentifier: self)!
//    }
//
//    var shortName : String {
//        return PVEmulatorConfiguration.shortName(forSystemIdentifier: self)!
//    }
//
//    var controllerLayout : [ControlLayoutEntry] {
//        return PVEmulatorConfiguration.controllerLayout(forSystemIdentifier: self)!
//    }
//
//    var biosPath : URL {
//        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: self)
//    }
//
//    var requiresBIOS : Bool {
//        return PVEmulatorConfiguration.requiresBIOS(forSystemIdentifier: self)
//    }
//
//    var biosEntries : [PVBIOS]? {
//        return PVEmulatorConfiguration.biosEntries(forSystemIdentifier: self)
//    }
//
//    var fileExtensions : [String] {
//        return PVEmulatorConfiguration.fileExtensions(forSystemIdentifier: self)!
//    }

    // TODO: Eventaully wouldl make sense to add batterySavesPath, savesStatePath that
    // are a sub-directory of the current paths. Right now those are just a folder
    // for all games by the game filename - extensions. Even then would be better
    // to use the ROM md5 not the name, since names might have collisions - jm
}

// MARK: - PVSystem convenience extension

public extension SystemProtocol {
    var biosDirectory: URL {
        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: identifier)
    }

    var romsDirectory: URL {
        return PVEmulatorConfiguration.romDirectory(forSystemIdentifier: identifier)
    }
}

// MARK: - PVGame convenience extension

public extension PVGame {
    // TODO: See above TODO, this should be based on the ROM systemid/md5
    var batterSavesPath: URL {
        return PVEmulatorConfiguration.batterySavesPath(forGame: self)
    }

    var saveStatePath: URL {
        return PVEmulatorConfiguration.saveStatePath(forGame: self)
    }
}

public enum PVEmulatorConfigurationError: Error {
    case systemNotFound
}

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
        #if swift(>=4.1)
            return Set(systems.compactMap({ (system) -> [String]? in
                guard system.usesCDs else {
                    return nil
                }

                return Array(system.supportedExtensions)
            }).joined())
        #else
            return Set(systems.flatMap({ (system) -> [String]? in
                guard system.usesCDs else {
                    return nil
                }

                return Array(system.supportedExtensions)
            }).joined())
        #endif
    }()

    public static var cdBasedSystems: [PVSystem] {
        #if swift(>=4.1)
            return systems.compactMap({ (system) -> PVSystem? in
                guard system.usesCDs else {
                    return nil
                }
                return system
            })
        #else
            return systems.flatMap({ (system) -> PVSystem? in
                guard system.usesCDs else {
                    return nil
                }
                return system
            })
        #endif
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

    public static let cachesPath: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()

    /// This should be called on a background thread
    static var iCloudContainerDirectory: URL? {
        if Thread.isMainThread {
            WLOG("Warning, this should only be called on background threads.")
        }
        return FileManager.default.url(forUbiquityContainerIdentifier: Constants.iCloud.containerIdentifier)
    }

    /// This should be called on a background thread
    public static var iCloudDocumentsDirectory: URL? {
        guard PVSettingsModel.shared.debugOptions.iCloudSync else {
            return nil
        }

        let documentsURL = iCloudContainerDirectory?.appendingPathComponent("Documents")
        if let documentsURL = documentsURL {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Failed creating dir on iCloud: \(error)")
            }
        }
        return documentsURL
    }

    public static var supportsICloud: Bool {
        return iCloudContainerDirectory != nil
    }

    /// This should be called on a background thread
    public static var documentsiCloudOrLocalPath: URL {
        return iCloudDocumentsDirectory ?? documentsPath
    }

    public struct Paths {
        public struct Legacy {
            public static let batterySavesPath: URL = {
                documentsPath.appendingPathComponent("Battery States", isDirectory: true)
            }()

            public static let saveSavesPath: URL = {
                documentsPath.appendingPathComponent("Save States", isDirectory: true)
            }()

            public static let screenShotsPath: URL = {
                documentsPath.appendingPathComponent("Screenshots", isDirectory: true)
            }()

            public static let biosesPath: URL = {
                documentsPath.appendingPathComponent("BIOS", isDirectory: true)
            }()
        }

        public static var romsImportPath: URL {
            return documentsPath.appendingPathComponent("Imports", isDirectory: true)
        }

        /// Should be called on BG Thread, iCloud blocks
        public static var batterySavesPath: URL {
            return documentsiCloudOrLocalPath.appendingPathComponent("Battery States", isDirectory: true)
        }

        /// Should be called on BG Thread, iCloud blocks
        public static var saveSavesPath: URL {
            return documentsiCloudOrLocalPath.appendingPathComponent("Save States", isDirectory: true)
        }

        /// Should be called on BG Thread, iCloud blocks
        public static var screenShotsPath: URL {
            return documentsiCloudOrLocalPath.appendingPathComponent("Screenshots", isDirectory: true)
        }

        /// Should be called on BG Thread, iCloud blocks
        public static var biosesPath: URL {
            return documentsiCloudOrLocalPath.appendingPathComponent("BIOS", isDirectory: true)
        }
    }

    public static let archiveExtensions: [String] = ["zip", "7z", "rar", "7zip", "gz", "gzip"]
    public static let artworkExtensions: [String] = ["png", "jpg", "jpeg"]
    public static let specialExtensions: [String] = ["cue", "m3u", "svs", "mcr", "plist", "ccd", "img", "iso", "sub", "bin"]
    public static let allKnownExtensions: [String] = {
        archiveExtensions + supportedROMFileExtensions + artworkExtensions + supportedBIOSFileExtensions + Array(supportedCDFileExtensions) + specialExtensions
    }()

    @objc
    public class func systemIDWantsStartAndSelectInMenu(_ systemID: String) -> Bool {
        if systemID == SystemIdentifier.PSX.rawValue {
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
        #if swift(>=4.1)
            return systems(forFileExtension: fileExtension)?.compactMap({ (system) -> String? in
                system.identifier
            })
        #else
            return systems(forFileExtension: fileExtension)?.flatMap({ (system) -> String? in
                system.identifier
            })
        #endif
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

public struct ClassInfo: CustomStringConvertible, Equatable {
    public let classObject: AnyClass
    public let className: String
    public let bundle: Bundle

    public init?(_ classObject: AnyClass?, withSuperclass superclass: String? = nil) {
        guard let classObject = classObject else { return nil }

        self.classObject = classObject

        let cName = class_getName(classObject)
        let classString = String(cString: cName)
        className = classString

        if let superclass = superclass, ClassInfo.superClassName(forClass: classObject) != superclass {
            return nil
        }

        bundle = Bundle(for: classObject)
    }

    public var superclassInfo: ClassInfo? {
        if let superclassObject: AnyClass = class_getSuperclass(self.classObject) {
            return ClassInfo(superclassObject)
        } else {
            return nil
        }
    }

    public var description: String {
        return className
    }

    public static func == (lhs: ClassInfo, rhs: ClassInfo) -> Bool {
        return lhs.className == rhs.className
    }

    static func superClassName(forClass c: AnyClass) -> String? {
        guard let superClass = class_getSuperclass(c) else {
            return nil
        }
        let cName = class_getName(superClass)
        let classString = String(cString: cName)
        return classString
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

    class func saveStatePath(forGame game: PVGame) -> URL {
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
        return game.file.url
    }
}

// MARK: m3u

public extension PVEmulatorConfiguration {
    class func stripDiscNames(fromFilename filename: String) -> String {
        return filename.replacingOccurrences(of: "\\ \\(Disc.*\\)", with: "", options: .regularExpression)
    }

    @objc
    class func m3uFile(forGame game: PVGame) -> URL? {
        let gamePath = path(forGame: game)
        let gameDirectory = romDirectory(forSystemIdentifier: game.system.identifier)
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

    class func sortImportURLs(urls: [URL]) -> [URL] {
        let sortedPaths = urls.sorted { (obj1, obj2) -> Bool in

            let obj1Filename = obj1.lastPathComponent
            let obj2Filename = obj2.lastPathComponent

            let obj1Extension = obj1.pathExtension.lowercased()
            let obj2Extension = obj2.pathExtension.lowercased()

            // Check m3u, put last
            if obj1Extension == "m3u" && obj2Extension != "m3u" {
                return obj1Filename > obj2Filename
            } else if obj1Extension == "m3u" {
                return false
            } else if obj2Extension == "m3u" {
                return true
            } // Check cue/ccd
            else if (obj1Extension == "cue" && obj2Extension != "cue") || (obj1Extension == "ccd" && obj2Extension != "ccd") {
                return obj1Filename < obj2Filename
            } else if obj1Extension == "cue" || obj1Extension == "ccd" {
                return true
            } else if obj2Extension == "cue" || obj2Extension == "ccd" {
                return false
            } // Check if image, put last
            else if artworkExtensions.contains(obj1Extension) {
                return false
            } else if artworkExtensions.contains(obj2Extension) {
                return true
            } // Standard sort
            else {
                return obj1Filename > obj2Filename
            }
        }

        return sortedPaths
    }
}

// MARK: System queries

public extension PVEmulatorConfiguration {
    class func romDirectory(forSystemIdentifier system: SystemIdentifier) -> URL {
        return romDirectory(forSystemIdentifier: system.rawValue)
    }

    class func romDirectory(forSystemIdentifier system: String) -> URL {
        return documentsPath.appendingPathComponent(system, isDirectory: true)
    }
}

// MARK: Move legacy files

public extension PVEmulatorConfiguration {
    class func moveLegacyPaths() {
        if documentsPath != documentsiCloudOrLocalPath {
            let fm = FileManager.default

            // TODO: Update PVGames and PVSaves for new paths for screenshots and saves

            ILOG("Looking up legecy saves")
            if let saves = try? fm.contentsOfDirectory(at: Paths.Legacy.saveSavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !saves.isEmpty {
                ILOG("Found (\(saves.count)) saves in old path")

                saves.forEach {
                    let newPath = Paths.saveSavesPath.appendingPathComponent($0.lastPathComponent)
                    do {
                        try fm.moveItem(at: $0, to: newPath)
                    } catch {
                        ELOG("\(error)")
                    }
                }
                // TODO: Remove old directory?
            }

            ILOG("Looking up legecy bios")
            if let bioses = try? fm.contentsOfDirectory(at: Paths.Legacy.biosesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !bioses.isEmpty {
                ILOG("Found (\(bioses.count)) BIOSes in old path")

                bioses.forEach {
                    let newPath = Paths.biosesPath.appendingPathComponent($0.lastPathComponent)
                    do {
                        try fm.moveItem(at: $0, to: newPath)
                    } catch {
                        ELOG("\(error)")
                    }
                }
            }

            ILOG("Looking up legecy screenshots")
            if let screenshots = try? fm.contentsOfDirectory(at: Paths.Legacy.screenShotsPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !screenshots.isEmpty {
                ILOG("Found (\(screenshots.count)) Screenshots in old path")

                screenshots.forEach {
                    let newPath = Paths.screenShotsPath.appendingPathComponent($0.lastPathComponent)
                    do {
                        try fm.moveItem(at: $0, to: newPath)
                    } catch {
                        ELOG("\(error)")
                    }
                }
            }

            ILOG("Looking up legecy battery saves")
            if let batterySaves = try? fm.contentsOfDirectory(at: Paths.Legacy.batterySavesPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles), !batterySaves.isEmpty {
                ILOG("Found (\(batterySaves.count)) Battery Saves in old path")

                batterySaves.forEach {
                    let newPath = Paths.batterySavesPath.appendingPathComponent($0.lastPathComponent)
                    do {
                        try fm.moveItem(at: $0, to: newPath)
                    } catch {
                        ELOG("\(error)")
                    }
                }
            }
        }
    }
}
