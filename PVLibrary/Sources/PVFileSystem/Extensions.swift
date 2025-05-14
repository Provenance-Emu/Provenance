//
//  Extensions.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

public enum Extensions: String, CaseIterable {
    
    case sevenZip = "7z"
    case sevenZipAlt = "7zip"
    case gzip = "gzip"
    case gz = "gz"
    case rar = "rar"
    case zip = "zip"
    
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
    
    // Other
    case mcr = "mcr"
    case plist = "plist"
    case bin = "bin"
    case sub = "sub"
    
    private static let _archiveExtensions: Set<Extensions> = [.sevenZip, .sevenZipAlt, .gzip, .gz, .rar, .zip]
    private static let _artworkExtensions: Set<Extensions> = [.png, .jpg, .jpeg]
    private static let _discImageExtensions: Set<Extensions> = [.ccd, .img, .iso, .chd]
    private static let _playlistExtensions: Set<Extensions> = [.m3u, .cue]
    private static let _specialExtensions: Set<Extensions> = [.svs, .mcr, .plist, .ccd, .sub, .bin]
    private static let _skinExtensions: Set<Extensions> = [.deltaSkin]

    public static let archiveExtensions: Set<String> = Set(_archiveExtensions.map { $0.rawValue })
    public static let artworkExtensions: Set<String> = Set(_artworkExtensions.map { $0.rawValue })
    public static let discImageExtensions: Set<String> = Set(_discImageExtensions.map { $0.rawValue })
    public static let playlistExtensions: Set<String> = Set(_playlistExtensions.map { $0.rawValue })
    public static let specialExtensions: Set<String> = Set(_specialExtensions.map { $0.rawValue })
    public static let skinExtensions: Set<String> = Set(_skinExtensions.map { $0.rawValue })

    public static let allKnownExtensions: Set<String> = archiveExtensions.union(artworkExtensions).union(discImageExtensions).union(playlistExtensions).union(specialExtensions).union(skinExtensions)
}
