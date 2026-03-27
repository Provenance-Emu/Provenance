//
//  GdiDiscSerialPlugin.swift
//  PVHashing
//
//  Disc-serial extraction for Dreamcast GD-ROM images (GDI format).
//

import Foundation
import PVLogging

/// Extracts product codes from Dreamcast GD-ROM images in GDI format (`.gdi`).
///
/// ## GDI Format
/// A `.gdi` file is a plain-text track listing, similar to a CUE sheet.
/// The first line is the total track count; subsequent lines describe each track:
/// ```
/// 3
/// 1 0 4 2048 track01.bin 0
/// 2 1 0 2352 track02.raw 0
/// 3 45000 4 2048 track03.bin 0
/// ```
/// Fields: `<num> <lba> <type> <sector_size> <filename> <unknown>`
/// - `type 4` = data track; `type 0` = audio track
/// - The high-density area (Dreamcast game data) is always the last data track
///   (conventionally track 3, starting at LBA 45000).
///
/// ## Strategy
/// 1. Parse the `.gdi` to find the last data track (`type == 4`).
/// 2. Resolve the track's binary file path.
/// 3. Delegate to ``SegaDiscSerialPlugin`` to read the Dreamcast IP.BIN header
///    and extract the product code (e.g. `T-12345H`).
public struct GdiDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["gdi"]

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        guard let trackURL = resolveHighDensityTrack(gdiURL: url) else {
            VLOG("GdiDiscSerialPlugin: no data track found in \(url.lastPathComponent)")
            return nil
        }
        VLOG("GdiDiscSerialPlugin: high-density track → \(trackURL.lastPathComponent)")
        return await SegaDiscSerialPlugin().extractSerial(from: trackURL, systemHint: systemHint)
    }

    // MARK: - GDI parsing

    /// Parsed representation of a single GDI track entry.
    private struct GDITrack {
        let number: Int
        let lba: Int
        let type: Int       // 0 = audio, 4 = data
        let sectorSize: Int
        let filename: String
    }

    /// Parses the `.gdi` and returns the URL of the last data-type track binary.
    private func resolveHighDensityTrack(gdiURL: URL) -> URL? {
        guard let content = (try? String(contentsOf: gdiURL, encoding: .utf8))
                         ?? (try? String(contentsOf: gdiURL, encoding: .isoLatin1)) else {
            WLOG("GdiDiscSerialPlugin: cannot read \(gdiURL.lastPathComponent)")
            return nil
        }

        let gdiDir = gdiURL.deletingLastPathComponent()
        var lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        // First line is the track count — skip it.
        lines.removeFirst()

        var dataTracks: [GDITrack] = []
        for line in lines {
            if let track = parseTrackLine(line) {
                if track.type == 4 { dataTracks.append(track) }
            }
        }

        // The high-density area is the last data track in the listing.
        guard let hdTrack = dataTracks.last else {
            WLOG("GdiDiscSerialPlugin: no data tracks in \(gdiURL.lastPathComponent)")
            return nil
        }

        return resolveFile(hdTrack.filename, in: gdiDir)
    }

    /// Parses one GDI track line into a ``GDITrack``.
    ///
    /// Expected format: `<num> <lba> <type> <sector_size> <filename> <unknown>`
    /// The filename may optionally be quoted.
    private func parseTrackLine(_ line: String) -> GDITrack? {
        let tokens = line.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard tokens.count >= 5 else { return nil }

        guard let number = Int(tokens[0]),
              let lba    = Int(tokens[1]),
              let type   = Int(tokens[2]),
              let sector = Int(tokens[3]) else { return nil }

        // The filename (token index 4) may be quoted.
        let filename = tokens[4]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .replacingOccurrences(of: "\\", with: "/")

        return GDITrack(number: number, lba: lba, type: type,
                        sectorSize: sector, filename: filename)
    }

    /// Resolves a GDI-relative filename to an absolute URL with a
    /// case-insensitive filesystem fallback.
    private func resolveFile(_ filename: String, in directory: URL) -> URL? {
        let candidateURL = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }
        let lower = filename.lowercased()
        guard let contents = try? FileManager.default
                .contentsOfDirectory(atPath: directory.path) else { return nil }
        if let match = contents.first(where: { $0.lowercased() == lower }) {
            return directory.appendingPathComponent(match)
        }
        WLOG("GdiDiscSerialPlugin: track file not found: \(filename)")
        return nil
    }
}
