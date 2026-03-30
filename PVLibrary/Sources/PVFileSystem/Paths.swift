//
//  Paths.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import Foundation
import PVPlists
import PVLogging
import PVSettings
import PVSystems
import PVPrimitives
import Defaults

public let UbiquityIdentityTokenKey = (Bundle.main.bundleIdentifier ?? "org.provenance-emu.provenance")  + ".UbiquityIdentityToken"
public let PVAppGroupId = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String ?? "group.org.provenance-emu.provenance"

    // MARK: - Filesystem Helpers
public extension URL {
    static var USE_APP_GROUPS: Bool {
        return Defaults[.useAppGroups]
    }
    
    static let documentsPath: URL = {
#if os(tvOS)
        return cachesPath
#else
        if USE_APP_GROUPS {
            return documentsPathAppGroup ?? documentsPathLocal
        } else {
            return documentsPathLocal
        }
#endif
    }()
    
    static let cachesPath: URL = {
        #if os(tvOS)
        return cachesPathLocal
        #else
        if USE_APP_GROUPS {
            return cachesPathAppGroup ?? cachesPathLocal
        } else {
            return cachesPathLocal
        }
        #endif
    }()
    
    static let cachesPathLocal: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        
        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()
    
    static let cachesPathAppGroup: URL? = {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return nil
        }
        
        return groupURL.appendingPathComponent("Caches/")
    }()
    
    static let documentsPathAppGroup: URL? = {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
            return nil
        }
                
        return groupURL.appendingPathComponent("Documents/")
    }()
    
    static let documentsPathLocal: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths.first!, isDirectory: true)
    }()
}

@objc public extension NSURL {
    @objc static let documentsPath: NSURL = URL.documentsPath as NSURL
    @objc static let cachesPath: NSURL = URL.cachesPath as NSURL
}

public struct Paths {
    public struct Legacy {
        public static var batterySavesPath: URL {
            URL.documentsPath.appendingPathComponent("Battery States", isDirectory: true)
        }

        public static var saveSavesPath: URL {
            URL.documentsPath.appendingPathComponent("Save States", isDirectory: true)
        }

        public static var screenShotsPath: URL {
            URL.documentsPath.appendingPathComponent("Screenshots", isDirectory: true)
        }

        public static var biosesPath: URL {
            URL.documentsPath.appendingPathComponent("BIOS", isDirectory: true)
        }
    }

    public static var romsImportPath: URL {
        return URL.documentsPath.appendingPathComponent("Imports", isDirectory: true)
    }

