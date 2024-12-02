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
}

public extension Paths {
    static func batterySavesPath(forROM romPath: URL) -> URL {
        let romName: String = romPath.deletingPathExtension().lastPathComponent
        let batterySavesDirectory = Paths.batterySavesPath.appendingPathComponent(romName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: Paths.batterySavesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ELOG("Error creating save state directory: \(batterySavesDirectory.path) : \(error.localizedDescription)")
        }
        
        return batterySavesDirectory
    }
    
    static func saveStatePath(forROM romPath: URL) -> URL {
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
    
}

public extension URL {
    var batterySavesPath: URL  { return Paths.batterySavesPath(forROM: self) }
    var saveStatePath: URL { return Paths.saveStatePath(forROM: self) }
}

public extension String {
    var saveStatePath: URL { return Paths.saveStatePath(forROMFilename: self) }
}
