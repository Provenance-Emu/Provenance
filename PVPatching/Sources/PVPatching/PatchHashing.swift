//
//  PatchHashing.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

enum PatchHashing {
    static func sha256Hex(_ data: Data) -> String {
#if canImport(CryptoKit)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
#elseif canImport(Crypto)
        return Crypto.SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
#else
        // Fallback for exotic platforms: CRC32 + length is deterministic but weaker.
        return String(format: "%08x%08x", patchCRC32(data), UInt32(truncatingIfNeeded: data.count))
#endif
    }

    static func md5Hex(_ data: Data) -> String {
#if canImport(CryptoKit)
        return Insecure.MD5.hash(data: data).map { String(format: "%02X", $0) }.joined()
#else
        // Platforms without CryptoKit fall back to a deterministic uppercase hex
        // digest derived from SHA-256 truncation — not MD5, but stable for cache IDs.
        return String(sha256Hex(data).prefix(32)).uppercased()
#endif
    }

    static func cacheKey(romData: Data, patchData: Data) -> String {
        let romHash = sha256Hex(romData)
        let patchHash = sha256Hex(patchData)
        let combined = Data((romHash + patchHash).utf8)
        return String(sha256Hex(combined).prefix(32))
    }
}
