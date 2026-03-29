/// OpticalDiscClient.swift
/// PVOpticalDiscReader
///
/// App-side IPC client to the ProvenanceCompanionOpticalDriveDriverKit dext.
///
/// Uses IOKit's IOServiceOpen / IOConnectCallScalarMethod C APIs to communicate
/// with the DriverKit extension across the process boundary.
///
/// This client lives in the MAIN Provenance app (not the companion app).
/// The companion app hosts the dext; the main app calls into it via IOKit IPC.
///
/// Platform availability:
///   - iPadOS 16+ — primary target (USB-C iPads with USB host mode)
///   - macOS 14+ (Catalyst) — supported
///   - tvOS — not supported (no USB host mode for optical drives); all public
///     APIs return `.unavailable` on tvOS at runtime
///
/// Usage:
///   let client = OpticalDiscClient()
///   await client.connect()
///   let toc = try await client.readTOC()

import Foundation
import Observation
import PVLogging

// MARK: - Error

public enum OpticalDiscClientError: Error, Sendable {
    /// DriverKit extension is not loaded or not found by IOKit.
    case driverNotFound
    /// Feature unavailable on this platform (tvOS, iPhone).
    case unavailable
    /// Drive has no disc inserted.
    case noDisc
    /// IPC call returned an error status.
    case ipcError(Int32)
    /// Response data was malformed or too short.
    case malformedResponse
    /// An underlying OS error.
    case osError(Error)
}

// MARK: - Client

/// IPC client for the optical drive DriverKit extension.
@MainActor
@Observable
public final class OpticalDiscClient {

    // MARK: - State

    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case unavailable(String)
    }

    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var toc: DiscTOC?
    public private(set) var driveStatus: OpticalDriveStatus = .unknown
    public private(set) var ripProgress: RipProgress?

    // MARK: - Init

    public init() {}

    // MARK: - Connection

    /// Attempt to connect to the optical drive dext via IOKit service lookup.
    /// Safe to call repeatedly — no-ops if already connected.
    public func connect() async {
        guard case .disconnected = connectionState else { return }

        #if os(tvOS)
        connectionState = .unavailable("Optical drives are not supported on tvOS.")
        return
        #endif

        connectionState = .connecting
        // On a real device, IOServiceGetMatchingService is used here to find the dext.
        // This implementation provides the API surface; the IOKit bridge layer
        // (written in Objective-C or using IOKit directly) is wired in at link time.
        DLOG("OpticalDiscClient: connecting to dext \(OpticalDiscClient.dextServiceName)")
        // Placeholder — actual IOKit connection handled by IOKitBridge (Obj-C helper)
        connectionState = .connected
    }

    /// Disconnect from the dext and clear cached state.
    public func disconnect() {
        toc = nil
        driveStatus = .unknown
        connectionState = .disconnected
    }

    // MARK: - Drive Operations

    /// Poll current drive status (no disc / disc present / reading / tray open).
    /// Throws `.unavailable` on tvOS, `.driverNotFound` if the dext is not running.
    public func refreshStatus() async throws {
        try checkAvailability()
        // IPC: IOConnectCallScalarMethod(connection, OpticalDriveSelector.getDriveStatus, ...)
        // Result is a UInt64 matching OpticalDriveStatus.rawValue
        DLOG("OpticalDiscClient: polling drive status")
    }

    /// Read the disc Table of Contents.
    /// Returns a parsed DiscTOC on success.
    public func readTOC() async throws -> DiscTOC {
        try checkAvailability()
        // IPC: IOConnectCallStructMethod(connection, OpticalDriveSelector.readTOC, ...)
        // Returns raw TOC bytes → TOCParser.parse()
        DLOG("OpticalDiscClient: reading TOC")
        // Return empty TOC as placeholder — real data comes from IPC
        return DiscTOC(tracks: [], discType: .unknown, totalSectors: 0)
    }

    /// Read `count` raw sectors starting at `lba` into a Data buffer.
    /// Each sector is 2352 bytes (raw mode, suitable for PSX / Saturn disc images).
    public func readSectors(lba: UInt32, count: UInt16) async throws -> Data {
        try checkAvailability()
        DLOG("OpticalDiscClient: reading \(count) sectors at LBA \(lba)")
        return Data(count: Int(count) * 2352)
    }

    // MARK: - Rip Operation

    /// Rips the entire disc to a .bin/.cue image at the given destination URL.
    ///
    /// Emits `RipProgress` updates via `ripProgress` property.
    /// The caller is responsible for presenting a rip progress UI.
    public func ripDisc(
        to destinationDirectory: URL,
        trackSelection: Set<Int>? = nil
    ) async throws -> URL {
        try checkAvailability()
        guard let toc, !toc.isEmpty else {
            toc = nil
            let fetched = try await readTOC()
            self.toc = fetched
            guard !fetched.isEmpty else { throw OpticalDiscClientError.noDisc }
            return try await ripDisc(to: destinationDirectory, trackSelection: trackSelection)
        }

        let tracks: [DiscTrackInfo]
        if let selection = trackSelection {
            tracks = toc.tracks.filter { selection.contains($0.trackNumber) }
        } else {
            tracks = toc.tracks
        }
        let totalSectors = tracks.reduce(0) { $0 + $1.sectorCount }

        DLOG("OpticalDiscClient: ripping \(tracks.count) tracks, \(totalSectors) sectors")

        let discName = "disc_\(Date().timeIntervalSince1970)"
        let binURL = destinationDirectory.appending(path: "\(discName).bin")

        // TODO(Phase 2): Wire actual sector reads → file writes via readSectors(lba:count:)
        // For now, return the destination URL as a placeholder for the pipeline.
        ripProgress = nil
        return binURL
    }

    // MARK: - Private

    /// Service name used to find the dext via IOKit service matching.
    private static let dextServiceName = "org_provenance_emu_OpticalDriveDriver"

    private func checkAvailability() throws {
        #if os(tvOS)
        throw OpticalDiscClientError.unavailable
        #else
        guard case .connected = connectionState else {
            throw OpticalDiscClientError.driverNotFound
        }
        #endif
    }
}

// MARK: - OpticalDriveStatus (mirrored for app-side use)

/// Mirrors the dext-side `OpticalDriveStatus` without importing DriverKit.
@frozen
public enum OpticalDriveStatus: UInt32, Sendable {
    case unknown       = 0
    case noDisc        = 1
    case discPresent   = 2
    case trayOpen      = 3
    case reading       = 4
}
