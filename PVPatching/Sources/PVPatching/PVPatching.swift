//
//  PVPatching.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

/// PVPatching — ROM patch file support for Provenance.
///
/// Supports applying and creating patches in common formats (IPS, BPS, UPS, PPF).
/// Original ROMs are never modified; patched ROMs are cached with unique filenames
/// so each variant gets isolated battery-save / save-state directories.
///
/// ## Quick start
/// ```swift
/// let applier = PatchApplier()
/// let artifact = try await applier.apply(patchURL: patchURL, to: romURL)
/// // Launch core with artifact.url / artifact.patchedMD5
/// ```
public enum PVPatching {
    /// Module version string.
    public static let version = "1.1.0"
}
