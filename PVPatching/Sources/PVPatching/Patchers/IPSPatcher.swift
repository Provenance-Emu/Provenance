//
//  IPSPatcher.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  IPS (International Patching System) and IPS32 patches.
//  Decoding is done by PVPatchEngine, which streams through files; this type keeps the
//  in-memory API for small ROMs and tests. `PatchApplier` uses the engine directly.
//

import Foundation

/// Applies IPS and IPS32 patches to ROM data.
///
/// IPS: "PATCH", records of offset (3 bytes BE) + length (2 bytes BE) + data, or an RLE record
/// (length 0, then count (2 bytes BE) and the byte), "EOF", optional 3-byte truncation size.
/// IPS32 uses 4-byte offsets and "EEOF".
public struct IPSPatcher: Sendable {
    public init() {}

    /// Determine if a patch file uses IPS32 format based on its file extension.
    ///
    /// An IPS32 patch that starts with "PATCH" can only be told apart by its `.ips32` extension:
    /// the bytes of "EEOF" can legitimately appear inside a record of a classic IPS patch, so the
    /// body must never be scanned for them.
    public static func isIPS32Format(url: URL) -> Bool {
        url.pathExtension.lowercased() == "ips32"
    }

    /// Apply an IPS patch to source data and return the patched result.
    ///
    /// - Parameter isIPS32: `true` for IPS32 patches; determine it with `isIPS32Format(url:)`.
    /// - Throws: `PatchError` on format or integrity issues.
    public func apply(patch: Data, to source: Data, isIPS32: Bool = false) async throws -> Data {
        try await EngineBridge.apply(format: isIPS32 ? .ips32 : .ips, patch: patch, source: source)
    }
}
