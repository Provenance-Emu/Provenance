//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVSupport

public struct SystemDictionaryKeys {
    public static let BIOSEntries         = "PVBIOSNames"
    public static let ControlLayout       = "PVControlLayout"
    public static let DatabaseID          = "PVDatabaseID"
    public static let RequiresBIOS        = "PVRequiresBIOS"
    public static let SystemShortName     = "PVSystemShortName"
    public static let SupportedExtensions = "PVSupportedExtensions"
    public static let SystemIdentifier    = "PVSystemIdentifier"
    public static let SystemName          = "PVSystemName"
	public static let Manufacturer        = "PVManufacturer"
	public static let Bit                 = "PVBit"
	public static let ReleaseYear         = "PVReleaseYear"
    public static let UsesCDs             = "PVUsesCDs"
    public static let SupportsRumble      = "PVSupportsRumble"
    public static let ScreenType          = "PVScreenType"
    public static let Portable            = "PVPortable"

    public struct ControllerLayoutKeys {
        public static let Button              = "PVButton"
        public static let ButtonGroup         = "PVButtonGroup"
        public static let ControlFrame        = "PVControlFrame"
        public static let ControlSize         = "PVControlSize"
        public static let ControlTitle        = "PVControlTitle"
        public static let ControlTint         = "PVControlTint"
        public static let ControlType         = "PVControlType"
        public static let DPad                = "PVDPad"
        public static let GroupedButtons      = "PVGroupedButtons"
        public static let LeftShoulderButton  = "PVLeftShoulderButton"
        public static let RightShoulderButton = "PVRightShoulderButton"
        public static let LeftAnalogButton    = "PVLeftAnalogButton"
        public static let RightAnalogButton   = "PVRightAnalogButton"
        public static let ZTriggerButton      = "PVZTriggerButton"
        public static let SelectButton        = "PVSelectButton"
        public static let StartButton         = "PVStartButton"
    }
}

public enum SystemIdentifier: String {
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
public extension PVSystem {
    public var biosDirectory: URL {
        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: enumValue)
    }

    public var romsDirectory: URL {
        return PVEmulatorConfiguration.romDirectory(forSystemIdentifier: enumValue)
    }
}

// MARK: - PVGame convenience extension
public extension PVGame {
    // TODO: See above TODO, this should be based on the ROM systemid/md5
    public var batterSavesPath: URL {
        return PVEmulatorConfiguration.batterySavesPath(forGame: self)
    }

    public var saveStatePath: URL {
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
    static public let availableSystemIdentifiers: [String] = {
        return systems.map({ (system) -> String in
            return system.identifier
        })
    }()

    // MARK: ROM IOS etc
    static public let supportedROMFileExtensions: [String] = {
        return systems.map({ (system) -> List<String> in
            return system.supportedExtensions
		}).joined().map { return $0 }
    }()

    static public let supportedCDFileExtensions: Set<String> = {
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

    static public var cdBasedSystems: [PVSystem] {
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
    static public let supportedBIOSFileExtensions: [String] = {
        return biosEntries.map({ (bios) -> String in
            return bios.expectedFilename.components(separatedBy: ".").last!.lowercased()
        })
    }()

    static public var biosEntries: Results<PVBIOS> {
        return PVBIOS.all
    }

    // MARK: - Filesystem Helpers
    static public let documentsPath: URL = {
        #if os(tvOS)
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        #else
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        #endif

        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()

    @objc
    static public let romsImportPath: URL = {
        return documentsPath.appendingPathComponent("Imports", isDirectory: true)
    }()

    static public let batterySavesPath: URL = {
        return documentsPath.appendingPathComponent("Battery States", isDirectory: true)
    }()

    static public let saveSavesPath: URL = {
        return documentsPath.appendingPathComponent("Save States", isDirectory: true)
    }()

	static public let screenShotsPath: URL = {
		return documentsPath.appendingPathComponent("Screenshots", isDirectory: true)
	}()

    static public let biosesPath: URL = {
        return documentsPath.appendingPathComponent("BIOS", isDirectory: true)
    }()

    static public let archiveExtensions: [String] = ["zip", "7z", "rar", "7zip", "gz", "gzip"]
    static public let artworkExtensions: [String] = ["png", "jpg", "jpeg"]
	static public let specialExtensions: [String] = ["cue", "m3u", "svs", "mcr", "plist", "ccd", "img", "iso", "sub", "bin"]
	static public let allKnownExtensions: [String] = {
		archiveExtensions + supportedROMFileExtensions + artworkExtensions + supportedBIOSFileExtensions + Array(supportedCDFileExtensions) + specialExtensions
	}()

    @objc
    class public func systemIDWantsStartAndSelectInMenu(_ systemID: String) -> Bool {
        if systemID == SystemIdentifier.PSX.rawValue {
            return true
        }
        return false
    }

    class public func databaseID(forSystemID systemID: String) -> Int? {
        return system(forIdentifier: systemID)?.openvgDatabaseID
    }

    class public func systemID(forDatabaseID databaseID: Int) -> String? {
        return systems.first { $0.openvgDatabaseID == databaseID }?.identifier
    }

    @objc
    class public func systemIdentifiers(forFileExtension fileExtension: String) -> [String]? {
		#if swift(>=4.1)
		return systems(forFileExtension: fileExtension)?.compactMap({ (system) -> String? in
			return system.identifier
		})
		#else
        return systems(forFileExtension: fileExtension)?.flatMap({ (system) -> String? in
            return system.identifier
		})
		#endif
    }

    class public func systems(forFileExtension fileExtension: String) -> [PVSystem]? {
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

    class public func biosEntry(forMD5 md5: String) -> PVBIOS? {
        return RomDatabase.sharedInstance.all(PVBIOS.self, where: "expectedMD5", value: md5).first
    }

    class public func biosEntry(forFilename filename: String) -> PVBIOS? {
        return biosEntries.first { $0.expectedFilename == filename }
    }

	private static let dateFormatter : DateFormatter = {
		let df = DateFormatter()
		df.dateFormat = "YYYY-MM-dd HH:mm:ss"
		return df
	}()

	class public func string(fromDate date : Date) -> String {
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
		self.className = classString

		if let superclass = superclass, ClassInfo.superClassName(forClass: classObject) != superclass {
			return nil
		}

		self.bundle = Bundle(for: classObject)
    }

    public var superclassInfo: ClassInfo? {
		if let superclassObject: AnyClass = class_getSuperclass(self.classObject) {
			return ClassInfo(superclassObject)
		} else {
			return nil
		}
    }

    public var description: String {
        return self.className
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
        return biosesPath.appendingPathComponent(systemID, isDirectory: true)
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
        let batterySavesDirectory = self.batterySavesPath.appendingPathComponent(romName, isDirectory: true)

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
        let saveSavesPath = self.saveSavesPath.appendingPathComponent(romName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }

        return saveSavesPath
    }

	class func screenshotsPath(forGame game: PVGame) -> URL {
		let screenshotsPath = self.screenShotsPath.appendingPathComponent(game.system.shortName, isDirectory: true).appendingPathComponent(game.title, isDirectory: true)

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
        let gamePath = self.path(forGame: game)
        let gameDirectory = self.romDirectory(forSystemIdentifier: game.system.identifier)
        let filenameWithoutExtension =  stripDiscNames(fromFilename: gamePath.deletingPathExtension().lastPathComponent)

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
