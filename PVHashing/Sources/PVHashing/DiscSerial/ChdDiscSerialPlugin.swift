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
/// - **Uncompressed CHD** (`compressors[0..3] == 0`): The hunk map lists each
///   hunk's file offset as a `uint32_t` multiple of `hunkbytes`.  We locate
///   the hunks that contain sectors 0 and 16, read the raw data, and then
///   perform full ISO 9660 directory walking to find `SYSTEM.CNF` for PSX/PS2.
/// - **Compressed CHD**: Returns `nil`; decompression requires codec
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
    /// ISO 9660 magic: "CD001"
    private static let iso9660Magic: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 8 else { return false }
        return Array(headerBytes[0..<8]) == Self.chdMagic
    }

    // MARK: - Pre-read sector data (Sendable result from sync I/O phase)

    /// Holds all sector data pre-read from the CHD on a utility thread.
    private struct CHDSectors: Sendable {
        let sector0: Data?    // Sega IP.BIN (Saturn / SegaCD / Dreamcast)
        let pvd: Data?        // ISO 9660 Primary Volume Descriptor (sector 16)
        let systemCNF: Data?  // SYSTEM.CNF content, if found via ISO directory walk
    }

    // MARK: - Public entry point

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        // Phase 1: all synchronous file I/O on a utility thread.
        let sectors = await Task.detached(priority: .utility) {
            self.readCHDSectors(from: url)
        }.value

        guard let sectors = sectors else {
            VLOG("ChdDiscSerialPlugin: no usable data from \(url.lastPathComponent)")
            return nil
        }

        // Phase 2: async dispatch to sub-plugins.

        // Sector 0 → Sega IP.BIN (Saturn / SegaCD / Dreamcast)
        if let sector0 = sectors.sector0,
           let result = await trySegaExtraction(sectorData: sector0, url: url,
                                                systemHint: systemHint) {
            return result
        }

        // SYSTEM.CNF found via ISO directory walk → PSX / PS2 product code
        if let cnfData = sectors.systemCNF,
           let result = parseSystemCNFData(cnfData, systemHint: systemHint) {
            ILOG("ChdDiscSerialPlugin: extracted serial via SYSTEM.CNF from \(url.lastPathComponent)")
            return result
        }

        // Fallback: ISO volume identifier from PVD (non-Sega discs without SYSTEM.CNF)
        if let pvdData = sectors.pvd,
           let volID = pvdData.asciiString(at: 40, length: 32),
           !volID.isEmpty {
            VLOG("ChdDiscSerialPlugin: using volume ID '\(volID)' as serial for \(url.lastPathComponent)")
            return DiscSerialResult(serial: volID)
        }

        VLOG("ChdDiscSerialPlugin: no serial found in uncompressed CHD \(url.lastPathComponent)")
        return nil
    }

    // MARK: - Synchronous CHD sector reader

    /// Reads all sectors needed for serial extraction.
    /// **Must be called from a non-cooperative thread** (e.g. via `Task.detached`).
    private func readCHDSectors(from url: URL) -> CHDSectors? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("ChdDiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        // Read and validate the CHD v5 header.
        guard (try? handle.seek(toOffset: 0)) != nil,
              let headerData = try? handle.read(upToCount: CHDv5.headerLength),
              headerData.count >= CHDv5.headerLength else {
            VLOG("ChdDiscSerialPlugin: cannot read header from \(url.lastPathComponent)")
            return nil
        }

        guard Array(headerData[0..<8]) == Self.chdMagic else { return nil }

        let version = headerData.loadBE32(at: CHDv5.versionOffset)
        guard version == 5 else {
            VLOG("ChdDiscSerialPlugin: unsupported CHD version \(version) in \(url.lastPathComponent)")
            return nil
        }

        // All 4 compressor slots must be zero for a truly uncompressed CHD.
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

        // Sanity-check unit and hunk sizes before arithmetic to prevent overflow.
        // CD-ROM units are 2448 bytes; cap at 1 MiB to reject corrupt/malformed CHDs.
        guard unitBytes <= 1_048_576 else {
            VLOG("ChdDiscSerialPlugin: unreasonably large unit size \(unitBytes) in \(url.lastPathComponent)")
            return nil
        }
        // Cap hunk size at 64 MiB. Without this guard, a crafted CHD with an extreme
        // hunkBytes value could silently overflow the UInt64 multiplication in
        // readCHDSector (hunkIndex * hunkBytes) and produce a garbage file offset.
        guard hunkBytes <= 67_108_864 else {
            VLOG("ChdDiscSerialPlugin: unreasonably large hunk size \(hunkBytes) in \(url.lastPathComponent)")
            return nil
        }

        let unitsPerHunk = hunkBytes / unitBytes

        // Convenience wrapper for reading a single sector from this CHD.
        func readSector(_ index: UInt64) -> Data? {
            readCHDSector(handle: handle, sectorIndex: index,
                          hunkBytes: hunkBytes, unitsPerHunk: unitsPerHunk,
                          unitBytes: unitBytes, mapOffset: mapOffset)
        }

        // Sector 0: Sega IP.BIN header.
        let sector0 = readSector(0)

        // Sector 16: ISO 9660 Primary Volume Descriptor.
        let pvd = readSector(16)

        // ISO 9660 directory walk to find SYSTEM.CNF (PSX / PS2).
        var systemCNF: Data?
        if let pvdData = pvd, pvdData.count >= 6,
           pvdData[1..<6].elementsEqual(Self.iso9660Magic) {
            let rootLBA = pvdData.loadLE32(at: 156 + 2)
            if rootLBA > 0, let dirData = readSector(UInt64(rootLBA)),
               let cnfLBA = ISODiscSerialPlugin().findFile(in: dirData, named: "SYSTEM.CNF") {
                systemCNF = readSector(UInt64(cnfLBA))
            }
        }

        return CHDSectors(sector0: sector0, pvd: pvd, systemCNF: systemCNF)
    }

    // MARK: - Sega extraction helper

    /// Tries to extract a Sega product code from the raw user-data bytes of
    /// sector 0, writing a temp file the SegaDiscSerialPlugin can open.
    private func trySegaExtraction(sectorData: Data, url: URL,
                                   systemHint: String?) async -> DiscSerialResult? {
        let plugin = SegaDiscSerialPlugin()
        guard plugin.matchesMagicBytes(sectorData) else { return nil }

        return await withTempFile(data: sectorData, stem: url.deletingPathExtension().lastPathComponent,
                                  ext: "bin") { tmpURL in
            await plugin.extractSerial(from: tmpURL, systemHint: systemHint)
        }
    }

    // MARK: - SYSTEM.CNF parsing

    /// Parses a SYSTEM.CNF data buffer and returns a PSX/PS2 serial result.
    /// Reuses `ISODiscSerialPlugin.normalizeSerial` for consistent normalisation.
    private func parseSystemCNFData(_ data: Data, systemHint: String?) -> DiscSerialResult? {
        guard let text = String(data: data, encoding: .ascii)
                      ?? String(data: data, encoding: .isoLatin1) else { return nil }

        let isoPlugin = ISODiscSerialPlugin()

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            let isPS2 = upper.hasPrefix("BOOT2")
            let isPSX = !isPS2 && upper.hasPrefix("BOOT")
            guard isPS2 || isPSX else { continue }

            guard let eqRange = trimmed.range(of: "=") else { continue }
            let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            let pathPart = value
                .replacingOccurrences(of: "\\", with: "/")
                .components(separatedBy: "/").last?
                .components(separatedBy: ";").first ?? ""

            let normalized = isoPlugin.normalizeSerial(pathPart)
            guard !normalized.isEmpty else { continue }

            let hint = isPS2 ? "com.provenance.ps2" : "com.provenance.psx"
            return DiscSerialResult(serial: normalized, systemIdentifierHint: hint)
        }
        return nil
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

        // unitBytes was already validated to be <= 1_048_576 by the caller.
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
