//
//  GameCubeDiscSerialPlugin.swift
//  PVHashing
//
//  Extracts disc IDs from Nintendo GameCube and Wii disc images.
//

import Foundation
import PVLogging

/// Extracts disc IDs from GameCube (`.iso`, `.gcm`) and Wii (`.iso`, `.wbfs`, `.wia`, `.rvz`) images.
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
///
/// ## WIA / RVZ files
/// WIA (Wii Image Archive) and RVZ (RetroArch / Dolphin compressed format)
/// store the first 128 bytes of the disc header uncompressed in their file
/// header (WIAHeader2.disc_header) at absolute file offset 0x54.  The disc ID
/// can therefore be read without any decompression.
///
/// WIA header layout (offsets are absolute file positions):
/// ```
/// 0x00: magic[4]         — "WIA\x01" or "RVZ\x01"
/// 0x04: revision[4]
/// 0x08: version_compatible[4]
/// 0x0C: disc_size_mb[4]
/// 0x10: disc_hash[20]    — SHA-1
/// 0x24: iso_file_size[8]
/// 0x2C: wia_file_size[8]
/// 0x34: header_1_hash[20]
/// // WIAHeader2 starts at 0x48:
/// 0x48: compression_type[4]
/// 0x4C: compression_level[4]
/// 0x50: chunk_size[4]
/// 0x54: disc_header[128] — first 128 bytes of disc image, UNCOMPRESSED
/// ```
public struct GameCubeDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["iso", "gcm", "wbfs", "rvz", "wia"]
    /// 32 bytes covers GC/Wii magic at 0x18/0x1C; we also check byte 0 for
    /// WBFS/WIA/RVZ magic which needs only 4 bytes.
    public let magicByteCount = 32

    private static let gcMagic:  [UInt8] = [0xC2, 0x33, 0x6F, 0xA5]
    private static let wiiMagic: [UInt8] = [0x5D, 0x1C, 0x9E, 0xA3]
    private static let wbfsMagic: [UInt8] = [0x57, 0x42, 0x46, 0x53] // "WBFS"
    private static let wiaMagic:  [UInt8] = [0x57, 0x49, 0x41, 0x01] // "WIA\x01"
    private static let rvzMagic:  [UInt8] = [0x52, 0x56, 0x5A, 0x01] // "RVZ\x01"

    private enum GCFormat {
        case cookedISO   // plain .iso / .gcm
        case wbfs        // WBFS container (.wbfs); disc header at file offset 512
        case wiaRvz      // WIA/RVZ container; disc header at file offset 0x54
    }

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 4 else { return false }
        // WBFS, WIA, RVZ: recognised by the first 4 bytes alone.
        let prefix4 = Array(headerBytes[0..<4])
        if prefix4 == Self.wbfsMagic { return true }
        if prefix4 == Self.wiaMagic  { return true }
        if prefix4 == Self.rvzMagic  { return true }
        // Cooked ISO / GCM: check 4-byte magic words at 0x18 (Wii) and 0x1C (GC).
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

        let format = detectFormat(handle: handle, url: url)
        let discHeaderOffset: UInt64
        switch format {
        case .cookedISO: discHeaderOffset = 0
        case .wbfs:      discHeaderOffset = 512
        case .wiaRvz:    discHeaderOffset = 0x54  // WIAHeader2.disc_header
        }

        guard (try? handle.seek(toOffset: discHeaderOffset)) != nil,
              let header = try? handle.read(upToCount: 32),
              header.count >= 6 else {
            VLOG("GameCubeDiscSerialPlugin: failed to read disc header from \(url.lastPathComponent)")
            return nil
        }

        // For cooked ISO and WBFS the GC/Wii magic is present; for WIA/RVZ we
        // trust the file-level magic we already verified in matchesMagicBytes.
        let isWii: Bool
        if format == .wiaRvz {
            // Determine GC vs Wii from the disc header's magic words.
            if header.count >= 32 {
                let wiiWord = Array(header[0x18..<0x1C])
                let gcWord  = Array(header[0x1C..<0x20])
                if wiiWord == Self.wiiMagic {
                    isWii = true
                } else if gcWord == Self.gcMagic {
                    isWii = false
                } else {
                    // Neither magic recognised — WIA/RVZ are Wii-era formats, default to Wii.
                    isWii = true
                }
            } else {
                // Default to Wii if we can't tell (WIA/RVZ are both Wii-era formats).
                isWii = true
            }
        } else {
            guard header.count >= 32 else {
                VLOG("GameCubeDiscSerialPlugin: header too short in \(url.lastPathComponent)")
                return nil
            }
            let gcWord  = Array(header[0x1C..<0x20])
            let wiiWord = Array(header[0x18..<0x1C])
            if wiiWord == Self.wiiMagic {
                isWii = true
            } else if gcWord == Self.gcMagic {
                isWii = false
            } else {
                VLOG("GameCubeDiscSerialPlugin: no GC/Wii magic in \(url.lastPathComponent)")
                return nil
            }
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

    // MARK: - Format detection

    private func detectFormat(handle: FileHandle, url: URL) -> GCFormat {
        guard (try? handle.seek(toOffset: 0)) != nil,
              let magic = try? handle.read(upToCount: 4),
              magic.count == 4 else { return .cookedISO }
        let prefix4 = Array(magic)
        if prefix4 == Self.wbfsMagic { return .wbfs }
        if prefix4 == Self.wiaMagic  { return .wiaRvz }
        if prefix4 == Self.rvzMagic  { return .wiaRvz }
        return .cookedISO
    }
}
