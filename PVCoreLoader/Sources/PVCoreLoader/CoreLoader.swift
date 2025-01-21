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

public final class CoreLoader: Sendable {

    public static let shared: CoreLoader = .init()
    private init() {}

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
//        if #available(iOS 17, *) {
//            return getCorePlistsFromDyload()
//        } else {
            return getCorePlistsFromFileSystem()
//        }
    }

    static private func getCorePlistsFromDyload() -> [EmulatorCoreInfoPlist] {
        // Scan all subclasses of PVEmulator core, and get their metadata
        // like their subclass name and the bundle they belong to
        let coreClasses: [ClassInfo] = CoreClasses.coreClasses

        let plists: [EmulatorCoreInfoPlist] = coreClasses.map { classInfo in
            let plist: EmulatorCoreInfoPlist = classInfo.classObject.corePlist
            return plist
        }

        return plists
    }

    static private func getCorePlistsFromFileSystem() -> [EmulatorCoreInfoPlist] {
        var plists: [EmulatorCoreInfoPlist] = []

        // Get main bundle path
        let mainBundlePath = Bundle.main.bundleURL

        // Get Frameworks directory path
        let frameworksPath = mainBundlePath.appendingPathComponent("Frameworks")

        // Define paths to scan
        let pathsToScan = [mainBundlePath, frameworksPath]

        do {
            // Scan each path for both .framework and .bundle
            for path in pathsToScan {
                // Skip if directory doesn't exist
                guard FileManager.default.fileExists(atPath: path.path) else { continue }

                let contents = try FileManager.default.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                // Filter for bundles and frameworks
                let bundlePaths = contents.filter { url in
                    let pathExtension = url.pathExtension.lowercased()
                    return pathExtension == "framework" || pathExtension == "bundle"
                }

                // Load Core.plist from each bundle
                for bundlePath in bundlePaths {
                    if let plist = try loadCorePlist(from: bundlePath) {
                        plists.append(plist)
                        ILOG("Loaded Core.plist from \(bundlePath.lastPathComponent)")
                    }
                }
            }

            // Also check main bundle itself for Core.plist
            if let mainBundlePlist = try loadCorePlist(from: mainBundlePath) {
                plists.append(mainBundlePlist)
                ILOG("Loaded Core.plist from main bundle")
            }

        } catch {
            ELOG("Error scanning for Core.plists: \(error)")
        }

        return plists
    }

    static private func loadCorePlist(from bundlePath: URL) throws -> EmulatorCoreInfoPlist? {
        let plistPath = bundlePath.appendingPathComponent("Core.plist")

        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            return nil
        }

        do {
            let plist = try EmulatorCoreInfoPlist(fromURL: plistPath)
            ILOG("Successfully loaded Core.plist from \(bundlePath.lastPathComponent)")
            return plist
        } catch {
            ELOG("Failed to load Core.plist from \(bundlePath.lastPathComponent): \(error)")
            return nil
        }
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
