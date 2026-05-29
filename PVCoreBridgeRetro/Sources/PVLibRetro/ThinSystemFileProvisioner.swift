//
//  ThinSystemFileProvisioner.swift
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-05-29.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Downloads the auxiliary "system" asset archives a thin-wrapper libretro
//  core needs (see `ThinSystemFileManifest`) from the libretro buildbot.
//
//  The provisioner is fire-and-forget: it is launched non-blocking from the
//  core's startup path so emulation begins immediately. For each manifest
//  asset whose per-core stamp sentinel is absent, it downloads the ZIP to a
//  temp location, extracts it into a temp dir, atomically moves the contents
//  into the system directory, then writes the stamp. Per-asset failures are
//  isolated and logged; the provisioner never throws to its caller.
//

import Foundation
import PVLogging
import PVArchiving
import PVCoreObjCBridge

// MARK: - Downloader abstraction (for testability)

/// Abstracts the network download so unit tests can inject a stub returning a
/// local fixture, a 404, an offline error, or a corrupt archive.
protocol ThinSystemFileDownloading: Sendable {
    /// Download `url` and return a local file URL to the downloaded payload.
    /// Throws on transport / HTTP failure.
    func download(from url: URL) async throws -> URL
}

/// Production downloader backed by `URLSession`. Treats non-2xx HTTP responses
/// as failures so a 404 HTML page is never mistaken for a valid archive.
struct URLSessionThinSystemFileDownloader: ThinSystemFileDownloading {
    func download(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // Clean up the temp payload (often an error page) before failing.
            try? FileManager.default.removeItem(at: tempURL)
            throw ThinSystemFileProvisioner.ProvisionError.httpStatus(http.statusCode)
        }
        return tempURL
    }
}

// MARK: - Provisioner

/// Serialises asset provisioning for thin-wrapper cores. Actor isolation keeps
/// concurrent launches of the same core from racing on the same system dir.
actor ThinSystemFileProvisioner {

    enum ProvisionError: Error, Equatable {
        case httpStatus(Int)
        case emptyArchive
    }

    /// Default duration (seconds) for OSD toasts. 0 = the OSD layer default.
    private static let toastDuration: TimeInterval = 4.0

    private let downloader: any ThinSystemFileDownloading
    private let fileManager: FileManager

    init(downloader: any ThinSystemFileDownloading = URLSessionThinSystemFileDownloader(),
         fileManager: FileManager = .default) {
        self.downloader = downloader
        self.fileManager = fileManager
    }

    /// Provision every missing asset for `coreId` into `systemDirectory`.
    ///
    /// Idempotent: assets whose stamp sentinel is present are skipped. Never
    /// throws — per-asset failures are logged and surfaced as warning toasts so
    /// the core keeps running and the download retries on the next launch.
    func provision(coreId: String, systemDirectory: String) async {
        guard let entry = ThinSystemFileManifest.entry(forCoreID: coreId) else {
            // No registered assets for this core — nothing to do.
            return
        }
        guard !systemDirectory.isEmpty else {
            WLOG("ThinProvision: system directory unavailable for \(coreId) — skipping")
            return
        }

        let systemDirURL = URL(fileURLWithPath: systemDirectory)
        let stampURL = systemDirURL.appendingPathComponent(
            ThinSystemFileManifest.stampFileName(forStampKey: entry.stampKey))

        // Already provisioned — stamp present, skip silently.
        if fileManager.fileExists(atPath: stampURL.path) {
            DLOG("ThinProvision: stamp present for \(entry.stampKey) — skipping")
            return
        }

        guard !entry.assets.isEmpty else {
            WLOG("ThinProvision: manifest entry \(entry.stampKey) has no assets")
            return
        }

        // First missing asset → announce the download (success is silent).
        postToast("Downloading \(entry.assets[0].displayName) system files…",
                  type: PVOSDTypeInfo)

        var allSucceeded = true
        for asset in entry.assets {
            let ok = await provisionAsset(asset, into: systemDirURL)
            if !ok { allSucceeded = false }
        }

        if allSucceeded {
            writeStamp(at: stampURL, stampKey: entry.stampKey)
            ILOG("ThinProvision: provisioned \(entry.stampKey) into \(systemDirectory)")
        } else {
            // Leave the stamp unwritten so the next launch retries.
            postToast("Couldn't fetch \(entry.assets[0].displayName) system files — some features may be missing",
                      type: PVOSDTypeWarning)
        }
    }

    // MARK: - Per-asset provisioning

    /// Download + extract a single asset into `systemDirURL`. Returns `true` on
    /// success. Isolates and logs all failures; never throws.
    private func provisionAsset(_ asset: ThinSystemAsset, into systemDirURL: URL) async -> Bool {
        let name = asset.sourceURL.lastPathComponent
        var downloadedURL: URL?
        let scratchDir = systemDirURL.appendingPathComponent(
            ".pv_provision_tmp_\(UUID().uuidString)", isDirectory: true)

        defer {
            if let downloadedURL { try? fileManager.removeItem(at: downloadedURL) }
            try? fileManager.removeItem(at: scratchDir)
        }

        do {
            // Ensure the system dir exists (also the parent of the scratch dir).
            try fileManager.createDirectory(at: systemDirURL, withIntermediateDirectories: true)

            // 1. Download to a temp payload.
            let tempPayload = try await downloader.download(from: asset.sourceURL)
            downloadedURL = tempPayload

            // 2. Extract into a fresh scratch dir (atomic: never partially
            //    populates the real system dir if extraction throws midway).
            try fileManager.createDirectory(at: scratchDir, withIntermediateDirectories: true)
            let extracted = try await ArchiveManager.shared.extractAll(at: tempPayload, to: scratchDir)
            guard !extracted.isEmpty else {
                ELOG("ThinProvision: archive \(name) extracted no files")
                throw ProvisionError.emptyArchive
            }

            // 3. Move extracted contents into the system dir. Existing files are
            //    left intact (idempotent), new files are moved in.
            try mergeContents(of: scratchDir, into: systemDirURL)
            ILOG("ThinProvision: installed \(name) (\(extracted.count) files)")
            return true
        } catch {
            ELOG("ThinProvision: failed \(name): \(error.localizedDescription)")
            return false
        }
    }

    /// Move every top-level item from `src` into `dst`. Files that already exist
    /// at the destination are skipped (provisioning is non-destructive).
    private func mergeContents(of src: URL, into dst: URL) throws {
        let items = try fileManager.contentsOfDirectory(at: src,
                                                        includingPropertiesForKeys: nil)
        for item in items {
            let target = dst.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                DLOG("ThinProvision: \(item.lastPathComponent) already present — keeping existing")
                continue
            }
            try fileManager.moveItem(at: item, to: target)
        }
    }

    /// Write the per-core provisioning stamp. The contents are a short version
    /// marker so a future format bump can invalidate older stamps if needed.
    private func writeStamp(at url: URL, stampKey: String) {
        let body = "pv_assets v1 \(stampKey)\n"
        do {
            try body.data(using: .utf8)?.write(to: url, options: .atomic)
        } catch {
            WLOG("ThinProvision: could not write stamp \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: - Toast helper

    private func postToast(_ message: String, type: PVOSDType) {
        PVOSDNotification.postMessage(message, type: type, duration: Self.toastDuration)
    }
}
