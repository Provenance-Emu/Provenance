//
//  PVmGBACore+PatchableCore.swift
//  PVmGBACore
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import PVPatching

// mGBA includes native IPS/UPS patching via its built-in patch loading routines:
//   src/util/patch-ips.c  — IPS v1 (classic format for ROMs up to 16 MB)
//   src/util/patch-fast.c — fast-IPS / IPS32 (4-byte offsets, "EEOF" terminator)
//   src/util/patch-ups.c  — UPS bidirectional patches with CRC verification
//   src/util/patch.c      — format detection and dispatch
//
// When a patch file is passed alongside the ROM at launch, mGBA will automatically
// detect the format and apply it without modifying the source ROM on disk.

extension PVmGBACore: PatchableCore {
    public static var supportedPatchFormats: [PatchFormat] {
        [.ips, .ips32, .ups]
    }
}
