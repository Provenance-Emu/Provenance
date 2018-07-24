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
public final class PVBIOS: Object, PVFiled {
    dynamic public var system: PVSystem!
    dynamic public var descriptionText: String = ""
    dynamic public var optional: Bool = false

    dynamic public var expectedMD5: String = ""
    dynamic public var expectedSize: Int = 0
    dynamic public var expectedFilename: String = ""

    dynamic public var file: PVFile?

    public convenience init(withSystem system: PVSystem, descriptionText: String, optional: Bool = false, expectedMD5: String, expectedSize: Int, expectedFilename: String) {
        self.init()
        self.system = system
        self.descriptionText = descriptionText
        self.optional = optional
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
    }

    override public static func primaryKey() -> String? {
        return "expectedFilename"
    }
}

public extension PVBIOS {
    var expectedPath: URL {
        return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
    }
}
