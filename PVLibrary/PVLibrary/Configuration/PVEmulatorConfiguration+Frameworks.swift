//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/10/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import PVSupport

// MARK: - System Scanner
public extension PVEmulatorConfiguration {
    static var coreClasses: [ClassInfo] {
        let motherClassInfo = ClassInfo(PVEmulatorCore.self)
        var subclassList = [ClassInfo]()

        var count = UInt32(0)
        let classList = objc_copyClassList(&count)!

        for i in 0..<Int(count) {
			if let classInfo = ClassInfo(classList[i], withSuperclass: "PVEmulatorCore"),
                let superclassInfo = classInfo.superclassInfo,
                superclassInfo == motherClassInfo {
                subclassList.append(classInfo)
            }
        }

		return subclassList.filter {return $0.className != "PVEmulatorCore" && $0.superclassInfo?.className == "PVEmulatorCore"}
    }

    class func updateCores(fromPlists plists: [URL]) {
        let database = RomDatabase.sharedInstance
        let decoder = PropertyListDecoder()

		// Remove all existing cores first incase things have been updated
//		if !database.realm.isInWriteTransaction {
//			try! database.writeTransaction {
//				try! database.deleteAll(PVCore.self)
//			}
//		} else {
//			try! database.deleteAll(PVCore.self)
//		}

        plists.forEach { (plist) in
            do {
                let data = try Data(contentsOf: plist)
                let core = try decoder.decode(CorePlistEntry.self, from: data)
                let supportedSystems = database.all(PVSystem.self, filter: NSPredicate(format: "identifier IN %@", argumentArray: [core.PVSupportedSystems]))

                let newCore = PVCore(withIdentifier: core.PVCoreIdentifier, principleClass: core.PVPrincipleClass, supportedSystems: Array(supportedSystems), name: core.PVProjectName, url: core.PVProjectURL, version: core.PVProjectVersion)
                try newCore.add(update: true)
            } catch {
                // Handle error
                ELOG("Failed to parse plist \(plist.path) : \(error)")
            }
        }
    }

    class func updateSystems(fromPlists plists: [URL]) {
        typealias SystemPlistEntries = [SytemPlistEntry]
        let database = RomDatabase.sharedInstance
        let decoder = PropertyListDecoder()

        plists.forEach { plist in
            do {
                let data = try Data(contentsOf: plist)
                let systems: SystemPlistEntries? = try decoder.decode(SystemPlistEntries.self, from: data)

                systems?.forEach { system in
                    if let existingSystem = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.PVSystemIdentifier) {
                        do {
                            try database.writeTransaction {
                                setPropertiesTo(pvSystem: existingSystem, fromSystemPlistEntry: system)
                                VLOG("Updated system for id \(system.PVSystemIdentifier)")
                            }
                        } catch {
                            ELOG("Failed to make update system: \(error)")
                        }
                    } else {
                        let newSystem = PVSystem()
                        newSystem.identifier = system.PVSystemIdentifier
                        setPropertiesTo(pvSystem: newSystem, fromSystemPlistEntry: system)
                        do {
                            try database.add(newSystem, update: true)
                            DLOG("Added new system for id \(system.PVSystemIdentifier)")
                        } catch {
                            ELOG("Failed to make new system: \(error)")
                        }
                    }

                }
            } catch {
                // Handle error
                ELOG("Failed to parse plist \(plist.path) : \(error)")
            }
        }
    }

    class func setPropertiesTo(pvSystem: PVSystem, fromSystemPlistEntry system: SytemPlistEntry) {
        pvSystem.openvgDatabaseID = Int(system.PVDatabaseID)!
        pvSystem.requiresBIOS = system.PVRequiresBIOS ?? false
        pvSystem.manufacturer = system.PVManufacturer
        pvSystem.bit = Int(system.PVBit) ?? 0
        pvSystem.releaseYear = Int(system.PVReleaseYear)!
        pvSystem.name = system.PVSystemName
        pvSystem.shortName = system.PVSystemShortName
        pvSystem.shortNameAlt = system.PVSystemShortNameAlt
        pvSystem.controllerLayout = system.PVControlLayout
        pvSystem.portableSystem = system.PVPortable ?? false
        pvSystem.usesCDs = system.PVUsesCDs ?? false
        pvSystem.supportsRumble = system.PVSupportsRumble ?? false
        pvSystem.headerByteSize = system.PVHeaderByteSize ?? 0

        if let screenType = system.PVScreenType {
            pvSystem.screenType = ScreenType(rawValue: screenType) ?? .unknown
        } else {
            pvSystem.screenType = .unknown
        }

        // Iterate extensions and add to Realm object
        pvSystem.supportedExtensions.removeAll()
        pvSystem.supportedExtensions.append(objectsIn: system.PVSupportedExtensions)
        let database = RomDatabase.sharedInstance

        system.PVBIOSNames?.forEach { entry in
            if let existingBIOS = database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: entry.Name) {
                if database.realm.isInWriteTransaction {
                    existingBIOS.system = pvSystem
                } else {
                    try! database.writeTransaction {
                        existingBIOS.system = pvSystem
                    }
                }
            } else {
                let newBIOS = PVBIOS(withSystem: pvSystem, descriptionText: entry.Description, optional: entry.Optional ?? false, expectedMD5: entry.MD5, expectedSize: entry.Size, expectedFilename: entry.Name)

                if database.realm.isInWriteTransaction {
                    database.realm.add(newBIOS)
                } else {
                    try! database.add(newBIOS)
                }
            }
         }
    }
}
