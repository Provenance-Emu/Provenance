//
//  BinCueDiscSerialPlugin.swift
//  PVHashing
//
//  Dispatches disc-serial extraction for BIN+CUE disc image pairs.
//

import Foundation
import PVLogging

/// Extracts disc serials from BIN+CUE disc image pairs.
///
/// This plugin handles `.cue` files. Its responsibilities are:
/// 1. Parse the `.cue` sheet to find the first data track (MODE1/MODE2).
/// 2. Resolve the corresponding `.bin` file path.
/// 3. Dispatch extraction to ``SegaDiscSerialPlugin`` or ``ISODiscSerialPlugin``
///    depending on the track's content.
///
/// ## Why a separate plugin?
/// A `.cue` file is the entry point for a multi-track disc image, but the
/// actual data lives in one or more `.bin` files. By handling `.cue`
/// separately, the registry can route an entire disc image pair to the
/// correct extractor without callers needing to know about track resolution.
///
/// ## CUE parsing
/// This plugin implements a minimal inline CUE parser (Foundation only,
/// Linux-compatible) that covers the common cases. It does *not* depend on
/// `CDFileHandler` from PVLibrary to avoid a circular dependency.
public struct BinCueDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["cue"]

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        guard let dataTrackURL = resolveDataTrack(cueURL: url) else {
            VLOG("BinCueDiscSerialPlugin: no data track found in \(url.lastPathComponent)")
            return nil
        }

        VLOG("BinCueDiscSerialPlugin: resolved data track → \(dataTrackURL.lastPathComponent)")

        // Try format-specific extractors in priority order.
        // Extension checks are intentionally omitted here: we already know the
        // file is the data track of a CUE sheet, so we try each extractor
        // regardless of extension (e.g. PSX/PS2 data tracks are .bin files
        // which are not in ISODiscSerialPlugin.supportedExtensions).

        // SegaDiscSerialPlugin first (magic-byte check at byte 0/16 — cheap).
        let segaPlugin = SegaDiscSerialPlugin()
        if let result = await segaPlugin.extractSerial(from: dataTrackURL, systemHint: systemHint) {
            return result
        }

        // ISODiscSerialPlugin handles PSX, PS2, and plain ISO 9660 discs.
        let isoPlugin = ISODiscSerialPlugin()
        if let result = await isoPlugin.extractSerial(from: dataTrackURL, systemHint: systemHint) {
            return result
        }

        return nil
    }

    // MARK: - Minimal CUE sheet parser

    /// Parses the `.cue` file and returns the URL of the first data track's
    /// BIN file, or `nil` if it cannot be resolved.
    private func resolveDataTrack(cueURL: URL) -> URL? {
        // Try UTF-8 then Latin-1 to handle encoding variations.
        guard let content = (try? String(contentsOf: cueURL, encoding: .utf8))
                         ?? (try? String(contentsOf: cueURL, encoding: .isoLatin1)) else {
            WLOG("BinCueDiscSerialPlugin: cannot read \(cueURL.lastPathComponent)")
            return nil
        }

        let cueDir = cueURL.deletingLastPathComponent()
        var currentFile: String?
        var foundDataTrack = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()

            if upper.hasPrefix("FILE ") {
                // Each new FILE directive starts a new track group; reset the
                // data-track flag so that INDEX lines under audio tracks are
                // not mistakenly treated as data tracks.
                foundDataTrack = false
                // Extract filename between double quotes.
                // Handle both straight quotes " and some smart-quote variants.
                let normalised = trimmed
                    .replacingOccurrences(of: "\u{201C}", with: "\"")
                    .replacingOccurrences(of: "\u{201D}", with: "\"")
                if let start = normalised.firstIndex(of: "\""),
                   let end   = normalised.lastIndex(of: "\""),
                   start < end {
                    let nameStart = normalised.index(after: start)
                    currentFile = String(normalised[nameStart..<end])
                }
            } else if upper.hasPrefix("TRACK ") {
                // Data tracks are MODE1/xxxx or MODE2/xxxx.
                if upper.contains("MODE1") || upper.contains("MODE2") {
                    foundDataTrack = true
                }
            } else if upper.hasPrefix("INDEX ") && foundDataTrack, let filename = currentFile {
                // First INDEX of the first data track — this is the file we want.
                return resolveFile(filename, in: cueDir)
            }
        }

        // Fallback: if we found a data-track FILE directive but no INDEX line
        // (malformed CUE), return the last seen data-track FILE if it resolves.
        // Guard ensures we don't return an audio-only file when no data track exists.
        guard foundDataTrack, let filename = currentFile else { return nil }
        return resolveFile(filename, in: cueDir)
    }

    /// Resolves a CUE-relative filename to an absolute URL, with a
    /// case-insensitive filesystem fallback for case-sensitive volumes.
    private func resolveFile(_ filename: String, in directory: URL) -> URL? {
        // Normalise path separators (Windows CUE files use backslashes).
        let normalised = filename.replacingOccurrences(of: "\\", with: "/")
        let candidateURL = directory.appendingPathComponent(normalised)

        if FileManager.default.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }

        // Case-insensitive search in the same directory.
        let leafName = (normalised as NSString).lastPathComponent
        guard let contents = try? FileManager.default
                .contentsOfDirectory(atPath: directory.path) else { return nil }
        let lower = leafName.lowercased()
        if let match = contents.first(where: { $0.lowercased() == lower }) {
            return directory.appendingPathComponent(match)
        }

        WLOG("BinCueDiscSerialPlugin: BIN file not found: \(leafName)")
        return nil
    }
}
