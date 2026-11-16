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
/// ## What is read
/// CHD v5 files, through `CHDImage`, which decompresses only the hunks asked for:
/// the one holding sector 0 (Sega IP.BIN), the one holding sector 16 (the
/// ISO 9660 volume descriptor), then the root directory and `SYSTEM.CNF` for
/// PlayStation discs.
///
/// - Codecs read: none, `zlib`, `lzma`, `cdzl`, `cdlz`.
/// - Codecs not read: `zstd`, `cdzs`, `flac`, `cdfl`, `huff`. A disc whose
///   first sectors use one of these returns `nil`, as do parent (delta) CHDs
///   and CHD v1 to v4.
/// - Off Apple platforms there is no DEFLATE, so `zlib` and `cdzl` hunks are not read.
///
/// ## Sector layout
/// A CD-ROM CHD stores 2448-byte frames. The 2048 bytes of user data sit at a
/// different offset for each track type (0 cooked, 8 MODE2/2336, 16 MODE1 raw,
/// 24 MODE2 raw), so the offset is found by looking for the volume descriptor
/// rather than assumed. A DVD CHD stores plain 2048-byte sectors.
///
/// Only the first track is read. A GD-ROM's boot header is in its third track,
/// so Dreamcast CHDs are not identified yet.
public struct ChdDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["chd"]
    /// "MComprHD" is 8 bytes; we also need up to the `compressors` field at
    /// offset 16 to decide whether the CHD is uncompressed.
    public let magicByteCount = 32

    // CHD magic: "MComprHD" (8 ASCII bytes).
    private static let chdMagic: [UInt8] = [
        0x4D, 0x43, 0x6F, 0x6D, 0x70, 0x72, 0x48, 0x44  // "MComprHD"
    ]

    /// ISO 9660 magic: "CD001"
    fileprivate static let iso9660Magic: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]

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

        guard let image = CHDImage(handle: handle) else {
            VLOG("ChdDiscSerialPlugin: not a CHD v5 this reader can address: \(url.lastPathComponent)")
            return nil
        }
        guard let layout = SectorLayout(image: image) else {
            ILOG("ChdDiscSerialPlugin: cannot read the first sectors of \(url.lastPathComponent): unsupported codec (such as zstd) or a parent CHD")
            return nil
        }

        func readSector(_ index: UInt64) -> Data? {
            layout.sector(Int(index), of: image)
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

    // MARK: - Sector layout

    /// Where the 2048 bytes of user data sit inside one unit of a CHD.
    private struct SectorLayout {
        private static let userBytes = 2048
        private static let volumeDescriptorSector = 16
        /// Cooked, MODE2/2336, MODE1 raw, MODE2 raw form 1.
        private static let cdPayloadOffsets = [0, 8, 16, 24]
        private static let rawMode1Offset = 16
        private static let rawMode2Offset = 24
        /// The mode byte follows the 12-byte sync pattern and the 3-byte address.
        private static let modeByteIndex = 15

        let payloadOffset: Int

        /// Nil when neither sector 16 nor sector 0 can be read.
        init?(image: CHDImage) {
            guard image.unitBytes == CHDImage.CDFrame.bytes else {
                // DVD and hard-disc CHDs hold plain sectors.
                payloadOffset = 0
                return
            }
            if let frame = image.unit(Self.volumeDescriptorSector),
               let offset = Self.cdPayloadOffsets.first(where: { Self.hasVolumeDescriptor(frame, at: $0) }) {
                payloadOffset = offset
                return
            }
            // No ISO 9660 volume: a raw sector starts with the sync pattern, and its mode follows the address.
            guard let first = image.unit(0) else { return nil }
            let bytes = [UInt8](first.prefix(Self.modeByteIndex + 1))
            if bytes.count > Self.modeByteIndex, Array(bytes.prefix(CHDImage.CDFrame.sync.count)) == CHDImage.CDFrame.sync {
                payloadOffset = bytes[Self.modeByteIndex] == 2 ? Self.rawMode2Offset : Self.rawMode1Offset
            } else {
                payloadOffset = 0
            }
        }

        func sector(_ index: Int, of image: CHDImage) -> Data? {
            guard let unit = image.unit(index) else { return nil }
            guard unit.count >= payloadOffset + Self.userBytes else { return unit }
            let start = unit.startIndex + payloadOffset
            return unit.subdata(in: start..<(start + Self.userBytes))
        }

        private static func hasVolumeDescriptor(_ frame: Data, at offset: Int) -> Bool {
            let magic = ChdDiscSerialPlugin.iso9660Magic
            guard frame.count >= offset + 1 + magic.count else { return false }
            let start = frame.startIndex + offset + 1
            return frame[start..<(start + magic.count)].elementsEqual(magic)
        }
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
