//
//  BIOS_Data.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData
import PVPrimitives

//#if !os(tvOS)
//@Model
//#endif
public class BIOS_Data {
    // Attributes
//#if !os(tvOS)
//    @Attribute(.unique)
//#endif
    public var expectedFilename: String = ""
//#if !os(tvOS)
//    @Attribute(.unique)
//#endif
    public var expectedMD5: String = ""
    public var expectedSize: Int = 0
    public var optional: Bool = false

    // Metadata
    public var descriptionText: String = ""
    public var regions: RegionOptions = RegionOptions.unknown
    public var version: String = ""

    // Files
    public var file: File_Data?
    public var fileInfo: File_Data? { return file }

    // Links
//    @Reference(to: System_Data.self)
    var system: System_Data!
    
    init(expectedFilename: String, expectedMD5: String, expectedSize: Int, optional: Bool, descriptionText: String, regions: RegionOptions, version: String, file: File_Data? = nil, system: System_Data!) {
        self.expectedFilename = expectedFilename
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.optional = optional
        self.descriptionText = descriptionText
        self.regions = regions
        self.version = version
        self.file = file
        self.system = system
    }
}

#endif
