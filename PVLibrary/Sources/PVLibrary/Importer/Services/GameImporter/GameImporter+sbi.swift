//
//  GameImporter+sbi.swift
//  PVLibrary
//
//  SBI file auto-detection for LibCrypt-protected PSX titles.
//
//  Background
//  ----------
//  Some PAL/European PlayStation titles (e.g. Final Fantasy VIII FR/ES, Resident Evil 3 FR)
//  use Sony's LibCrypt copy-protection which encodes extra data in the disc's subchannel Q
//  sector.  Mednafen reads this data from a companion `.sbi` file that must reside **in the
//  same directory** as the matching `.cue` file and share the same base filename.
//
//  e.g.  Final Fantasy VIII (France) (Disc 1).cue
//        Final Fantasy VIII (France) (Disc 1).sbi  ← loaded automatically by Mednafen
//
//  If the `.sbi` is absent the LibCrypt check fails silently and the game freezes after the
//  BIOS boot sequence — exactly the symptom described in issue #923.
//
//  This extension hooks into the existing CUE/m3u import pipeline to automatically discover
//  any `.sbi` files that live alongside the CUE sheets being imported, so they are moved to
//  the correct ROM directory as part of the normal import flow.
//
//  Part of #923 — see also epics #2725 (Unified Game Content & Extra Asset Management)
//  and #1946 (Folder support) for the broader SBI management roadmap.
//

import Foundation

extension GameImporter {

    // MARK: - SBI File Detection

    /// Scans for an `.sbi` file adjacent to `cueURL` that shares the same base filename.
    ///
    /// Mednafen's CDAccess_Image automatically loads `<base>.sbi` when it finds one next to the
    /// `.cue` file it is opening.  This helper mirrors that lookup so the importer can pull the
    /// `.sbi` into `resolvedAssociatedFileURLs` and move it alongside the rest of the disc files.
    ///
    /// - Parameters:
    ///   - cueURL: The URL of the `.cue` sheet whose sibling `.sbi` we are looking for.
    ///   - primaryGameItem: The queue item that will carry the resolved file list.
    internal func detectAdjacentSBIFile(forCUEURL cueURL: URL, primaryGameItem: ImportQueueItem) {
        let directory = cueURL.deletingLastPathComponent()
        let baseName  = cueURL.deletingPathExtension().lastPathComponent
        let sbiURL    = directory.appendingPathComponent(baseName).appendingPathExtension(Extensions.sbi.rawValue)

        guard FileManager.default.fileExists(atPath: sbiURL.path) else { return }
        guard !primaryGameItem.resolvedAssociatedFileURLs.contains(sbiURL) else { return }

        primaryGameItem.resolvedAssociatedFileURLs.append(sbiURL)
        ILOG("SBI: Found adjacent SBI file for \(cueURL.lastPathComponent) → \(sbiURL.lastPathComponent)")
    }

    /// Scans every `.cue` file already resolved for `primaryGameItem` and attaches any
    /// matching `.sbi` files that live next to them on disk.
    ///
    /// Call this after `processCUEFilesForBINs` to round-trip all known CUE sheets.
    internal func detectSBIFilesForResolvedCUEs(primaryGameItem: ImportQueueItem) {
        for resolvedURL in primaryGameItem.resolvedAssociatedFileURLs
            where resolvedURL.pathExtension.lowercased() == Extensions.cue.rawValue {
            detectAdjacentSBIFile(forCUEURL: resolvedURL, primaryGameItem: primaryGameItem)
        }
    }

    /// Handles a standalone `.sbi` item that arrived in the import queue without its CUE partner.
    ///
    /// Strategy:
    /// 1. Look for a CUE item in `importQueue` with the same base filename.
    /// 2. If found, attach the SBI as a resolved associated file on the CUE item and mark
    ///    the SBI item for removal from the top-level queue.
    /// 3. If no CUE is in the queue, check whether the matching CUE already lives on disk
    ///    in the ROM directory; if so, just move the SBI to that directory.
    ///
    /// - Parameters:
    ///   - sbiItem: The queue item whose URL has a `.sbi` extension.
    ///   - importQueue: The full import queue (modified in place).
    ///   - indicesToRemove: Indices in `importQueue` that should be removed after this pass.
    internal func processSBIItem(
        _ sbiItem: ImportQueueItem,
        in importQueue: inout [ImportQueueItem],
        indicesToRemove: inout [Int]
    ) {
        let sbiURL  = sbiItem.url
        let baseName = sbiURL.deletingPathExtension().lastPathComponent

        // 1. Find a matching CUE item in the queue (same base name, case-insensitive)
        for (index, item) in importQueue.enumerated() {
            guard item.id != sbiItem.id else { continue }
            let itemExt  = item.url.pathExtension.lowercased()
            let itemBase = item.url.deletingPathExtension().lastPathComponent

            if itemExt == Extensions.cue.rawValue,
               itemBase.lowercased() == baseName.lowercased() {
                if !item.resolvedAssociatedFileURLs.contains(sbiURL) {
                    item.resolvedAssociatedFileURLs.append(sbiURL)
                    ILOG("SBI: Attached \(sbiURL.lastPathComponent) to CUE item \(item.url.lastPathComponent)")
                }
                // Mark the standalone SBI item for removal — it is now tracked under the CUE item.
                if let sbiIndex = importQueue.firstIndex(where: { $0.id == sbiItem.id }),
                   !indicesToRemove.contains(sbiIndex) {
                    indicesToRemove.append(sbiIndex)
                }
                return
            }
        }

        // 2. No matching CUE in queue — mark SBI as a supplementary file so it is not treated
        //    as a standalone ROM and is still moved to the correct destination directory.
        sbiItem.fileType = .cdRom
        ILOG("SBI: No matching CUE found in queue for \(sbiURL.lastPathComponent); marking as supplementary.")
    }

    // MARK: - Queue Organisation

    /// Iterates the import queue and wires up any orphaned `.sbi` items to their CUE partners.
    ///
    /// Call this from the main queue-organisation pass (after CUE/BIN and M3U passes).
    internal func organizeSBIFiles(in importQueue: inout [ImportQueueItem]) {
        ILOG("SBI: Starting SBI organisation...")
        var indicesToRemove: [Int] = []

        for (index, item) in importQueue.enumerated() {
            guard item.url.pathExtension.lowercased() == Extensions.sbi.rawValue else { continue }
            processSBIItem(item, in: &importQueue, indicesToRemove: &indicesToRemove)
            _ = index // suppress unused-variable warning
        }

        // Remove any SBI items that were successfully attached to a CUE
        for indexToRemove in indicesToRemove.sorted(by: >) {
            if indexToRemove < importQueue.count {
                let removed = importQueue.remove(at: indexToRemove)
                ILOG("SBI: Removed \(removed.url.lastPathComponent) from top-level queue (now tracked under its CUE).")
            }
        }

        ILOG("SBI: Finished SBI organisation.")
    }
}
