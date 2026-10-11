//
//  PVPatching.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

/// PVPatching — ROM patch file support for Provenance.
///
/// Supports applying and creating patches in common formats (IPS, BPS, UPS, PPF),
/// plus an opt-in online catalog client for RomHacking.net discovery and a
/// `ROMToolOperation` foundation (Patch Applier / batch apply; CHD convert later).
/// Original ROMs are never modified; patched ROMs are stored under `PatchedROMs/`
/// with unique filenames so each variant gets isolated battery-save / save-state
/// directories and resolves through the normal Documents/Caches file roots.
///
/// ## Quick start
/// ```swift
/// let applier = PatchApplier()
/// let artifact = try await applier.apply(patchURL: patchURL, to: romURL)
/// // Launch core with artifact.url / artifact.patchedMD5
///
/// let hits = try await RomHackingNetDatabase.shared.search(query: "zelda")
/// let validation = try PatchCRCValidator.validate(romURL: romURL, inspection: inspection)
/// ```
public enum PVPatching {
    /// Module version string.
    public static let version = "1.3.1"
}
