/// RipperViewModel.swift
/// PVUI
///
/// @Observable view model for the disc ripper UI.
/// Manages drive/disc state, TOC loading, rip progress, and recent rips.
/// Lives on the @MainActor; all properties are safe to bind from SwiftUI.

import Foundation
import Observation
import PVOpticalDiscReader
import PVLogging

// MARK: - Ripped Disc Record

/// A record of a completed (or failed) rip, shown in the Recent Rips list.
public struct RippedDisc: Identifiable, Sendable {
    public enum Status: Sendable {
        case success(url: URL)
        case failed(reason: String)
    }

    public let id: UUID
    public let discType: DiscType
    public let trackCount: Int
    public let date: Date
    public let status: Status

    public var isSuccess: Bool {
        if case .success = status { return true }
        return false
    }

    public var destinationURL: URL? {
        if case .success(let url) = status { return url }
        return nil
    }
}

// MARK: - View Model

/// Drives `DiscRipperView` and `RipperProgressSheet`.
@MainActor
@Observable
public final class RipperViewModel {

    // MARK: - Drive / Disc State

    public var driveStatus: OpticalDriveStatus = .unknown
    public var toc: DiscTOC?
    public var isLoadingTOC = false
    public var tocError: String?

    // MARK: - Rip State

    public var isRipping = false
    public var ripError: String?
    public var showRipperSheet = false
    public var showCancelRipConfirmation = false

    /// Live progress from the in-flight rip.
    public var currentProgress: RipProgress?
    /// Rolling read speed in MB/s (updated every ~0.5 s).
    public var ripSpeedMBps: Double = 0
    /// Estimated seconds remaining, nil when unknown.
    public var etaSeconds: Double?

    // MARK: - Track Selection

    public var selectedTracks: Set<Int> = []

    public var allTracksSelected: Bool {
        guard let toc else { return false }
        return selectedTracks.count == toc.trackCount
    }

    // MARK: - Recent Rips

    public private(set) var recentRips: [RippedDisc] = []

    // MARK: - Private State

    private let client: OpticalDiscClient
    private var ripTask: Task<Void, Never>?
    private var speedSampleTime: Date?
    private var speedSampleSectors: UInt32 = 0

    // MARK: - Init

    public init(client: OpticalDiscClient) {
        self.client = client
    }

    // MARK: - Drive Connection

    /// Connect to the optical drive dext. Safe to call on appearance.
    public func connect() async {
        await client.connect()
        driveStatus = client.driveStatus
        if case .connected = client.connectionState {
            try? await client.refreshStatus()
            driveStatus = client.driveStatus
            if driveStatus == .discPresent {
                await loadTOC()
            }
        }
    }

    // MARK: - TOC Loading

    public func loadTOC() async {
        isLoadingTOC = true
        tocError = nil
        toc = nil
        do {
            let fetched = try await client.readTOC()
            toc = fetched
            selectedTracks = Set(fetched.tracks.map(\.trackNumber))
        } catch {
            tocError = error.localizedDescription
        }
        isLoadingTOC = false
    }

    // MARK: - Track Selection

    public func toggleTrack(_ number: Int) {
        if selectedTracks.contains(number) {
            selectedTracks.remove(number)
        } else {
            selectedTracks.insert(number)
        }
    }

    public func toggleAllTracks() {
        guard let toc else { return }
        if allTracksSelected {
            selectedTracks.removeAll()
        } else {
            selectedTracks = Set(toc.tracks.map(\.trackNumber))
        }
    }

    // MARK: - Rip

    /// Start ripping the selected tracks. Presents `RipperProgressSheet` automatically.
    public func startRip() {
        guard toc != nil, !isRipping else { return }
        isRipping = true
        ripError = nil
        currentProgress = nil
        ripSpeedMBps = 0
        etaSeconds = nil
        speedSampleTime = nil
        speedSampleSectors = 0
        showRipperSheet = true

        ripTask = Task { [weak self] in
            guard let self else { return }

            // Progress observer runs concurrently with the rip operation.
            // It exits when isRipping becomes false or the task is cancelled.
            let progressObserver = Task { [weak self] in
                await self?.observeProgress()
            }

            do {
                let destDir = FileManager.default.temporaryDirectory
                    .appending(path: "DiscRips", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                let outputURL = try await client.ripDisc(to: destDir, trackSelection: selectedTracks)

                guard !Task.isCancelled else {
                    progressObserver.cancel()
                    return
                }
                // Signal observer to exit, then record success
                isRipping = false
                progressObserver.cancel()
                let disc = RippedDisc(
                    id: UUID(),
                    discType: toc?.discType ?? .unknown,
                    trackCount: selectedTracks.count,
                    date: Date(),
                    status: .success(url: outputURL)
                )
                recentRips.insert(disc, at: 0)
                showRipperSheet = false
                DLOG("RipperViewModel: rip completed → \(outputURL.lastPathComponent)")
            } catch is CancellationError {
                isRipping = false
                progressObserver.cancel()
                recordFailedRip(reason: "Cancelled")
                DLOG("RipperViewModel: rip cancelled")
            } catch {
                isRipping = false
                progressObserver.cancel()
                recordFailedRip(reason: error.localizedDescription)
                ripError = error.localizedDescription
                showRipperSheet = false
                DLOG("RipperViewModel: rip error — \(error)")
            }
        }
    }

    /// Cancel an in-flight rip after confirmation.
    public func cancelRip() {
        ripTask?.cancel()
        ripTask = nil
        isRipping = false
        showRipperSheet = false
        showCancelRipConfirmation = false
        cleanPartialFiles()
    }

    // MARK: - Private Helpers

    /// Poll `client.ripProgress` until the rip task finishes or is cancelled.
    private func observeProgress() async {
        while isRipping && !Task.isCancelled {
            if let progress = client.ripProgress {
                updateSpeed(progress: progress)
                currentProgress = progress
            }
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 s
        }
    }

    /// Rolling speed estimate using a 0.5-second window.
    private func updateSpeed(progress: RipProgress) {
        let now = Date()
        if let lastTime = speedSampleTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed >= 0.5 {
                let sectorsDelta = Int64(progress.currentSector) - Int64(speedSampleSectors)
                let bytesDelta = Double(max(0, sectorsDelta)) * 2352
                ripSpeedMBps = (bytesDelta / elapsed) / 1_048_576

                let sectorsLeft = Int64(progress.totalSectors) - Int64(progress.currentSector)
                if ripSpeedMBps > 0 {
                    let bytesLeft = Double(max(0, sectorsLeft)) * 2352
                    etaSeconds = (bytesLeft / 1_048_576) / ripSpeedMBps
                }
                speedSampleTime = now
                speedSampleSectors = progress.currentSector
            }
        } else {
            speedSampleTime = now
            speedSampleSectors = progress.currentSector
        }
    }

    private func recordFailedRip(reason: String) {
        let disc = RippedDisc(
            id: UUID(),
            discType: toc?.discType ?? .unknown,
            trackCount: selectedTracks.count,
            date: Date(),
            status: .failed(reason: reason)
        )
        recentRips.insert(disc, at: 0)
    }

    private func cleanPartialFiles() {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "DiscRips", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: dir)
        DLOG("RipperViewModel: cleaned partial rip files")
    }
}
