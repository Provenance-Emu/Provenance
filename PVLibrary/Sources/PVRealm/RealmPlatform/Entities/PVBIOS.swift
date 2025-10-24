//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVPrimitives

@objcMembers
public final class PVBIOS: Object, Identifiable, BIOSFileProvider {
//    public var status: BIOSStatus
    public var id: String { expectedMD5 }
    
    @Persisted public var system: PVSystem!

    @Persisted public var descriptionText: String = ""
    public var regions: RegionOptions = .unknown
    @Persisted public var version: String = ""
    @Persisted public var optional: Bool = false

    @Persisted(indexed: true) public var expectedMD5: String = ""
    @Persisted public var expectedSize: Int = 0
    @Persisted(primaryKey: true) public var expectedFilename: String = ""

    @Persisted public var file: PVFile?
    
    // CloudKit sync properties
    @Persisted public var cloudRecordID: String? // CloudKit record ID for on-demand downloads
    @Persisted public var isDownloaded: Bool = true // Whether the file is downloaded locally
    @Persisted public var fileSize: Int = 0 // File size in bytes
    public var fileInfo: PVFile? { return file }
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
//        let system = bios.system.asDomain()
        
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
