//
//  Extensions.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import PVPatching

public enum Extensions: String, CaseIterable {
    
    case sevenZip = "7z"
    case sevenZipAlt = "7zip"
    case gzip = "gzip"
    case gz = "gz"
    case rar = "rar"
    case zip = "zip"
    case tar = "tar"
    case bz2 = "bz2"
    case bzip2 = "bzip2"
    case lzh = "lzh"
    case lha = "lha"
    case xz = "xz"
    case zst = "zst"
    case zstd = "zstd"
    case lzma = "lzma"

    // Images
    case png = "png"
    case jpg = "jpg"
    case jpeg = "jpeg"
    
    // Playlists
    case cue = "cue"
    case m3u = "m3u"

    // Saves
    case svs = "svs"

    // Disc Images
    case ccd = "ccd"
    case img = "img"
    case iso = "iso"
    case chd = "chd"

    // Skins
    case deltaSkin = "deltaskin"
    case manicSkin = "manicskin"

    // Other
    case mcr = "mcr"
    case plist = "plist"
    case bin = "bin"
    case sub = "sub"

    // CD Supplementary (LibCrypt / subchannel data)
    /// SBI files carry subchannel Q data needed by LibCrypt-protected PSX titles.
    /// Mednafen auto-loads `<disc>.sbi` when it is placed next to the matching `.cue` file.
    case sbi = "sbi"

    // Patches
    case ips      = "ips"
    case ips32    = "ips32"
    case bps      = "bps"
    case ups      = "ups"
    case xdelta   = "xdelta"
    case delta    = "delta"
    case xdelta3  = "xdelta3"
    case vcdiff   = "vcdiff"
    case ppf      = "ppf"
    case aps      = "aps"
    case rup      = "rup"

    private static let _archiveExtensions: Set<Extensions> = [
        .sevenZip, .sevenZipAlt, .gzip, .gz, .rar, .zip,
        .tar, .bz2, .bzip2, .lzh, .lha, .xz, .zst, .zstd, .lzma
    ]
    private static let _artworkExtensions: Set<Extensions> = [.png, .jpg, .jpeg]
    private static let _discImageExtensions: Set<Extensions> = [.ccd, .img, .iso, .chd]
    private static let _playlistExtensions: Set<Extensions> = [.m3u, .cue]
    private static let _specialExtensions: Set<Extensions> = [.svs, .mcr, .plist, .ccd, .sub, .bin]
    private static let _cdSupplementaryExtensions: Set<Extensions> = [.sbi, .sub]
    private static let _skinExtensions: Set<Extensions> = [.deltaSkin, .manicSkin]

    public static let archiveExtensions: Set<String> = Set(_archiveExtensions.map { $0.rawValue })
    public static let artworkExtensions: Set<String> = Set(_artworkExtensions.map { $0.rawValue })
    public static let discImageExtensions: Set<String> = Set(_discImageExtensions.map { $0.rawValue })
    public static let playlistExtensions: Set<String> = Set(_playlistExtensions.map { $0.rawValue })
    public static let specialExtensions: Set<String> = Set(_specialExtensions.map { $0.rawValue })
    /// Supplementary files that accompany disc images (e.g. `.sbi` subchannel data, `.sub` subchannel tracks).
    public static let cdSupplementaryExtensions: Set<String> = Set(_cdSupplementaryExtensions.map { $0.rawValue })
    public static let skinExtensions: Set<String> = Set(_skinExtensions.map { $0.rawValue })
    /// Patch file extensions — derived from `PatchFormat.allFileExtensions` (single source of truth).
    public static let patchExtensions: Set<String> = PatchFormat.allFileExtensions

    public static let allKnownExtensions: Set<String> = archiveExtensions.union(artworkExtensions).union(discImageExtensions).union(playlistExtensions).union(specialExtensions).union(cdSupplementaryExtensions).union(skinExtensions).union(patchExtensions)
}