    /// Should be called on BG Thread, iCloud blocks
    public static var romsPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("ROMs", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var batterySavesPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("Battery States", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var saveSavesPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("Save States", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var screenShotsPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("Screenshots", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var biosesPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("BIOS", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var cheatsPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("Cheats", isDirectory: true)
    }}

    /// Should be called on BG Thread, iCloud blocks
    public static var patchesPath: URL { get {
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("Patches", isDirectory: true)
    }}

    /// Root `System/` directory for per-console system files (BIOS, firmware, fonts, etc.)
    ///
    /// Structured as `Documents/System/<SystemName>/` on iOS/macOS and
    /// `Library/Caches/System/<SystemName>/` on tvOS (App Store guidelines prohibit
    /// using `Documents` on tvOS).
    ///
    /// Example children:
    /// - `System/PSP/`   — PPSSPP flash0 fonts and MemStick data
    /// - `System/NDS/`   — Nintendo DS firmware (nds_bios_arm7.bin, etc.)
    /// - `System/3DS/`   — Citra/Lime3DS system files
    ///
    /// **tvOS note:** The OS may purge `Caches` at any time.
    /// - Bundle-derived assets (e.g. PPSSPP flash0 fonts) are re-seeded from the app bundle
    ///   on every core launch — no special recovery needed for those.
    /// - User-placed firmware/BIOS files are backed up to CloudKit by `CloudKitBIOSSyncer`,
    ///   which covers the directories listed in `CloudKitBIOSSyncer.systemDirectoriesToSync`
    ///   (PSP, DC, AtariST, Saturn). See #3582.
    ///
    /// Part of Epic #2725 — future UI will let users manage these directories.
    ///
    /// Should be called on BG Thread (iCloud blocks).
    public static var systemPath: URL { get {
#if os(tvOS)
        // tvOS must use Caches — Documents is not permitted by App Store guidelines.
        return URL.cachesPath.appendingPathComponent("System", isDirectory: true)
#else
        return URL.documentsiCloudOrLocalPath.appendingPathComponent("System", isDirectory: true)
#endif
    }}

    /// Returns the system-specific path for a given short name (e.g. "PSP", "NDS").
    /// Creates the directory if it does not exist.
    /// Should be called on BG Thread (iCloud blocks).
    public static func systemPath(forSystemName name: String) -> URL {
        let path = systemPath.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating system directory at \(path.path): \(error.localizedDescription)")
        }
        return path
    }

    /// Returns the system-specific path for a `SystemIdentifier`, or `nil` if none is defined.
    /// Creates the directory if it does not exist.
    /// Should be called on BG Thread (iCloud blocks).
    public static func systemPath(forSystem system: SystemIdentifier) -> URL? {
        guard let name = system.systemDirectoryName else { return nil }
        return systemPath(forSystemName: name)
    }

    /// Returns the system-specific path for a system identifier string, or `nil` if none is defined.
    /// Creates the directory if it does not exist.
    /// Should be called on BG Thread (iCloud blocks).
    public static func systemPath(forSystemIdentifier identifier: String) -> URL? {
        guard let system = SystemIdentifier(rawValue: identifier) else { return nil }
        return systemPath(forSystem: system)
    }
}

public extension Paths {
    static func batterySavesPath(forROM romPath: URL?) -> URL {
        guard let romPath = romPath else {
            return Paths.batterySavesPath.appendingPathComponent("NULL", isDirectory: true)
        }
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let batterySavesDirectory = Paths.batterySavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: Paths.batterySavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(batterySavesDirectory.path) : \(error.localizedDescription)")
        }
        
        return batterySavesDirectory
    }
    
    static func saveStatePath(forROM romPath: URL?) -> URL {
        guard let romPath = romPath else {
            return Paths.saveSavesPath.appendingPathComponent("NULL", isDirectory: true)
        }
        
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let saveSavesPath = Paths.saveSavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }
        
        return saveSavesPath
    }
    
    static func saveStatePath(forROMFilename romName: String) -> URL {
        let saveSavesPath = Paths.saveSavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: saveSavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(saveSavesPath.path) : \(error.localizedDescription)")
        }
        
        return saveSavesPath
    }
    
    static func cheatsPath(forROM romPath: URL?) -> URL {
        guard let romPath = romPath else {
            return Paths.cheatsPath.appendingPathComponent("NULL", isDirectory: true)
        }

        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let cheatsDirectory = Paths.cheatsPath.appendingPathComponent(romName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: cheatsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating cheats directory: \(cheatsDirectory.path) : \(error.localizedDescription)")
        }

        return cheatsDirectory
    }

    static func cheatsPath(forROMFilename romName: String) -> URL {
        let cheatsDirectory = Paths.cheatsPath.appendingPathComponent(romName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: cheatsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating cheats directory: \(cheatsDirectory.path) : \(error.localizedDescription)")
        }

        return cheatsDirectory
    }

    static func romsPath(forSystemIdentifier systemIdentifier: String) -> URL {
        return Paths.romsPath.appendingPathComponent(systemIdentifier, isDirectory: true)
    }
    
    static func romsPath(forSystemIdentifier systemIdentifier: SystemIdentifier) -> URL {
        return Paths.romsPath.appendingPathComponent(systemIdentifier.rawValue, isDirectory: true)
    }
}

public extension URL {
    var batterySavesPath: URL  { return Paths.batterySavesPath(forROM: self) }
    var saveStatePath: URL { return Paths.saveStatePath(forROM: self) }
    var cheatsPath: URL { return Paths.cheatsPath(forROM: self) }
}

public extension String {
    var saveStatePath: URL { return Paths.saveStatePath(forROMFilename: self) }
    var cheatsPath: URL { return Paths.cheatsPath(forROMFilename: self) }
}
