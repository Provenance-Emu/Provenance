//
//  SegaDiscSerialPlugin.swift
//  PVHashing
//
//  Extracts product codes from Sega Saturn, SegaCD, and Dreamcast disc images.
//

import Foundation
import PVLogging

/// Extracts product codes from Sega disc images (`.bin`, `.iso`).
///
/// ## Supported systems
/// | System    | Magic (first 16 bytes)     | Product code offset | Length |
/// |-----------|----------------------------|---------------------|--------|
/// | Sega CD   | `SEGADISCSYSTEM  `         | 0x183               | 8      |
/// | Saturn    | `SEGA SATURN     `         | 0x20                | 10     |
/// | Dreamcast | `SEGA SEGASATURN `         | 0x40                | 10     |
///
/// ## Sector layout
/// For raw 2352-byte/sector BIN tracks the IP.BIN / volume header is embedded
/// in the data area of the first sector. The plugin detects whether the file
/// uses cooked (2048-byte) or raw sectors and reads the header accordingly.
public struct SegaDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["bin", "iso", "img"]
    public let magicByteCount = 32

    // First 16 bytes of each Sega format's IP.BIN / volume header.
    private static let saturnMagic:  [UInt8] = Array("SEGA SATURN     ".utf8)
    private static let segaCDMagic:  [UInt8] = Array("SEGADISCSYSTEM  ".utf8)
    private static let dreamcastMagic: [UInt8] = Array("SEGA SEGASATURN ".utf8)

    private enum SegaFormat {
        case saturn, segaCD, dreamcast
    }

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 16 else { return false }
        // For raw-sector BINs the data payload starts at byte 16.
        // We check both offset 0 (cooked ISO) and offset 16 (raw sector).
        return detectFormat(in: headerBytes) != nil
    }

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        return await Task.detached(priority: .utility) {
            self._extractSerial(from: url, systemHint: systemHint)
        }.value
    }

    // MARK: - Implementation

    private func _extractSerial(from url: URL, systemHint: String?) -> DiscSerialResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("SegaDiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        // Determine sector data offset (0 for cooked ISO, 16 for raw 2352-byte BIN).
        let dataOffset = sectorDataOffset(for: url)

        // Read the first 512 bytes of the IP.BIN / volume header.
        guard (try? handle.seek(toOffset: UInt64(dataOffset))) != nil,
              let headerBytes = try? handle.read(upToCount: 512),
              headerBytes.count >= 256 else {
            VLOG("SegaDiscSerialPlugin: failed to read header from \(url.lastPathComponent)")
            return nil
        }

        guard let format = detectFormat(in: headerBytes) else {
            VLOG("SegaDiscSerialPlugin: no Sega magic in \(url.lastPathComponent)")
            return nil
        }

        guard let serial = productCode(from: headerBytes, format: format), !serial.isEmpty else {
            WLOG("SegaDiscSerialPlugin: empty product code in \(url.lastPathComponent)")
            return nil
        }

        let hint: String
        switch format {
        case .saturn:    hint = "com.provenance.saturn"
        case .segaCD:    hint = "com.provenance.segacd"
        case .dreamcast: hint = "com.provenance.dreamcast"
        }

        ILOG("SegaDiscSerialPlugin: found serial '\(serial)' (\(hint)) in \(url.lastPathComponent)")
        return DiscSerialResult(serial: serial, systemIdentifierHint: hint)
    }

    // MARK: - Format detection

    private func detectFormat(in bytes: Data) -> SegaFormat? {
        // Check at offset 0 (cooked ISO) first, then offset 16 (raw BIN sector).
        for startOffset in [0, 16] {
            guard bytes.count >= startOffset + 16 else { continue }
            let head = Array(bytes[startOffset..<(startOffset + 16)])
            if head == Self.saturnMagic    { return .saturn }
            if head == Self.segaCDMagic   { return .segaCD }
            if head == Self.dreamcastMagic { return .dreamcast }
        }
        return nil
    }

    // MARK: - Product code extraction

    private func productCode(from bytes: Data, format: SegaFormat) -> String? {
        let offset: Int
        let length: Int
        switch format {
        case .segaCD:    (offset, length) = (0x183, 8)
        case .saturn:    (offset, length) = (0x20,  10)
        case .dreamcast: (offset, length) = (0x40,  10)
        }

        // For raw-sector BINs, the header is at byte 16 of the first sector,
        // so we need to shift the offset by 16.
        // We already seeked to the correct data start in _extractSerial, so the
        // `bytes` buffer already has the data at the right position.
        return bytes.asciiString(at: offset, length: length)
    }

    // MARK: - Sector size detection

    /// Returns the byte offset of the first sector's data payload.
    ///
    /// - 0  for cooked ISO / plain .iso files (2048-byte sectors)
    /// - 16 for raw-sector BIN files (2352-byte sectors, data at byte 16)
    ///
    /// Detection is by file-size divisibility — not foolproof but correct
    /// for the vast majority of disc images in the wild.
    private func sectorDataOffset(for url: URL) -> Int {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64, size > 0 else { return 0 }
        if size % 2352 == 0 { return 16 }
        if size % 2048 == 0 { return 0 }
        // File size not evenly divisible — default to raw sector.
        return 16
    }
}
