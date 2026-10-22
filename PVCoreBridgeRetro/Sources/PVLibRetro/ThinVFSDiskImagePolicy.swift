//
//  ThinVFSDiskImagePolicy.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Decides when the thin libretro VFS should memory-map a file.
//
//  RetroArch's reference VFS mmaps every file opened with
//  `RETRO_VFS_FILE_ACCESS_HINT_FREQUENT_ACCESS`. MAME's libretro OSD, however,
//  opens CHD/hard-disk images with `HINT_NONE` (see libretro_vfs.cpp), so a
//  hint-only policy never activates for the games that need it most. Disk-image
//  extensions are therefore treated like FREQUENT_ACCESS for read-only opens.
//

import Foundation

/// Policy for aggressive VFS caching / memory-mapping of large disk images.
enum ThinVFSDiskImagePolicy {

    /// Libretro `RETRO_VFS_FILE_ACCESS_READ`.
    static let accessRead: UInt32 = 1 << 0
    /// Libretro `RETRO_VFS_FILE_ACCESS_WRITE`.
    static let accessWrite: UInt32 = 1 << 1
    /// Libretro `RETRO_VFS_FILE_ACCESS_HINT_FREQUENT_ACCESS`.
    static let hintFrequentAccess: UInt32 = 1 << 0

    /// Extensions whose random hunk / sector I/O benefits from an mmap'd view.
    /// CHD is the primary MAME case; the optical / HDD set covers other thin cores.
    static let diskImageExtensions: Set<String> = [
        "chd",
        "iso",
        "cso",
        "isz",
        "gcm",
        "gcz",
        "rvz",
        "wbfs",
        "wia",
        "nrg",
        "mdf",
        "cdi",
        "toast",
        "img",
        "hdd",
        "hd",
    ]

    /// Returns whether `path` looks like a disk / optical / hard-disk image.
    static func isDiskImagePath(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return diskImageExtensions.contains(ext)
    }

    /// Returns whether the thin VFS should attempt to memory-map this open.
    ///
    /// - Parameters:
    ///   - path: Absolute path passed to `retro_vfs_open`.
    ///   - mode: Libretro `RETRO_VFS_FILE_ACCESS_*` flags.
    ///   - hints: Libretro `RETRO_VFS_FILE_ACCESS_HINT_*` flags.
    ///   - fileSize: Size from `stat`, or `<= 0` when unknown / empty.
    static func shouldMemoryMap(path: String, mode: UInt32, hints: UInt32, fileSize: Int64) -> Bool {
        // Writes need a mutable descriptor path; never map those.
        guard (mode & accessWrite) == 0 else { return false }
        guard (mode & accessRead) != 0 else { return false }
        guard fileSize > 0 else { return false }
        if (hints & hintFrequentAccess) != 0 { return true }
        return isDiskImagePath(path)
    }
}

/// C entry point for `PVThinLibretroFrontend.mm` VFS open.
///
/// Matches the Swift policy so ObjC++ does not re-implement the extension list.
@_cdecl("pv_thin_vfs_should_memory_map")
public func pvThinVFSShouldMemoryMap(
    _ path: UnsafePointer<CChar>?,
    mode: UInt32,
    hints: UInt32,
    fileSize: Int64
) -> Bool {
    guard let path else { return false }
    return ThinVFSDiskImagePolicy.shouldMemoryMap(
        path: String(cString: path),
        mode: mode,
        hints: hints,
        fileSize: fileSize
    )
}
