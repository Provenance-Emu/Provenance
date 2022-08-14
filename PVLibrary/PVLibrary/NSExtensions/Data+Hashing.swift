//
//  Data+Hashing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CommonCrypto

@objc public
extension String {
    #if canImport(CommonCrypto)
    var MD5Hash: String {
        Insecure.MD5.hash(data: self.data(using: .utf8)!).uppercased()
    }
    #else
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    #endif
}

@objc public
extension Data {
    var md5Hash: String {
        let hash = Insecure.MD5.hash(data: self)
        return hash
    }
    
    var sha1Hash: String {
        let hash = Insecure.SHA1.hash(data: self)
        return hash.uppercased()
    }
}
