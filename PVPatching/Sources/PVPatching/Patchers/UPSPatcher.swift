//
//  UPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  UPS (Universal Patch System) patches, with CRC32 verification in both directions.
//  Decoding is done by PVPatchEngine, which streams through files; this type keeps the
//  in-memory API for small ROMs and tests. `PatchApplier` uses the engine directly.
//

import Foundation

/// Applies UPS patches to ROM data with CRC32 verification.
///
/// The direction is picked from the source: the input image patches forward, the output image
/// patches back.
public struct UPSPatcher: Sendable {
    public init() {}

    /// Apply a UPS patch to source data and return the patched result.
    ///
    /// - Throws: `PatchError.sourceROMMismatch` for the wrong source,
    ///   `.patchedROMVerificationFailed` when the result fails its CRC32, `.corruptPatchFile`
    ///   for a damaged patch (including a patch CRC32 mismatch).
    public func apply(patch: Data, to source: Data) async throws -> Data {
        try await EngineBridge.apply(format: .ups, patch: patch, source: source)
    }
}
