//
//  ChdDiscSerialPlugin.swift
//  PVHashing
//
//  Disc-serial extraction from MAME Compressed Hunks of Data (CHD) archives.
//

import Foundation
import PVLogging

/// Extracts disc serials from MAME CHD archives (`.chd`).
///
/// ## CHD Format (v5)
/// CHD is the compressed disc image format used by MAME and RetroArch.
/// The v5 header (124 bytes) begins with the magic string `"MComprHD"` and
/// contains:
/// - `compressors[4]` — four compression codec tags; `0` means uncompressed.
/// - `mapoffset` — file offset of the hunk lookup table.
/// - `hunkbytes` — logical size of each hunk.
/// - `unitbytes` — logical size of each unit within a hunk.
///
/// ## CD-ROM CHDs
/// For CD-ROM images, each unit is one raw sector (2448 bytes: 2352 raw data +
/// 96 subchannel bytes).  The Sega IP.BIN header lives at sector 0 (data at
/// byte offset 16 within the raw sector for `MODE1` / `MODE2` raw sectors).
/// The ISO 9660 PVD lives at sector 16 (LBA 16).
///
/// ## Extraction strategy
/// - **Uncompressed CHD** (`compressors[0] == 0`): The hunk map lists each
///   hunk's file offset as a `uint32_t` multiple of `hunkbytes`.  We locate
///   the hunks that contain sectors 0 and 16 and read the raw data directly.
/// - **Compressed CHD**: Returning `nil`; decompression requires codec
///   libraries (zlib/LZMA/FLAC) that are not bundled with this module.
///
/// - Note: Compressed CHD support is a future enhancement.  The open-source
///   `libchdr` (BSD-licensed, already present in emulator cores) can be
///   vendored into this module to handle the general case.
public struct ChdDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["chd"]
    /// "MComprHD" is 8 bytes; we also need up to the `compressors` field at
    /// offset 16 to decide whether the CHD is uncompressed.
    public let magicByteCount = 32

    // CHD magic: "MComprHD" (8 ASCII bytes).
    private static let chdMagic: [UInt8] = [
        0x4D, 0x43, 0x6F, 0x6D, 0x70, 0x72, 0x48, 0x44  // "MComprHD"
    ]

    // CHD header field offsets (v5).
    private enum CHDv5 {
        static let headerLength      = 124
        static let versionOffset     = 12
        static let compressorsOffset = 16  // 4 × uint32_t (big-endian)
        static let mapOffsetOffset   = 40  // uint64_t BE
        static let hunkBytesOffset   = 56  // uint32_t BE
        static let unitBytesOffset   = 60  // uint32_t BE
    }

    /// Bytes per raw CD sector including subchannel.
    private static let cdRawSectorBytes = 2448
    /// Byte offset of user data within a raw CD sector (after 12-byte sync + 4-byte header).
    private static let cdDataOffset = 16

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 8 else { return false }
        return Array(headerBytes[0..<8]) == Self.chdMagic
    }

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("ChdDiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        // Read and validate the CHD header.
        guard (try? handle.seek(toOffset: 0)) != nil,
              let headerData = try? handle.read(upToCount: CHDv5.headerLength),
              headerData.count >= CHDv5.headerLength else {
            VLOG("ChdDiscSerialPlugin: cannot read header from \(url.lastPathComponent)")
            return nil
        }

        // Verify magic.
        guard Array(headerData[0..<8]) == Self.chdMagic else { return nil }

        // Only handle v5.
        let version = headerData.loadBE32(at: CHDv5.versionOffset)
        guard version == 5 else {
            VLOG("ChdDiscSerialPlugin: unsupported CHD version \(version) in \(url.lastPathComponent)")
            return nil
        }

        // Check compression — we only handle truly uncompressed CHDs (all 4 compressor
        // slots must be zero).  Checking only compressor[0] is insufficient: a CHD
        // with compressor[0]=0 but non-zero compressor[1-3] is still compressed and
        // the map-entry format differs from the simple sequential uncompressed layout.
        let compressor0 = headerData.loadBE32(at: CHDv5.compressorsOffset)
        let compressor1 = headerData.loadBE32(at: CHDv5.compressorsOffset + 4)
        let compressor2 = headerData.loadBE32(at: CHDv5.compressorsOffset + 8)
        let compressor3 = headerData.loadBE32(at: CHDv5.compressorsOffset + 12)
        guard compressor0 == 0 && compressor1 == 0 && compressor2 == 0 && compressor3 == 0 else {
            ILOG("ChdDiscSerialPlugin: compressed CHD (codecs 0x\(String(compressor0, radix: 16))/0x\(String(compressor1, radix: 16))/0x\(String(compressor2, radix: 16))/0x\(String(compressor3, radix: 16))) — serial extraction requires libchdr; skipping \(url.lastPathComponent)")
            return nil
        }

        let hunkBytes    = UInt64(headerData.loadBE32(at: CHDv5.hunkBytesOffset))
        let unitBytes    = UInt64(headerData.loadBE32(at: CHDv5.unitBytesOffset))
        let mapOffset    = headerData.loadBE64(at: CHDv5.mapOffsetOffset)

        guard hunkBytes > 0, unitBytes > 0, mapOffset > 0 else {
            VLOG("ChdDiscSerialPlugin: invalid CHD geometry in \(url.lastPathComponent)")
            return nil
        }

        let unitsPerHunk = hunkBytes / unitBytes

        // Try to read raw sector data from the CHD and extract serial.
        // Sector 0 → Sega IP.BIN (Saturn / SegaCD / Dreamcast)
        if let sector0Data = readCHDSector(
            handle: handle, sectorIndex: 0,
            hunkBytes: hunkBytes, unitsPerHunk: unitsPerHunk,
            unitBytes: unitBytes, mapOffset: mapOffset) {

            if let result = await trySegaExtraction(sectorData: sector0Data, url: url,
                                                     systemHint: systemHint) {
                return result
            }
        }

        // Sector 16 → ISO 9660 PVD (PSX / PS2 / generic CD-ROM)
        if let sector16Data = readCHDSector(
            handle: handle, sectorIndex: 16,
            hunkBytes: hunkBytes, unitsPerHunk: unitsPerHunk,
            unitBytes: unitBytes, mapOffset: mapOffset) {

            if let result = await tryISOExtraction(sectorData: sector16Data, url: url,
                                                    systemHint: systemHint) {
                return result
            }
        }

        VLOG("ChdDiscSerialPlugin: no serial found in uncompressed CHD \(url.lastPathComponent)")
        return nil
    }

    // MARK: - Per-format extraction helpers

    /// Tries to extract a Sega product code from the raw user-data bytes of
    /// sector 0, writing a temp file the SegaDiscSerialPlugin can open.
    private func trySegaExtraction(sectorData: Data, url: URL,
                                   systemHint: String?) async -> DiscSerialResult? {
        let plugin = SegaDiscSerialPlugin()
        // The sectorData is the 2048-byte user payload; the Sega plugin expects
        // either a cooked ISO (data at offset 0) or a raw sector (data at offset 16).
        // Here data is already the payload, so we treat it as a cooked ISO image.
        guard plugin.matchesMagicBytes(sectorData) else { return nil }

        return await withTempFile(data: sectorData, stem: url.deletingPathExtension().lastPathComponent,
                                  ext: "bin") { tmpURL in
            await plugin.extractSerial(from: tmpURL, systemHint: systemHint)
        }
    }

    /// Tries to extract an ISO 9660 serial by constructing a minimal fake ISO
    /// image with the PVD sector at the correct offset and writing it to disk.
    private func tryISOExtraction(sectorData: Data, url: URL,
                                  systemHint: String?) async -> DiscSerialResult? {
        // Build a minimal fake cooked ISO: sector 16 at byte offset 32768.
        let pvdFileOffset = 16 * 2048
        var fakeISO = Data(repeating: 0, count: pvdFileOffset + sectorData.count)
        fakeISO.replaceSubrange(pvdFileOffset..<(pvdFileOffset + sectorData.count), with: sectorData)

        let isoPlugin = ISODiscSerialPlugin()
        guard isoPlugin.matchesMagicBytes(fakeISO) else { return nil }

        return await withTempFile(data: fakeISO, stem: url.deletingPathExtension().lastPathComponent,
                                  ext: "iso") { tmpURL in
            await isoPlugin.extractSerial(from: tmpURL, systemHint: systemHint)
        }
    }

    // MARK: - CHD sector reading

    /// Reads the user-data bytes of a single CD sector from an **uncompressed** CHD.
    ///
    /// For CD-ROM CHDs each unit is one raw sector (`unitBytes == 2448`).
    /// The user data starts at byte 16 of the raw sector (after sync + header).
    ///
    /// For non-CD CHDs (e.g. hard-disc) `unitBytes != 2448`; we return the raw
    /// unit data and let the caller decide how to interpret it.
    private func readCHDSector(
        handle: FileHandle,
        sectorIndex: UInt64,
        hunkBytes: UInt64,
        unitsPerHunk: UInt64,
        unitBytes: UInt64,
        mapOffset: UInt64
    ) -> Data? {
        guard unitsPerHunk > 0 else { return nil }
        let hunkIndex  = sectorIndex / unitsPerHunk
        let unitInHunk = sectorIndex % unitsPerHunk

        // Uncompressed V5 map: each entry is a uint32_t (BE) hunk index that
        // gives the file position as `entryValue * hunkBytes`.
        let mapEntryOffset = mapOffset + hunkIndex * 4
        guard (try? handle.seek(toOffset: mapEntryOffset)) != nil,
              let mapEntryData = try? handle.read(upToCount: 4),
              mapEntryData.count == 4 else { return nil }

        let hunkFilePosition = UInt64(mapEntryData.loadBE32(at: 0)) * hunkBytes
        let unitFilePosition = hunkFilePosition + unitInHunk * unitBytes

        guard (try? handle.seek(toOffset: unitFilePosition)) != nil,
              let unitData = try? handle.read(upToCount: Int(unitBytes)),
              !unitData.isEmpty else { return nil }

        // For raw CD sectors (2448 bytes) extract the 2048-byte user-data payload.
        if unitBytes == UInt64(Self.cdRawSectorBytes),
           unitData.count >= Self.cdDataOffset + 2048 {
            return unitData.subdata(in: Self.cdDataOffset..<(Self.cdDataOffset + 2048))
        }
        return unitData
    }

    // MARK: - Temp-file helper

    /// Writes `data` to a uniquely-named temporary file, calls `body` with its
    /// URL, then removes the file regardless of outcome.
    private func withTempFile(
        data: Data,
        stem: String,
        ext: String,
        body: (URL) async -> DiscSerialResult?
    ) async -> DiscSerialResult? {
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpURL = tmpDir.appendingPathComponent(
            "\(stem)_chd_\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: tmpURL)
        } catch {
            WLOG("ChdDiscSerialPlugin: cannot write temp file: \(error)")
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        return await body(tmpURL)
    }
}
