//
//  BIOS_Data.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData
import PVPrimitives

@Model
public class BIOS_Data {
    @Attribute(.unique) public var expectedFilename: String
    @Attribute(.unique) public var expectedMD5: String
    public var expectedSize: Int = 0
    public var optional: Bool = false

    // Metadata
    public var descriptionText: String = ""
    // RegionOptions is Codable (OptionSet<Int>) — stored as Codable attribute
    public var regions: RegionOptions = RegionOptions.unknown
    public var version: String = ""

    // One-to-one: BIOS file on disk (BIOS owns the file record)
    @Relationship(deleteRule: .cascade)
    public var file: File_Data?

    // Many-to-one: inverse of System_Data.bioses
    public var system: System_Data?

    /// Alias for `file` matching existing API
    public var fileInfo: File_Data? { file }

    public init(expectedFilename: String, expectedMD5: String, expectedSize: Int,
                optional: Bool, descriptionText: String, regions: RegionOptions,
                version: String, file: File_Data? = nil, system: System_Data? = nil) {
        self.expectedFilename = expectedFilename
        self.expectedMD5 = expectedMD5.uppercased()
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
