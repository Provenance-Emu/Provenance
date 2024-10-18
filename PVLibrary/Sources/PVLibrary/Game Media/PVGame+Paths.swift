//
//  PVGame+Paths.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation
import PVRealm

// MARK: - PVGame convenience extension

public extension PVGame {
    // TODO: See above TODO, this should be based on the ROM systemid/md5
    var batterSavesPath: URL { get {
        return PVEmulatorConfiguration.batterySavesPath(forGame: self)
    }}

    var saveStatePath: URL { get {
        return PVEmulatorConfiguration.saveStatePath(forGame: self)
    }}
    
    var diskCount: Int { get {
        return relatedFiles
            .filter({ $0.pathExtension.lowercased() != "m3u" })
            .filter({
                if let extensions = RomDatabase.sharedInstance.getSystemCacheSync()[self.systemIdentifier]?.supportedExtensions {
                    return extensions.contains($0.pathExtension.lowercased())
                }
                return false
            }).count
    }}
}
