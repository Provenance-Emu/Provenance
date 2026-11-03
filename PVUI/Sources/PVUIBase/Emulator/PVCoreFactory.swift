//  PVCoreFactory.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/14/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVRealm
import PVLogging
import PVSettings

// extension PVSystem {
//    var responderClassType : AnyClass {
//        guard let responderClassHandle = NSClassFromString(self.responderClass) else {
//            fatalError("Couldn't get class for <\(self.responderClass)>")
//        }
//
//        return responderClassHandle
//    }
// }

public extension PVCore {
    public func createInstance(forSystem system: PVSystem) -> PVEmulatorCore? {
        var className = self.principleClass

        // Every libretro core runs on the thin wrapper. The full in-process
        // RetroArch wrapper has been removed; the principleClass strings that
        // remain in the plist are only a marker that this is a libretro core.
        ILOG("createInstance: principleClass=\(className) for \(identifier)")
        if className.contains("RetroArch") || className.contains("LibRetro") || className == "PVRetroArchCoreBridge" {
            Self.ensurePVCoreBridgeRetroLoaded()
            if NSClassFromString("PVThinLibretroCore") != nil {
                ILOG("ThinLibretro: swapping \(className) → PVThinLibretroCore for \(identifier)")
                className = "PVThinLibretroCore"
            } else {
                ELOG("ThinLibretro: PVThinLibretroCore class not found after loading PVCoreBridgeRetro.framework")
            }
        }

        guard let coreClass = NSClassFromString(className) as? PVEmulatorCore.Type else {
            ELOG("Couldn't get class for <\(className)> (original: \(principleClass))")
            return nil
        }

        let emuCore = coreClass.init()

        DLOG("Created core : <\(emuCore.debugDescription)>")

        emuCore.systemIdentifier = system.identifier
        emuCore.coreIdentifier = identifier
        return emuCore
    }

    /// Ensures PVCoreBridgeRetro.framework is loaded so its classes are registered
    /// with the ObjC runtime. Called once lazily before the thin wrapper swap.
    private static var _bridgeRetroLoaded = false
    private static func ensurePVCoreBridgeRetroLoaded() {
        guard !_bridgeRetroLoaded else { return }
        _bridgeRetroLoaded = true
        // Find and load PVCoreBridgeRetro.framework from the app's Frameworks dir
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let bundleURL = frameworksURL.appendingPathComponent("PVCoreBridgeRetro.framework")
            if let bundle = Bundle(url: bundleURL), !bundle.isLoaded {
                ILOG("ThinLibretro: loading PVCoreBridgeRetro.framework from \(bundleURL.path)")
                bundle.load()
            }
        }
    }
}
