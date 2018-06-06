//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class PVBIOS: Object, PVFiled {
    public dynamic var system: PVSystem!
    public dynamic var descriptionText: String = ""
    public dynamic var optional: Bool = false

    public dynamic var expectedMD5: String = ""
    public dynamic var expectedSize: Int = 0
    public dynamic var expectedFilename: String = ""

    public dynamic var file: PVFile?

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
