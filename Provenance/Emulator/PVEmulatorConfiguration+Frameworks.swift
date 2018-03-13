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
    static var coreClasses : [ClassInfo] {
        let motherClassInfo = ClassInfo(PVEmulatorCore.self)!
        var subclassList = [ClassInfo]()
        
        var count = UInt32(0)
        let classList = objc_copyClassList(&count)!
        
        for i in 0..<Int(count) {
            if let classInfo = ClassInfo(classList[i]),
                let superclassInfo = classInfo.superclassInfo,
                superclassInfo == motherClassInfo
            {
                subclassList.append(classInfo)
            }
        }
        
        return subclassList
    }
    
    class func updateSystems(fromPlist plists : [URL]) {
        typealias SystemPlistEntries = [SytemPlistEntry]
        let database = RomDatabase.sharedInstance
        
        plists.forEach { plist in
            do {
                let data = try Data(contentsOf: plist)
                let decoder = PropertyListDecoder()
                let systems : SystemPlistEntries? = try decoder.decode(SystemPlistEntries.self, from: data)
                
                systems?.forEach { system in
                    if let existingSystem = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.PVSystemIdentifier) {
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
    
    class func setPropertiesTo(pvSystem : PVSystem, fromSystemPlistEntry system : SytemPlistEntry) {
        pvSystem.openvgDatabaseID = Int(system.PVDatabaseID)!
        pvSystem.requiresBIOS = system.PVRequiresBIOS ?? false
        pvSystem.manufacturer = system.PVManufacturer
        pvSystem.bit = Int(system.PVBit) ?? 0
        pvSystem.releaseYear = Int(system.PVReleaseYear)!
        pvSystem.name = system.PVSystemName
        pvSystem.shortName = system.PVSystemShortName
        pvSystem.controllerLayout = system.PVControlLayout
        pvSystem.usesCDs = system.PVUsesCDs ?? false
        
        // Iterate extensions and add to Realm object
        pvSystem.supportedExtensions.removeAll()
        pvSystem.supportedExtensions.append(objectsIn: system.PVSupportedExtensions)
        
        system.PVBiosNames?.forEach { entry in
            if let existingBIOS = RomDatabase.sharedInstance.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: entry.Name) {
                existingBIOS.system = pvSystem
            } else {
                let newBIOS = PVBIOS(withSystem: pvSystem, descriptionText: entry.Description, optional: entry.Optional ?? false, expectedMD5: entry.MD5, expectedSize: entry.Size, expectedFilename: entry.Name)
                try! newBIOS.add()
            }
         }
    }
}

