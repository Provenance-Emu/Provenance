//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers
public final class PVBIOS: Object, BIOSFileProvider {
    public dynamic var system: PVSystem!

    public dynamic var descriptionText: String = ""
    public dynamic var regions: RegionOptions = .unknown
    public dynamic var version: String = ""
    public dynamic var optional: Bool = false

    public dynamic var expectedMD5: String = ""
    public dynamic var expectedSize: Int = 0
    public dynamic var expectedFilename: String = ""

    public dynamic var file: PVFile?
    public var fileInfo: PVFile? { return file }

    public convenience init(withSystem system: PVSystem, descriptionText: String, optional: Bool = false, expectedMD5: String, expectedSize: Int, expectedFilename: String) {
        self.init()
        self.system = system
        self.descriptionText = descriptionText
        self.optional = optional
        self.expectedMD5 = expectedMD5.uppercased()
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
    }

    public override static func primaryKey() -> String? {
        return "expectedFilename"
    }
}

public extension PVBIOS {
    var expectedPath: URL {
        return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
    }
}

extension PVBIOS {
    public var status: BIOSStatus {
        return BIOSStatus(withBios: self)
    }
}

// MARK: - Conversions

private extension BIOS {
    init(with bios: PVBIOS) {
        descriptionText = bios.descriptionText
        optional = bios.optional
        expectedMD5 = bios.expectedMD5
        expectedSize = bios.expectedSize
        expectedFilename = bios.expectedFilename
        status = bios.status
        file = bios.file?.asDomain()
        regions = bios.regions
        version = bios.version
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

    public func asRealm() -> PVBIOS {
        return PVBIOS.build({ object in
            object.descriptionText = descriptionText
            object.optional = optional
            object.expectedMD5 = expectedMD5
            object.expectedSize = expectedSize
            object.expectedFilename = expectedFilename
        })
    }
}
