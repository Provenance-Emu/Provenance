//
//  ThinContentArchiveResolver.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Decides what path the thin wrapper hands to `retro_load_game` when the game
//  file is a `.zip` / `.7z`.
//
//  Libretro cores do not open archives themselves. In RetroArch the frontend
//  does it (`task_content.c`): unless the core sets `block_extract` or lists the
//  archive's extension in `valid_extensions`, it extracts the archive and loads
//  the first entry the core accepts. Cores that do read zips natively — MAME,
//  FBNeo, DOSBox Pure — list `zip` and get the archive untouched, which is what
//  keeps arcade romsets working.
//
//  The thin wrapper skipped this step and passed every archive straight
//  through, so a zipped SNES / Genesis / Jaguar game reached snes9x,
//  Genesis Plus GX or virtualjaguar as raw zip bytes and failed to boot.
//

import Foundation
import PVLogging
import PVArchiving

@objc(PVThinContentArchiveResolver)
public final class ThinContentArchiveResolver: NSObject {

    /// Archive formats RetroArch extracts for a core that can't read them.
    static let extractableExtensions: Set<String> = ["zip", "7z"]

    /// Entry types that describe a whole game (and reference the other files in
    /// the archive), so they win over the first matching data file.
    static let preferredEntryExtensions = ["m3u", "cue", "gdi", "ccd"]

    /// Name of the file recording which archive a cache directory was extracted
    /// from, so an unchanged archive isn't extracted again on every boot.
    static let sourceStampFileName = ".pvthin-source"

    /// Parses a libretro `valid_extensions` string (`"smc|sfc|swc"`).
    static func extensions(fromValidExtensions validExtensions: String?) -> Set<String> {
        guard let validExtensions else { return [] }
        return Set(validExtensions.lowercased()
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    /// `true` when the frontend must extract `contentPath` before loading it.
    static func shouldExtract(contentPath: String, validExtensions: Set<String>, blockExtract: Bool) -> Bool {
        let ext = (contentPath as NSString).pathExtension.lowercased()
        guard extractableExtensions.contains(ext), !blockExtract else { return false }
        // An empty list means the core didn't say what it accepts; leave the
        // archive alone rather than guess.
        guard !validExtensions.isEmpty else { return false }
        return !validExtensions.contains(ext)
    }

    /// The extracted file to load: a playlist/cue sheet if there is one, else the
    /// first file (by path) the core accepts. `nil` when nothing matches.
    static func preferredContent(among files: [URL], validExtensions: Set<String>) -> URL? {
        let candidates = files
            .filter { !$0.pathComponents.contains("__MACOSX") && !$0.lastPathComponent.hasPrefix(".") }
            .filter { validExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
        for ext in preferredEntryExtensions {
            if let match = candidates.first(where: { $0.pathExtension.lowercased() == ext }) {
                return match
            }
        }
        return candidates.first
    }

    /// Returns the path to pass to `retro_load_game`: `contentPath` itself, or the
    /// file to load from its extracted copy under `extractionRoot`. Falls back
    /// to `contentPath` when extraction fails or yields nothing the core accepts,
    /// so the core reports the load failure as it did before.
    @objc public static func resolveContentPath(_ contentPath: String,
                                                validExtensions: String?,
                                                blockExtract: Bool,
                                                extractionRoot: String) -> String {
        let accepted = extensions(fromValidExtensions: validExtensions)
        guard shouldExtract(contentPath: contentPath, validExtensions: accepted, blockExtract: blockExtract) else {
            return contentPath
        }

        let fm = FileManager.default
        let source = URL(fileURLWithPath: contentPath)
        let destination = URL(fileURLWithPath: extractionRoot)
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent, isDirectory: true)
        let stampURL = destination.appendingPathComponent(sourceStampFileName)
        let stamp = sourceStamp(for: source)

        if let stamp, (try? String(contentsOf: stampURL, encoding: .utf8)) == stamp,
           let cached = preferredContent(among: files(under: destination), validExtensions: accepted) {
            ILOG("ThinArchive: reusing extracted \(cached.lastPathComponent) from \(source.lastPathComponent)")
            return cached.path
        }

        try? fm.removeItem(at: destination)
        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            ELOG("ThinArchive: cannot create \(destination.path): \(error.localizedDescription)")
            return contentPath
        }
        guard PVArchiveHelper.shared.extractArchive(contentPath, toDestination: destination.path, overwrite: true) else {
            ELOG("ThinArchive: extracting \(source.lastPathComponent) failed; loading the archive as-is")
            return contentPath
        }
        guard let content = preferredContent(among: files(under: destination), validExtensions: accepted) else {
            ELOG("ThinArchive: \(source.lastPathComponent) holds no file the core accepts (\(validExtensions ?? "")); loading the archive as-is")
            return contentPath
        }
        if let stamp {
            try? stamp.write(to: stampURL, atomically: true, encoding: .utf8)
        }
        ILOG("ThinArchive: extracted \(source.lastPathComponent); loading \(content.lastPathComponent)")
        return content.path
    }

    /// Identifies an archive by path, size and modification date.
    private static func sourceStamp(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            return nil
        }
        return "\(url.path)\n\(size)\n\(modified.timeIntervalSince1970)"
    }

    private static func files(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory,
                                                              includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    }
}
