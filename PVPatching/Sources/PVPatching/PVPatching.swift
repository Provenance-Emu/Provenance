//
//  PVPatching.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

/// PVPatching — ROM patch file support for Provenance.
///
/// Supports applying patches in common formats (IPS, BPS, UPS, xdelta) to ROM files.
/// Original ROMs are never modified; patched ROMs are cached in the app cache directory.
///
/// ## Quick start
/// ```swift
/// let applier = PatchApplier()
/// let patchedURL = try await applier.apply(patchURL: patchURL, to: romURL)
/// // Launch core with patchedURL
/// ```
public enum PVPatching {
    /// Module version string.
    public static let version = "1.0.0"
}
