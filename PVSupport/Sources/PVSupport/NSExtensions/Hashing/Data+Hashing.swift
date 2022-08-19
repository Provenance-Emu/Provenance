//
//  Data+Hashing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CommonCrypto
import CryptoKit
import CryptoSwift

extension Data: PVDigestable {
    public var md5Hash: MD5Digest { self.md5().toHexString().uppercased() }
    
    public var sha1Hash: SHA1Digest { self.sha1().toHexString().uppercased() }
    
    public var sha256Hash: SHA256Digest { self.sha256().toHexString().uppercased() }

    public var crc32Hash: CRC32Digest { crc32(seed: nil).toHexString().uppercased() }
}

// Legacy versions not using CryptoSwift
//public extension Data {
//    var md5Hash: String {
//        let hash: String = Insecure.MD5.hash(data: self).map { String(format: "%02x", $0) }.joined().uppercased()
//        return hash
//    }
//
//    var sha1Hash: String {
//        let hash: String = Insecure.SHA1.hash(data: self).map { String(format: "%02x", $0) }.joined().uppercased()
//        return hash
//    }
//
//    var sha256Hash: String {
//        let hash: String = SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined().uppercased()
//        return hash
//    }
//
//    var crc32Hash: String { crc32(seed: nil).toHexString().uppercased() }
//}
