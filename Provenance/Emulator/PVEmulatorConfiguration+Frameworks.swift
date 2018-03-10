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
                        try! database.writeTransaction {
                            setPropertiesTo(pvSystem: existingSystem, fromSystemPlistEntry: system)
                        }
                    } else {
                        let newSystem = PVSystem()
                        newSystem.systemIdentifier = system.PVSystemIdentifier
                        setPropertiesTo(pvSystem: newSystem, fromSystemPlistEntry: system)
                        do {
                            try database.add(object: newSystem, update: true)
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
        pvSystem.bit = Int(system.PVBit)!
        pvSystem.releaseYear = Int(system.PVReleaseYear)!
        pvSystem.name = system.PVSystemName
        pvSystem.shortName = system.PVSystemShortName
        pvSystem.controllerLayout = system.PVControlLayout
        pvSystem.usesCDs = system.PVUsesCDs ?? false
        
        // Iterate extensions and add to Realm object
        pvSystem.supportedExtensions = List<String>()
        system.PVSupportedExtensions.forEach { pvSystem.supportedExtensions.append($0) }
        
        if let bioses = system.PVBiosNames?.map({ (entry) -> PVBIOS in
            let newBIOS = PVBIOS()
            newBIOS.descriptionText = entry.Description
            newBIOS.expectedMD5 = entry.MD5
            newBIOS.expectedFilename = entry.Name
            newBIOS.expectedSize = entry.Size
            newBIOS.optional = entry.Optional ?? false
            return newBIOS
        }) {
            pvSystem.bioses.removeAll()
            bioses.forEach { pvSystem.bioses.append($0) }
        }
    }
}

