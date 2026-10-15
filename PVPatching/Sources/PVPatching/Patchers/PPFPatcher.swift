//
//  PPFPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  PPF (PlayStation Patch Format) patches, versions 1.0, 2.0 and 3.0.
//  Decoding is done by PVPatchEngine, which streams through files; this type keeps the
//  in-memory API for small ROMs and tests. `PatchApplier` uses the engine directly.
//

import Foundation

/// Applies PPF (PlayStation Patch Format) patches to disc image data.
///
/// v2 checks the image size and block; v3 checks the block when the patch carries one. A PPF
/// patch never grows the image.
public struct PPFPatcher: Sendable {
    public init() {}

    /// Apply a PPF patch to source data and return the patched result.
    ///
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data) async throws -> Data {
        try await EngineBridge.apply(format: .ppf, patch: patch, source: source)
    }
}
