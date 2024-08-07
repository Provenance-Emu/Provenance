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
import PVPlists

public enum CoreLoaderError: Error {
    case systemsDotPlistNotFound
    case noCoresFound
}

@Singleton
public final class CoreLoader: Sendable {
    fileprivate let ThisBundle: Bundle = Bundle.module

//    public func parseCoresPlists(plists: [URL]) async -> [EmulatorCoreInfoPlist] {
//        // Loading cores and calling `.corePlist` property on the `Class.self`
//        let corePlistsStructs = plists.compactMap {
//            do {
//                return try EmulatorCoreInfoPlist(fromURL: $0)
//            } catch {
//                ELOG("\(error.localizedDescription) for URL: \($0.debugDescription)")
//            }
//            return nil
//        }
//        return corePlistsStructs
//    }

    static public func getCorePlists() -> [EmulatorCoreInfoPlist] {

        // Scane all subclasses of  PVEmulator core, and get their metadata
        // like their subclass name and the bundle the belong to
        let coreClasses: [ClassInfo] = CoreClasses.coreClasses

        let plists: [EmulatorCoreInfoPlist] = coreClasses.map { classInfo in
            let plist: EmulatorCoreInfoPlist = classInfo.classObject.corePlist
            return plist
        }

        return plists
    }

//    public func parseSystemsPlist() throws(CoreLoaderError) -> [URL] {
//        guard let systemsPlist = ThisBundle.url(forResource: "systems", withExtension: "plist") else {
//            assertionFailure("Missing systems.plist")
//            throw CoreLoaderError.systemsDotPlistNotFound
//        }
//
//        return [systemsPlist]
//    }

    static public func systemsPlist() ->  [[String: Any]] {
        return PlistFiles.items
    }
}
