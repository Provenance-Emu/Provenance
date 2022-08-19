//
//  Hashing.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public typealias MD5Digest = String
public typealias SHA1Digest = String
public typealias CRC32Digest = String
public typealias SHA256Digest = String

public protocol MD5Digestable {
    var md5Hash: MD5Digest { get }
}

public protocol CRC32Digestable {
    var crc32Hash: CRC32Digest { get }
}

public protocol SHA1Digestable {
    var sha1Hash: SHA1Digest { get }
}

public protocol SHA265Digestable {
    var sha256Hash: SHA256Digest { get }
}

public protocol PVDigestable: MD5Digestable, CRC32Digestable, SHA1Digestable, SHA265Digestable { }
