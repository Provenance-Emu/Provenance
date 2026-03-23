//
//  EmulatorFileProviderItem.swift  (contains ROMContentType)
//  ROM File Provider
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//
//  Provides UTType resolution for ROM file extensions used by FileProviderItem.
//  Note: this file defines `ROMContentType`; the filename predates a refactor and
//  cannot be changed without modifying project.pbxproj.
//

import UniformTypeIdentifiers

/// Maps ROM file extensions to the most appropriate `UTType` for display in Files.app.
///
/// Provenance does not (yet) declare custom UTIs in its Info.plist for individual
/// systems, so most ROM files fall back to `.data`. This helper is kept here as
/// the single place to extend UTType coverage once system-specific UTIs are added.
enum ROMContentType {
    /// Returns the best-effort `UTType` for a given ROM file extension.
    ///
    /// Falls back to `.data` for any extension that lacks a registered system UTType.
    static func contentType(forExtension ext: String) -> UTType {
        switch ext.lowercased() {
        // CD / disc images
        case "iso", "bin":
            return UTType("public.iso-image") ?? .data
        case "cue":
            return UTType("com.goldenhawk.cdrwin-cuesheet") ?? .data
        // Compressed archives
        case "zip":
            return .zip
        case "7z":
            return UTType("org.7-zip.7-zip-archive") ?? .data
        // Playlist / multi-disc descriptor
        case "m3u":
            return UTType("public.m3u-playlist") ?? .data
        // All cartridge ROMs and anything else
        default:
            return .data
        }
    }
}
