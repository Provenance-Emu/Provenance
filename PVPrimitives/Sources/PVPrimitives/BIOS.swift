//
//  BIOS.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public typealias BIOSExpectationsInfoProvider = ExpectedMD5Provider & ExpectedFilenameProvider & ExpectedSizeProvider & ExpectedExistentInfoProvider

public protocol BIOSInfoProvider: BIOSExpectationsInfoProvider {
    var descriptionText: String { get }
    var regions: RegionOptions { get }
    var version: String { get }
}

public protocol BIOSStatusProvider: BIOSInfoProvider {
    var status: BIOSStatus { get }
}

public typealias BIOSFileProvider = BIOSStatusProvider & BIOSInfoProvider & LocalFileBacked

public struct BIOS: BIOSFileProvider, Codable, Sendable {
    public let descriptionText: String
    public let regions: RegionOptions
    public let version: String

    public let expectedMD5: String
    public let expectedSize: Int
    public let expectedFilename: String

    public let optional: Bool

    public let status: BIOSStatus

    public let file: LocalFile?
    public var fileInfo: LocalFile? { return file }
    
    public init(descriptionText: String, regions: RegionOptions, version: String, expectedMD5: String, expectedSize: Int, expectedFilename: String, optional: Bool, status: BIOSStatus, file: LocalFile?) {
        self.descriptionText = descriptionText
        self.regions = regions
        self.version = version
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
        self.optional = optional
        self.status = status
        self.file = file
    }
}

extension BIOS: Equatable {
    public static func == (lhs: BIOS, rhs: BIOS) -> Bool {
        return lhs.expectedMD5.lowercased() == rhs.expectedMD5.lowercased()
    }
}

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers
@available(iOS 16.0, macOS 13, tvOS 16.0, *)
extension BIOS: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .bios)
    }
}
#endif
