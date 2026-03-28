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

        // Read from offset 0 and detect the sector layout by checking where the
        // Sega magic appears. We need enough bytes to cover:
        //   - cooked (2048-byte sectors): magic at byte 0, product code up to 0x183+8=0x18B
        //   - raw (2352-byte sectors):    sync header at bytes 0–15, magic at byte 16,
        //                                 product code up to 16+0x183+8=0x19B
        // Reading 528 bytes covers both cases with margin.
        guard (try? handle.seek(toOffset: 0)) != nil,
              let headerBytes = try? handle.read(upToCount: 528),
              headerBytes.count >= 32 else {
            VLOG("SegaDiscSerialPlugin: failed to read header from \(url.lastPathComponent)")
            return nil
        }

        guard let (format, dataStart) = detectFormatWithOffset(in: headerBytes) else {
            VLOG("SegaDiscSerialPlugin: no Sega magic in \(url.lastPathComponent)")
            return nil
        }

        guard let serial = productCode(from: headerBytes, format: format, dataStart: dataStart),
              !serial.isEmpty else {
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

    /// Returns the detected format and the byte offset within the buffer where
    /// the IP.BIN / volume header data payload starts (0 for cooked, 16 for raw).
    private func detectFormatWithOffset(in bytes: Data) -> (SegaFormat, Int)? {
        // Check at offset 0 (cooked ISO) first, then offset 16 (raw 2352-byte BIN sector).
        for startOffset in [0, 16] {
            guard bytes.count >= startOffset + 16 else { continue }
            let head = Array(bytes[startOffset..<(startOffset + 16)])
            if head == Self.saturnMagic    { return (.saturn,    startOffset) }
            if head == Self.segaCDMagic   { return (.segaCD,    startOffset) }
            if head == Self.dreamcastMagic { return (.dreamcast, startOffset) }
        }
        return nil
    }

    /// For `matchesMagicBytes` compatibility — returns format without offset.
    private func detectFormat(in bytes: Data) -> SegaFormat? {
        return detectFormatWithOffset(in: bytes).map { $0.0 }
    }

    // MARK: - Product code extraction

    /// Extracts the product code from `bytes`, where `dataStart` is the offset
    /// within `bytes` at which the IP.BIN / volume header data payload begins.
    private func productCode(from bytes: Data, format: SegaFormat, dataStart: Int) -> String? {
        let relativeOffset: Int
        let length: Int
        switch format {
        case .segaCD:    (relativeOffset, length) = (0x183, 8)
        case .saturn:    (relativeOffset, length) = (0x20,  10)
        case .dreamcast: (relativeOffset, length) = (0x40,  10)
        }
        return bytes.asciiString(at: dataStart + relativeOffset, length: length)
    }
}
