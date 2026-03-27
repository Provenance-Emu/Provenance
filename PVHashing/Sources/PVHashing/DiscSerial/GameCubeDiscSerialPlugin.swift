//
//  GameCubeDiscSerialPlugin.swift
//  PVHashing
//
//  Extracts disc IDs from Nintendo GameCube and Wii disc images.
//

import Foundation
import PVLogging

/// Extracts disc IDs from GameCube (`.iso`, `.gcm`) and Wii (`.iso`, `.wbfs`, `.rvz`) images.
///
/// ## Format
/// Both GameCube and Wii discs use a common 512-byte disc header. The first
/// 6 bytes form the disc ID:
/// ```
/// Bytes 0–3:  Game code (e.g. "GALE" for Super Smash Bros. Melee)
/// Bytes 4–5:  Maker code (e.g. "01" for Nintendo)
/// ```
/// Combined: `GALE01`
///
/// ## Magic words
/// - GameCube: `0xC2336FA5` at header offset `0x1C`
/// - Wii:      `0x5D1C9EA3` at header offset `0x18`
///
/// ## WBFS files
/// WBFS archives prepend a 512-byte WBFS header before the disc data, so the
/// disc header starts at file offset 512.
public struct GameCubeDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["iso", "gcm", "wbfs", "rvz"]
    /// Need 32 bytes to cover both magic word positions (0x18 and 0x1C).
    public let magicByteCount = 32

    private static let gcMagic:  [UInt8] = [0xC2, 0x33, 0x6F, 0xA5]
    private static let wiiMagic: [UInt8] = [0x5D, 0x1C, 0x9E, 0xA3]

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 32 else { return false }
        let gcWord  = Array(headerBytes[0x1C..<0x20])
        let wiiWord = Array(headerBytes[0x18..<0x1C])
        return gcWord == Self.gcMagic || wiiWord == Self.wiiMagic
    }

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        return await Task.detached(priority: .utility) {
            self._extractSerial(from: url, systemHint: systemHint)
        }.value
    }

    // MARK: - Implementation

    private func _extractSerial(from url: URL, systemHint: String?) -> DiscSerialResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("GameCubeDiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        let ext = url.pathExtension.lowercased()
        let isWBFS = ext == "wbfs"
        let discHeaderOffset: UInt64 = isWBFS ? 512 : 0

        guard (try? handle.seek(toOffset: discHeaderOffset)) != nil,
              let header = try? handle.read(upToCount: 32),
              header.count >= 32 else {
            VLOG("GameCubeDiscSerialPlugin: failed to read header from \(url.lastPathComponent)")
            return nil
        }

        // Identify Wii vs. GameCube.
        let gcWord  = Array(header[0x1C..<0x20])
        let wiiWord = Array(header[0x18..<0x1C])

        let isWii: Bool
        if wiiWord == Self.wiiMagic {
            isWii = true
        } else if gcWord == Self.gcMagic {
            isWii = false
        } else {
            VLOG("GameCubeDiscSerialPlugin: no magic in \(url.lastPathComponent)")
            return nil
        }

        // Disc ID is the first 6 bytes: game code (4) + maker code (2).
        let idBytes = header[0..<6]
        guard let discID = String(bytes: idBytes, encoding: .ascii),
              discID.count == 6,
              discID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            WLOG("GameCubeDiscSerialPlugin: invalid disc ID bytes in \(url.lastPathComponent)")
            return nil
        }

        let hint = isWii ? "com.provenance.wii" : "com.provenance.gamecube"
        ILOG("GameCubeDiscSerialPlugin: found disc ID '\(discID)' (\(hint)) in \(url.lastPathComponent)")
        return DiscSerialResult(serial: discID, systemIdentifierHint: hint)
    }
}
