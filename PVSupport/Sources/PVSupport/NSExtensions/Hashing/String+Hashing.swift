//
//  String+Hashing.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CommonCrypto
import CryptoKit

extension String: PVDigestable {
    public var md5Hash: MD5Digest { self.md5().uppercased() }
    
    public var sha1Hash: SHA1Digest { self.sha1().uppercased() }
    
    public var sha256Hash: SHA256Digest { self.sha256().uppercased() }

    public var crc32Hash: CRC32Digest { crc32(seed: nil).uppercased() }
}


// Legacy version
//private protocol ByteCountable {
//  static var byteCount: Int { get }
//}
//
//extension Insecure.MD5: ByteCountable { }
//extension Insecure.SHA1: ByteCountable { }
//public extension String {
////    var MD5Hash: String {
////        let data = Data(self.utf8)
////        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
////            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
////            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
////            return hash
////        }
////        return hash.map { String(format: "%02x", $0) }.joined()
////    }
//    var md5Hash: String {
//        return insecureMD5Hash() ?? ""
//    }
//
//    func insecureMD5Hash(using encoding: String.Encoding = .utf8) -> String? {
//      return self.hash(algo: Insecure.MD5.self, using: encoding)
//    }
//
//    func insecureSHA1Hash(using encoding: String.Encoding = .utf8) -> String? {
//      return self.hash(algo: Insecure.SHA1.self, using: encoding)
//    }
//
//    private func hash<Hash: HashFunction & ByteCountable>(algo: Hash.Type, using encoding: String.Encoding = .utf8) -> String? {
//      guard let data = self.data(using: encoding) else {
//        return nil
//      }
//
//      return algo.hash(data: data).prefix(algo.byteCount).map {
//        String(format: "%02hhx", $0)
//      }.joined()
//    }
//}
