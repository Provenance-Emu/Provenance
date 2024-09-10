//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVLibraryPrimitives

@objcMembers
public final class PVBIOS: Object, BIOSFileProvider {
//    public var status: BIOSStatus
    
    public dynamic var system: PVSystem!

    public dynamic var descriptionText: String = ""
    public var regions: RegionOptions = .unknown
    public dynamic var version: String = ""
    public dynamic var optional: Bool = false

    public dynamic var expectedMD5: String = ""
    public dynamic var expectedSize: Int = 0
    public dynamic var expectedFilename: String = ""

    public dynamic var file: PVFile?
    public var fileInfo: PVFile? { return file }
    
    public init(system: PVSystem!, descriptionText: String, regions: RegionOptions, version: String, optional: Bool, expectedMD5: String, expectedSize: Int, expectedFilename: String, file: PVFile? = nil) {
        self.system = system
        self.descriptionText = descriptionText
        self.regions = regions
        self.version = version
        self.optional = optional
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
        self.file = file
    }

    public override static func primaryKey() -> String? {
        return "expectedFilename"
    }
}

public extension PVBIOS {
    convenience init(withSystem system: PVSystem, descriptionText: String, optional: Bool = false, expectedMD5: String, expectedSize: Int, expectedFilename: String) {
        self.init()
        self.system = system
        self.descriptionText = descriptionText
        self.optional = optional
        self.expectedMD5 = expectedMD5.uppercased()
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
    }
}

public extension PVBIOS {
    var expectedPath: URL { get {
        return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
    }}
}

extension PVBIOS {
    public var status: BIOSStatus { get {
        return BIOSStatus(withBios: self)
    }}
}

// MARK: - Conversions

public extension BIOS {
    init(with bios: PVBIOS) {
        let descriptionText = bios.descriptionText
        let optional = bios.optional
        let expectedMD5 = bios.expectedMD5
        let expectedSize = bios.expectedSize
        let expectedFilename = bios.expectedFilename
        let status = bios.status
        let file = bios.file?.asDomain()
        let regions = bios.regions
        let version = bios.version
        let system = bios.system.asDomain()
        
        self.init(descriptionText: descriptionText, regions: regions, version: version, expectedMD5: expectedMD5, expectedSize: expectedSize, expectedFilename: expectedFilename, optional: optional, status: status, file: file)
    }
}

extension PVBIOS: DomainConvertibleType {
    public typealias DomainType = BIOS

    public func asDomain() -> BIOS {
        return BIOS(with: self)
    }
}

extension BIOS: RealmRepresentable {
    public var uid: String {
        return expectedFilename
    }

    public func asRealm() async -> PVBIOS {
        return await PVBIOS.build({ object in
            object.descriptionText = descriptionText
            object.optional = optional
            object.expectedMD5 = expectedMD5
            object.expectedSize = expectedSize
            object.expectedFilename = expectedFilename
        })
    }
}
