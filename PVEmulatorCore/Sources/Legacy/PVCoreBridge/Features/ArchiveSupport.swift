//
//  ArchiveSupport.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public protocol ArchiveSupport {
    var supportedArchiveFormats: ArchiveSupportOptions { get }
}

// extension protocol ArchiveSupport where Self:PVEmulatorCore {
//    open var supportedArchiveFormats : ArchiveSupportOptions {
//        return []
//    }
// }

public struct ArchiveSupportOptions: OptionSet {
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int

    public static let zip = ArchiveSupportOptions(rawValue: 1 << 0)
    public static let sevenZip = ArchiveSupportOptions(rawValue: 1 << 1)
    public static let gzip = ArchiveSupportOptions(rawValue: 1 << 1)

    public static let all: ArchiveSupportOptions = [.zip, .sevenZip]
}
