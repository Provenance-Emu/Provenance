//
//  ROMStatusWatcher.swift
//  PVLibrary
//
//  Lightweight kqueue-based watcher on the ROMs directory tree.
//  When filesystem changes are detected, it debounces and triggers
//  GameFileStatusService.refreshAllStatuses() to reconcile
//  isDownloaded with actual file presence.
//
//  Unlike the full DirectoryWatcher (which handles imports, archive
//  extraction, file stability, etc.), this watcher ONLY updates
//  download status metadata — it doesn't move or process files.
//
//  Created by Joseph Mattiello on 4/16/26.
//

import Foundation
import PVLogging
import PVFileSystem

/// Watches ROMs, BIOS, and Save States directories for filesystem changes
/// and triggers `GameFileStatusService.refreshAllStatuses()` with debouncing.
public final class ROMStatusWatcher: @unchecked Sendable {

    public static let shared = ROMStatusWatcher()

    /// Minimum interval between refresh calls (seconds).
    /// Filesystem events can fire rapidly during bulk operations;
    /// debouncing prevents hammering Realm with redundant scans.
    private let debounceInterval: TimeInterval = 2.0

    private let serialQueue = DispatchQueue(label: "org.provenance-emu.romStatusWatcher", qos: .utility)
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWorkItem: DispatchWorkItem?
    private var isMonitoring = false

    private init() {}

    // MARK: - Public API

    /// Start watching the ROMs, BIOS, and Save States directories.
    /// Safe to call multiple times — subsequent calls are no-ops.
    public func startMonitoring() {
        serialQueue.async { [weak self] in
            self?._startMonitoring()
        }
    }

    /// Stop all watchers and cancel pending refreshes.
    public func stopMonitoring() {
        serialQueue.async { [weak self] in
            self?._stopMonitoring()
        }
    }

    /// Force an immediate status refresh (bypasses debounce).
    public func refreshNow() {
        Task {
            let result = await GameFileStatusService.shared.refreshAllStatuses()
            if result.upgraded > 0 || result.downgraded > 0 {
                DLOG("ROMStatusWatcher: forced refresh — \(result.upgraded) upgraded, \(result.downgraded) downgraded")
            }
        }
    }

    // MARK: - Internal

    private func _startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // kqueue only watches direct children, not subdirectories.
        // We need to watch the root directories AND their immediate
        // subdirectories (e.g., ROMs/<system>/, Save States/<rom>/).
        let rootDirectories = [
            Paths.romsPath,
            Paths.biosesPath,
            Paths.saveSavesPath
        ]

        var allDirectories = rootDirectories
        let fm = FileManager.default

        // Add immediate subdirectories of each root
        for root in rootDirectories {
            try? fm.createDirectory(at: root, withIntermediateDirectories: true)
            if let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for item in contents {
                    let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        allDirectories.append(item)
                    }
                }
            }
        }

        for dir in allDirectories {
            watchDirectory(dir)
        }

        DLOG("ROMStatusWatcher: monitoring \(sources.count) directories")
    }

    private func watchDirectory(_ dir: URL) {
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            WLOG("ROMStatusWatcher: failed to open \(dir.path) (errno=\(errno))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .link],
            queue: serialQueue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleRefresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        sources.append(source)
    }

    private func _stopMonitoring() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        isMonitoring = false
        DLOG("ROMStatusWatcher: stopped")
    }

    private func scheduleRefresh() {
        // Cancel any pending refresh and schedule a new one
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            Task {
                let result = await GameFileStatusService.shared.refreshAllStatuses()
                if result.upgraded > 0 || result.downgraded > 0 {
                    DLOG("ROMStatusWatcher: \(result.upgraded) upgraded, \(result.downgraded) downgraded out of \(result.totalGames)")
                }
            }
        }

        debounceWorkItem = workItem
        serialQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
