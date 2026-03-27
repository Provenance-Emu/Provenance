//
//  M3UDiscSerialPlugin.swift
//  PVHashing
//
//  Disc-serial extraction for M3U multi-disc playlists.
//

import Foundation
import PVLogging

/// Extracts disc serials from M3U multi-disc playlists (`.m3u`).
///
/// ## Format
/// An M3U file is a plain-text playlist where each non-comment, non-empty line
/// names a disc image file (relative or absolute path).  The first such line
/// identifies the lead disc of the set.
///
/// ## Strategy
/// This plugin:
/// 1. Reads the `.m3u` and finds the first non-comment, non-empty file line.
/// 2. Resolves the path relative to the `.m3u` file's directory.
/// 3. Delegates to ``DiscSerialExtractorRegistry/shared`` to extract the serial
///    from the resolved disc image.
///
/// The registry must have had ``DiscSerialExtractorRegistry/registerDefaults()``
/// called before this plugin can delegate successfully.
///
/// - Note: M3U files that point to other M3U files are not supported and will
///   return `nil` to avoid infinite recursion.
public struct M3UDiscSerialPlugin: DiscSerialExtractorPlugin {

    public let supportedExtensions: Set<String> = ["m3u"]

    public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? {
        guard let firstDiscURL = resolveFirstDisc(m3uURL: url) else {
            VLOG("M3UDiscSerialPlugin: no valid disc entry in \(url.lastPathComponent)")
            return nil
        }

        let ext = firstDiscURL.pathExtension.lowercased()
        // Guard against chained M3U playlists to avoid infinite recursion.
        guard ext != "m3u" else {
            WLOG("M3UDiscSerialPlugin: nested M3U not supported (\(firstDiscURL.lastPathComponent))")
            return nil
        }

        VLOG("M3UDiscSerialPlugin: delegating to registry for \(firstDiscURL.lastPathComponent)")
        return await DiscSerialExtractorRegistry.shared.extractSerial(
            from: firstDiscURL, systemHint: systemHint)
    }

    // MARK: - M3U parsing

    /// Parses the `.m3u` file and returns the URL of the first listed disc image.
    private func resolveFirstDisc(m3uURL: URL) -> URL? {
        guard let content = (try? String(contentsOf: m3uURL, encoding: .utf8))
                         ?? (try? String(contentsOf: m3uURL, encoding: .isoLatin1)) else {
            WLOG("M3UDiscSerialPlugin: cannot read \(m3uURL.lastPathComponent)")
            return nil
        }

        let directory = m3uURL.deletingLastPathComponent()

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip blank lines and comments.
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Normalise Windows-style path separators.
            let normalised = trimmed.replacingOccurrences(of: "\\", with: "/")
            if let resolved = resolveFile(normalised, in: directory) {
                return resolved
            }
        }
        return nil
    }

    /// Resolves a playlist-relative path to an absolute URL with a
    /// case-insensitive fallback for case-sensitive volumes.
    private func resolveFile(_ relativePath: String, in directory: URL) -> URL? {
        // Handle absolute paths (unusual but possible).
        if relativePath.hasPrefix("/") {
            let absURL = URL(fileURLWithPath: relativePath)
            return FileManager.default.fileExists(atPath: absURL.path) ? absURL : nil
        }

        let candidateURL = directory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }

        // Case-insensitive fallback: look for the leaf name in the same directory.
        let leafName = (relativePath as NSString).lastPathComponent
        let subdir: URL
        let parent = (relativePath as NSString).deletingLastPathComponent
        if parent.isEmpty || parent == "." {
            subdir = directory
        } else {
            subdir = directory.appendingPathComponent(
                parent.replacingOccurrences(of: "\\", with: "/"))
        }

        guard let contents = try? FileManager.default
                .contentsOfDirectory(atPath: subdir.path) else { return nil }
        let lower = leafName.lowercased()
        if let match = contents.first(where: { $0.lowercased() == lower }) {
            return subdir.appendingPathComponent(match)
        }

        VLOG("M3UDiscSerialPlugin: disc file not found: \(relativePath)")
        return nil
    }
}
