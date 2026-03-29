/// TOCParser.swift
/// PVOpticalDiscReader
///
/// Parses the raw TOC byte array returned by the SCSI READ TOC command
/// (format 0x00, full TOC with MSF addresses) into a typed DiscTOC model.
///
/// TOC response layout (SCSI MMC-5 §6.27):
///   Bytes 0-1: TOC Data Length (big-endian, excludes these 2 bytes)
///   Byte  2:   First track number
///   Byte  3:   Last track number
///   Bytes 4+:  Track descriptors (8 bytes each):
///     [0] Reserved
///     [1] ADR/Control (bit 2 set = data track)
///     [2] Track number (0xAA = lead-out)
///     [3] Reserved
///     [4] Minutes (MSF)
///     [5] Seconds (MSF)
///     [6] Frames (MSF)
///     [7] Reserved

import Foundation

public enum TOCParser {

    /// Parses raw TOC bytes into a DiscTOC.
    /// Returns nil if the data is malformed or too short.
    public static func parse(_ bytes: [UInt8], totalSectors: UInt32) -> DiscTOC? {
        guard bytes.count >= 4 else { return nil }

        let tocLength = Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        guard bytes.count >= tocLength + 2 else { return nil }

        let firstTrack = Int(bytes[2])
        let lastTrack  = Int(bytes[3])
        guard firstTrack >= 1, lastTrack >= firstTrack else { return nil }

        var tracks: [DiscTrackInfo] = []
        var leadOutLBA: UInt32 = totalSectors
        let offset = 4

        var index = offset
        while index + 7 < bytes.count {
            let control    = bytes[index + 1]
            let trackNum   = bytes[index + 2]
            let minutes    = bytes[index + 4]
            let seconds    = bytes[index + 5]
            let frames     = bytes[index + 6]

            let msf = MSFAddress(minutes: minutes, seconds: seconds, frames: frames)
            let lba = msf.lba

            if trackNum == 0xAA {
                // Lead-out track — marks end of last track
                leadOutLBA = lba
            } else if trackNum >= 1 {
                let isAudio = (control & 0x04) == 0
                tracks.append(DiscTrackInfo(
                    trackNumber: Int(trackNum),
                    isAudio: isAudio,
                    startMSF: msf,
                    startLBA: lba,
                    sectorCount: 0 // filled in after parsing all tracks
                ))
            }
            index += 8
        }

        // Fill in sector counts: each track ends where the next begins.
        tracks.sort { $0.trackNumber < $1.trackNumber }
        var resolved: [DiscTrackInfo] = []
        for (i, track) in tracks.enumerated() {
            let nextStart = i + 1 < tracks.count ? tracks[i + 1].startLBA : leadOutLBA
            let count = nextStart > track.startLBA ? nextStart - track.startLBA : 0
            resolved.append(DiscTrackInfo(
                id: track.id,
                trackNumber: track.trackNumber,
                isAudio: track.isAudio,
                startMSF: track.startMSF,
                startLBA: track.startLBA,
                sectorCount: count
            ))
        }

        let discType = detectDiscType(tracks: resolved)
        return DiscTOC(tracks: resolved, discType: discType, totalSectors: totalSectors)
    }

    // MARK: - Disc Type Detection

    /// Infers disc type from the track layout.
    /// Refined detection (e.g. reading system area) is done in OpticalDiscClient.
    private static func detectDiscType(tracks: [DiscTrackInfo]) -> DiscType {
        let hasData  = tracks.contains(where: { !$0.isAudio })
        let hasAudio = tracks.contains(where: { $0.isAudio })

        if !hasData { return .audioCD }
        if hasData && !hasAudio { return .dataCD }
        if hasData && hasAudio {
            // If track 1 is data and remaining are audio → mixed mode (PSX-style)
            if let first = tracks.first, !first.isAudio {
                return .mixedMode
            }
        }
        return .unknown
    }
}
