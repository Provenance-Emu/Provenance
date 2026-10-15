//
//  BPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  BPS (Beat Patch System) patches, with source, target and patch CRC32.
//  Decoding is done by PVPatchEngine, which streams through files; this type keeps the
//  in-memory API for small ROMs and tests. `PatchApplier` uses the engine directly.
//

import Foundation

/// Applies BPS patches to ROM data with full CRC32 verification.
///
/// A source longer than the declared size is accepted when its first `sourceSize` bytes match.
public struct BPSPatcher: Sendable {
    public init() {}

    /// Apply a BPS patch to source data and return the patched result.
    ///
    /// - Throws: `PatchError.sourceROMMismatch` for the wrong source,
    ///   `.patchedROMVerificationFailed` when the result fails its CRC32, `.corruptPatchFile`
    ///   for a damaged patch (including a patch CRC32 mismatch).
    public func apply(patch: Data, to source: Data) async throws -> Data {
        try await EngineBridge.apply(format: .bps, patch: patch, source: source)
    }
}
