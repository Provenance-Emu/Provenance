/// DiscTypes.swift
/// PVOpticalDiscReader
///
/// Shared data types describing optical disc structure (TOC, tracks, sectors).
/// These types are used by both the IPC bridge and the disc ripping UI.

import Foundation

// MARK: - Disc Type

/// The detected type of an inserted disc.
public enum DiscType: String, Sendable, CaseIterable {
    /// Unknown or not yet detected.
    case unknown = "Unknown"
    /// Standard audio CD (Red Book).
    case audioCD = "Audio CD"
    /// CD-ROM data disc (Yellow Book Mode 1).
    case dataCD = "Data CD"
    /// Mixed-mode disc with data track 1 and audio tracks (Mode 1 + Audio).
    case mixedMode = "Mixed Mode"
    /// CD-ROM XA / PlayStation 1 format (Yellow Book Mode 2 / Green Book).
    case cdromXA = "CD-ROM XA"
    /// Sega Saturn / early PC-FX discs (CD-ROM XA with special header).
    case saturnDisc = "Sega Saturn"
    /// Neo Geo CD.
    case neoGeoCD = "Neo Geo CD"
    /// PC Engine CD-ROM² / TurboGrafx-CD.
    case pcEngineCD = "PC Engine CD"
    /// Sega Mega CD / Sega CD.
    case megaCD = "Mega CD"
    /// 3DO Interactive Multiplayer.
    case threeDO = "3DO"
}

// MARK: - Track Info

/// Describes a single track on an optical disc.
public struct DiscTrackInfo: Sendable, Identifiable {
    public let id: UUID
    /// Track number (1-based, as reported by the drive).
    public let trackNumber: Int
    /// True if this is an audio track; false if data.
    public let isAudio: Bool
    /// Start address in MSF (minutes / seconds / frames) notation.
    public let startMSF: MSFAddress
    /// Start address as a logical block address.
    public let startLBA: UInt32
    /// Length of the track in sectors.
    public let sectorCount: UInt32

    public init(
        id: UUID = UUID(),
        trackNumber: Int,
        isAudio: Bool,
        startMSF: MSFAddress,
        startLBA: UInt32,
        sectorCount: UInt32
    ) {
        self.id = id
        self.trackNumber = trackNumber
        self.isAudio = isAudio
        self.startMSF = startMSF
        self.startLBA = startLBA
        self.sectorCount = sectorCount
    }

    /// Size of this track in bytes (raw 2352-byte sectors).
    public var sizeBytes: Int { Int(sectorCount) * 2352 }
}

// MARK: - MSF Address

/// Disc address in Minutes / Seconds / Frames format.
/// Standard CD addressing: 75 frames/second, 60 seconds/minute.
public struct MSFAddress: Sendable, Equatable, CustomStringConvertible {
    public let minutes: UInt8
    public let seconds: UInt8
    public let frames: UInt8

    public init(minutes: UInt8, seconds: UInt8, frames: UInt8) {
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
    }

    /// Convert MSF to a logical block address (LBA).
    /// Formula: LBA = (M×60 + S)×75 + F − 150 (2-second pregap offset).
    public var lba: UInt32 {
        let totalFrames = (UInt32(minutes) * 60 + UInt32(seconds)) * 75 + UInt32(frames)
        return totalFrames > 150 ? totalFrames - 150 : 0
    }

    public var description: String { String(format: "%02d:%02d:%02d", minutes, seconds, frames) }
}

// MARK: - Table of Contents

/// Parsed table of contents for an optical disc.
public struct DiscTOC: Sendable {
    /// All tracks on the disc, sorted by track number.
    public let tracks: [DiscTrackInfo]
    /// Detected disc type based on track layout and data headers.
    public let discType: DiscType
    /// Total number of sectors on the disc.
    public let totalSectors: UInt32

    public init(tracks: [DiscTrackInfo], discType: DiscType = .unknown, totalSectors: UInt32) {
        self.tracks = tracks
        self.discType = discType
        self.totalSectors = totalSectors
    }

    public var isEmpty: Bool { tracks.isEmpty }
    public var trackCount: Int { tracks.count }

    /// Returns the first data track, or nil if this is an audio-only disc.
    public var firstDataTrack: DiscTrackInfo? { tracks.first(where: { !$0.isAudio }) }

    /// Returns all audio tracks.
    public var audioTracks: [DiscTrackInfo] { tracks.filter(\.isAudio) }
}

// MARK: - Rip Progress

/// Progress information for an in-flight disc rip operation.
public struct RipProgress: Sendable {
    /// Current sector being read.
    public let currentSector: UInt32
    /// Total sectors to read.
    public let totalSectors: UInt32
    /// Current track being ripped (1-based).
    public let currentTrack: Int
    /// Total number of tracks.
    public let totalTracks: Int
    /// Fraction complete in [0.0, 1.0].
    public var fraction: Double {
        totalSectors > 0 ? Double(currentSector) / Double(totalSectors) : 0
    }
}
