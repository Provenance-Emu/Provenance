//
//  PVGameBoxArtAspectRatio.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(CoreGraphics)
import CoreGraphics
#else
public typealias CGFloat = Double
#endif

public enum PVGameBoxArtAspectRatio: CGFloat {
    case square = 1.0
    case wide = 1.45
    case tall = 0.72
    case fiveBySix = 0.8333333333
    case tg16 = 0.8497494768
    case pce = 1.00176208
    case sgx = 1.12
    case gbJAPAN = 0.8566003203
    case gbUSA = 1.0028730846
    case snesUSA = 1.3889901527
    case snesJAPAN = 0.5595619918
    case genmd = 0.719651472
    case smsUSA = 0.716864397
    case nesUSA = 0.7251925801
    case saturnUSA = 0.625
    case saturnJAPAN = 1.136
    case ggUSA = 0.7201
    case ggJAPAN = 0.86
    case Sega32XUSA = 0.7194636596

    // CD jewel case front (Dreamcast, Neo Geo CD, CDi) — same as saturnJAPAN
    public static var cdJewelCase: PVGameBoxArtAspectRatio { .saturnJAPAN }
    // DVD/Blu-ray keepcases
    case dvdCase = 0.7053
    case blurayCase = 0.7836
    // UMD case (PSP)
    case umdCase = 0.6176
    // N64 wide landscape box
    case n64USA = 1.4113
    // Tall specialty boxes
    case longBox3DO = 0.5625
    case vectrex = 0.6053
    case supervision = 0.6818
    // Cassette inlay (ZX Spectrum, EP128)
    case cassetteBox = 0.6667
    // Cartridge boxes
    case atari8bit = 0.6571
    case intellivision = 0.7436
    // Computer software floppy boxes
    case floppyBox = 0.7865
    case atariST = 0.7755
    case pc98 = 0.7054
    // Famicom Disk System sleeve
    case fds = 0.8636

    public static var jaguar: PVGameBoxArtAspectRatio { .tall }
}
