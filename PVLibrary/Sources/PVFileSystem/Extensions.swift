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
    
    // Other
    case mcr = "mcr"
    case plist = "plist"
    case bin = "bin"
    case sub = "sub"

    public static let _archiveExtensions: [Extensions] = [.sevenZip, .sevenZipAlt, .gzip, .gz, .rar, .zip]
    public static let _artworkExtensions: [Extensions] = [.png, .jpg, .jpeg]
    public static let _discImageExtensions: [Extensions] = [.ccd, .img, .iso, .chd, .img]
    public static let _playlistExtensions: [Extensions] = [.m3u, .cue]
    public static let _specialExtensions: [Extensions] = [.svs, .mcr, .plist, .ccd, .sub, .bin]
    
    public static let archiveExtensions: [String] = _archiveExtensions.map { $0.rawValue }
    public static let artworkExtensions: [String] = _artworkExtensions.map { $0.rawValue }
    public static let discImageExtensions: [String] = _discImageExtensions.map { $0.rawValue }
    public static let playlistExtensions: [String] = _playlistExtensions.map { $0.rawValue }
    public static let specialExtensions: [String] = _specialExtensions.map { $0.rawValue }
    
    public static let allKnownExtensions: [String] = archiveExtensions + artworkExtensions + discImageExtensions + playlistExtensions + specialExtensions
}
