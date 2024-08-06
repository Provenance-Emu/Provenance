//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  GameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import SwiftMacros

#if canImport(PVAtari800)
@_exported import PVAtari800
#endif
#if canImport(PVPicoDrive)
@_exported import PVPicoDrive
#endif
#if canImport(PVPokeMini)
@_exported import PVPokeMini
#endif
#if canImport(PVStella)
@_exported import PVStella
#endif
#if canImport(PVTGBDUal)
@_exported import PVTGBDUal
#endif
#if canImport(PVVirtualJaguar)
@_exported import PVVirtualJaguar
#endif

public enum CoreLoaderError: Error {
    case systemsDotPlistNotFound
    case noCoresFound
}

@Singleton
public final class CoreLoader: Sendable {
    fileprivate let ThisBundle: Bundle = Bundle.module

    public func parseCoresPlists(plists: [URL]) async -> [EmulatorCoreInfoPlist] {
        // Loading cores and calling `.corePlist` property on the `Class.self`
        let corePlistsStructs = plists.compactMap {
            do {
                return try EmulatorCoreInfoPlist(fromURL: $0)
            } catch {
                ELOG("\(error.localizedDescription) for URL: \($0.debugDescription)")
            }
            return nil
        }
        return corePlistsStructs
    }

    public func getCorePlists() -> [EmulatorCoreInfoPlist] {

        // Scane all subclasses of  PVEmulator core, and get their metadata
        // like their subclass name and the bundle the belong to
        let coreClasses: [ClassInfo] = CoreClasses.coreClasses

        let plists: [EmulatorCoreInfoPlist] = coreClasses.map { classInfo in
            let plist: EmulatorCoreInfoPlist = classInfo.classObject.corePlist
            return plist
        }

        return plists
    }

    public func parseSystemsPlist() throws(CoreLoaderError) -> [URL] {
        guard let systemsPlist = ThisBundle.url(forResource: "systems", withExtension: "plist") else {
            assertionFailure("Missing systems.plist")
            throw CoreLoaderError.systemsDotPlistNotFound
        }

        return [systemsPlist]
    }

    public func systemsPlist() ->  [[String: Any]] {
        return PlistFiles.items
    }
}
