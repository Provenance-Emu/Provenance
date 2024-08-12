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
    var status: BIOSStatus { get async }
}

public typealias BIOSFileProvider = BIOSStatusProvider & BIOSInfoProvider & LocalFileBacked

public struct BIOS: BIOSFileProvider, Codable {
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
}

extension BIOS: Equatable {
    public static func == (lhs: BIOS, rhs: BIOS) -> Bool {
        return lhs.expectedMD5 == rhs.expectedMD5
    }
}
