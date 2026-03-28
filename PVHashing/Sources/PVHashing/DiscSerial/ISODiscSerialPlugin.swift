//
//  ISODiscSerialPlugin.swift
//  PVHashing
//
//  Extracts disc serials from plain ISO 9660 images, including PSX/PS2
//  discs by locating SYSTEM.CNF on the filesystem.
//

import Foundation
import PVLogging

/// Extracts disc serials from ISO 9660 disc images (`.iso`, `.img`).
///
/// ## PSX / PS2
/// Walks the ISO 9660 path table from LBA 16 to find `SYSTEM.CNF` in the
/// root directory, then parses the `BOOT` (PSX) or `BOOT2` (PS2) key to
/// extract the product code, e.g. `SLUS-01234`.
///
/// ## Raw-sector BIN (2352 bytes/sector)
/// Automatically detects whether the file uses 2048-byte cooked sectors
/// (plain ISO) or 2352-byte raw sectors (BIN from a rip), and adjusts the
/// LBA-to-byte mapping accordingly.
///
/// ## Other ISO 9660 discs
/// Returns the volume identifier string from the Primary Volume Descriptor
/// as a best-effort serial when no SYSTEM.CNF is found.
public struct ISODiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["iso", "img"]
    /// We need to read at least past the ISO 9660 magic at PVD offset 1
    /// (file offset 32769). Read 37 KB to cover both cooked (32768) and
    /// raw-sector (37632) PVD locations without committing to a full read.
    public let magicByteCount = 37_700

    // ISO 9660 magic: "CD001" at byte 1 of the Primary Volume Descriptor.
    private static let iso9660Magic: [UInt8] = [0x43, 0x44, 0x30, 0x30, 0x31]

    public func matchesMagicBytes(_ headerBytes: Data) -> Bool {
        // Cooked ISO: PVD at LBA 16 = offset 32768; magic at +1 = 32769.
        if headerBytes.count > 32_773 &&
            headerBytes[32769..<32774].elementsEqual(Self.iso9660Magic) {
            return true
        }
        // Raw 2352-byte/sector BIN: LBA 16 at 16*2352 = 37632; data at +16 = 37648; magic at +1 = 37649.
        if headerBytes.count > 37_653 &&
            headerBytes[37649..<37654].elementsEqual(Self.iso9660Magic) {
            return true
        }
        // Raw 2336-byte/sector (Mode 2 without sync): LBA 16 at 16*2336 = 37376; data at +8 = 37384; magic at +1 = 37385.
        if headerBytes.count > 37_389 &&
            headerBytes[37385..<37390].elementsEqual(Self.iso9660Magic) {
            return true
        }
        // If we couldn't read enough bytes, let extractSerial try anyway.
        if headerBytes.count < 37_700 { return true }
        return false
    }

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        return await Task.detached(priority: .utility) {
            self._extractSerial(from: url, systemHint: systemHint)
        }.value
    }

    // MARK: - Implementation

    private func _extractSerial(from url: URL, systemHint: String?) -> DiscSerialResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            WLOG("ISODiscSerialPlugin: cannot open \(url.lastPathComponent)")
            return nil
        }
        defer { try? handle.close() }

        let sectorLayout = detectSectorLayout(handle: handle)
        guard let pvd = readPVD(handle: handle, layout: sectorLayout) else {
            VLOG("ISODiscSerialPlugin: no PVD found in \(url.lastPathComponent)")
            return nil
        }

        // Root directory record is at PVD offset 156.
        let rootLBA  = pvd.loadLE32(at: 156 + 2)
        let rootSize = pvd.loadLE32(at: 156 + 10)
        guard rootLBA > 0, rootSize > 0 else { return nil }

        guard let dirData = readSector(handle: handle, lba: rootLBA,
                                       size: Int(rootSize), layout: sectorLayout) else {
            return nil
        }

        // Look for SYSTEM.CNF first (PSX / PS2).
        if let cnfLBA = findFile(in: dirData, named: "SYSTEM.CNF") {
            return readSystemCNF(handle: handle, lba: cnfLBA,
                                 layout: sectorLayout, systemHint: systemHint)
        }

        // Presence of PSX.EXE also identifies PSX discs.
        if findFile(in: dirData, named: "PSX.EXE") != nil {
            return DiscSerialResult(serial: "PSX.EXE",
                                    systemIdentifierHint: "com.provenance.psx")
        }

        // Fall back to volume identifier from PVD (offset 40, length 32).
        if let volID = pvd.asciiString(at: 40, length: 32), !volID.isEmpty {
            VLOG("ISODiscSerialPlugin: using volume ID '\(volID)' as serial for \(url.lastPathComponent)")
            return DiscSerialResult(serial: volID)
        }

        return nil
    }

    // MARK: - Sector layout detection

    private enum SectorLayout {
        case cooked   // 2048 bytes/sector — plain .iso
        case raw2352  // 2352 bytes/sector raw BIN; data starts at byte 16 of each sector
        case raw2336  // 2336 bytes/sector (Mode 2 without sync); data at byte 8

        var sectorSize: Int {
            switch self {
            case .cooked:  return 2048
            case .raw2352: return 2352
            case .raw2336: return 2336
            }
        }

        /// Byte offset within each sector where user data begins.
        var dataOffset: Int {
            switch self {
            case .cooked:  return 0
            case .raw2352: return 16
            case .raw2336: return 8
            }
        }
    }

    private func detectSectorLayout(handle: FileHandle) -> SectorLayout {
        // Helper: seek and read 5 bytes; returns nil on failure.
        func readMagicAt(_ offset: UInt64) -> Data? {
            guard (try? handle.seek(toOffset: offset)) != nil else { return nil }
            return try? handle.read(upToCount: 5)
        }

        // Cooked ISO: PVD at offset 32768, magic at byte 32769.
        if let data = readMagicAt(32769),
           data.count == 5,
           data.elementsEqual(ISODiscSerialPlugin.iso9660Magic) {
            return .cooked
        }

        // Raw 2352-byte/sector: LBA 16 at 16*2352 = 37632; data offset +16 = 37648; magic at +1 = 37649.
        if let data = readMagicAt(37649),
           data.count == 5,
           data.elementsEqual(ISODiscSerialPlugin.iso9660Magic) {
            return .raw2352
        }

        // Raw 2336-byte/sector: LBA 16 at 16*2336 = 37376; data offset +8 = 37384; magic at +1 = 37385.
        if let data = readMagicAt(37385),
           data.count == 5,
           data.elementsEqual(ISODiscSerialPlugin.iso9660Magic) {
            return .raw2336
        }

        return .cooked // default
    }

    private func readPVD(handle: FileHandle, layout: SectorLayout) -> Data? {
        return readSector(handle: handle, lba: 16, size: 2048, layout: layout)
    }

    /// Reads `size` bytes of user data starting at `lba`, respecting sector layout.
    private func readSector(handle: FileHandle, lba: UInt32, size: Int,
                             layout: SectorLayout) -> Data? {
        var result = Data()
        result.reserveCapacity(size)

        var remaining = size
        var currentLBA = lba

        while remaining > 0 {
            let fileOffset = UInt64(currentLBA) * UInt64(layout.sectorSize)
                           + UInt64(layout.dataOffset)
            guard (try? handle.seek(toOffset: fileOffset)) != nil else { return nil }
            let toRead = min(remaining, 2048)
            guard let chunk = try? handle.read(upToCount: toRead), !chunk.isEmpty else { return nil }
            result.append(chunk)
            remaining -= chunk.count
            currentLBA += 1
            // A short read means we hit EOF before reading a full sector worth of
            // user data.  Do not attempt to advance to the next LBA — the data is
            // incomplete and any further seek would produce garbage output.
            if chunk.count < toRead { break }
        }

        return result
    }

    // MARK: - ISO 9660 directory walking

    /// Walks an ISO 9660 directory record block looking for a file named `name`
    /// (case-insensitive). Returns the file's LBA on success.
    ///
    /// ISO 9660 directory record layout:
    /// ```
    /// Byte 0:     Record length
    /// Byte 1:     Extended attribute record length
    /// Bytes 2–5:  Location of extent (LE UInt32)
    /// Bytes 10–13: Data length (LE UInt32)
    /// Byte 32:    File identifier length
    /// Bytes 33+:  File identifier (uppercased ASCII, no null terminator)
    /// ```
    private func findFile(in dirData: Data, named name: String) -> UInt32? {
        let target = name.uppercased()
        var offset = 0

        while offset < dirData.count {
            let recordLength = Int(dirData[offset])
            guard recordLength > 0 else { break }
            guard offset + recordLength <= dirData.count else { break }

            let idLength = Int(dirData[offset + 32])
            guard idLength > 0, offset + 33 + idLength <= dirData.count else {
                offset += recordLength
                continue
            }

            let idBytes = dirData[(offset + 33)..<(offset + 33 + idLength)]
            if let identifier = String(bytes: idBytes, encoding: .ascii)?
                .uppercased()
                // Strip ";1" version suffix used by some mastering tools.
                .components(separatedBy: ";").first {
                if identifier == target {
                    return dirData.loadLE32(at: offset + 2)
                }
            }
            // Records are aligned to even byte boundaries.
            offset += recordLength
            if offset % 2 != 0 { offset += 1 }
        }
        return nil
    }

    // MARK: - SYSTEM.CNF parsing

    private func readSystemCNF(handle: FileHandle, lba: UInt32,
                                layout: SectorLayout,
                                systemHint: String?) -> DiscSerialResult? {
        guard let cnfData = readSector(handle: handle, lba: lba, size: 512, layout: layout),
              let text = String(data: cnfData, encoding: .ascii)
                      ?? String(data: cnfData, encoding: .isoLatin1) else {
            return nil
        }

        // SYSTEM.CNF format (PSX):  BOOT = cdrom:\SLUS_01234;1\main.exe
        // SYSTEM.CNF format (PS2):  BOOT2 = cdrom0:\SCES_123.45;1
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isPS2 = trimmed.uppercased().hasPrefix("BOOT2")
            let isPSX = !isPS2 && trimmed.uppercased().hasPrefix("BOOT")
            guard isPS2 || isPSX else { continue }

            // Extract the value after '='.
            guard let eqRange = trimmed.range(of: "=") else { continue }
            let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // The game ID is a path component matching the pattern:
            //   SLUS_012.34, SCES_123.45, SLES_012.34, NTSC_xxx, etc.
            // We extract the last path component before the semicolon.
            let pathPart = value
                .replacingOccurrences(of: "\\", with: "/")
                .components(separatedBy: "/")
                .last?
                .components(separatedBy: ";").first ?? ""

            let normalized = normalizeSerial(pathPart)
            guard !normalized.isEmpty else { continue }

            let hint = isPS2 ? "com.provenance.ps2" : "com.provenance.psx"
            ILOG("ISODiscSerialPlugin: found serial '\(normalized)' in SYSTEM.CNF (\(isPS2 ? "PS2" : "PSX"))")
            return DiscSerialResult(serial: normalized, systemIdentifierHint: hint)
        }
        return nil
    }

    // MARK: - Serial normalisation

    /// Normalises a PSX/PS2 game ID to the standard `XXXX-NNNNN` format.
    ///
    /// Input examples:
    /// - `SLUS_01234`    → `SLUS-01234`
    /// - `SLUS_01234.EXE` → `SLUS-01234`  (strips alphabetic extension)
    /// - `SCES_533.45`   → `SCES-53345`   (combines digit halves, no extension to strip)
    /// - `SCES_123.45`   → `SCES-12345`
    private func normalizeSerial(_ raw: String) -> String {
        // Strip trailing version markers like ";1".
        let clean = (raw.components(separatedBy: ";").first ?? raw)
            .trimmingCharacters(in: .whitespaces)

        let parts = clean.components(separatedBy: "_")
        guard parts.count >= 2 else { return clean.uppercased() }

        let prefix = parts[0].uppercased()

        // Collect everything after the first underscore.
        // For `SLUS_01234.EXE` that is `"01234.EXE"`.
        // For `SCES_533.45`   that is `"533.45"`.
        // We take only leading digits and dots, stopping at the first alphabetic
        // character (the start of a file extension like `.EXE`), then strip dots.
        let afterUnderscore = parts[1...].joined(separator: "_")
        let digitDotPart = afterUnderscore.prefix(while: { $0.isNumber || $0 == "." })
        let digits = String(digitDotPart).replacingOccurrences(of: ".", with: "")

        let result = "\(prefix)-\(digits)"
        // Sanity: must look like a product code (letters dash digits).
        guard result.range(of: #"^[A-Z]{2,4}-\d{4,6}$"#, options: .regularExpression) != nil else {
            // Return cleaned-up version even if it doesn't match perfectly.
            return clean.uppercased().replacingOccurrences(of: "_", with: "-")
        }
        return result
    }
}
