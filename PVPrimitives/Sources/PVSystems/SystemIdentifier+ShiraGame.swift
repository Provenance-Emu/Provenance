import Foundation

public extension SystemIdentifier {
    /// ShiraGame platform ID for this system
    var shiraGameID: String {
        switch self {
        // Nintendo
        case .NES: return "NINTENDO_NES"
        case .SNES: return "NINTENDO_SNES"
        case .N64: return "NINTENDO_N64"
//        case .N64DD: return "NINTENDO_N64DD"
        case .GameCube: return "NINTENDO_GCN"
        case .Wii: return "NINTENDO_WII"
//        case .WiiU: return "NINTENDO_WIIU"
        case .GB: return "NINTENDO_GB"
        case .GBC: return "NINTENDO_GBC"
        case .GBA: return "NINTENDO_GBA"
        case .DS: return "NINTENDO_NDS"
//        case .DSi: return "NINTENDO_DSI"
        case ._3DS: return "NINTENDO_3DS"
        case .VirtualBoy: return "NINTENDO_VB"
        case .FDS: return "NINTENDO_FDS"

        // Sony
        case .PSX: return "SONY_PSX"
        case .PS2: return "SONY_PS2"
        case .PS3: return "SONY_PS3"
//        case .PS4: return "SONY_PS4"
        case .PSP: return "SONY_PSP"
//        case .Vita return "SONY_PSV"
        // Sega
        case .Genesis: return "SEGA_GEN"
        case .MasterSystem: return "SEGA_SMS"
        case .GameGear: return "SEGA_GG"
        case .SegaCD: return "SEGA_CD"
        case .Saturn: return "SEGA_SAT"
        case .Dreamcast: return "SEGA_DC"
        case .Sega32X: return "SEGA_32X"
        case .SG1000: return "SEGA_SG1000"

        // Atari
        case .Atari2600: return "ATARI_2600"
        case .Atari5200: return "ATARI_5200"
        case .Atari7800: return "ATARI_7800"
        case .AtariJaguar: return "ATARI_JAGUAR"
        case .AtariJaguarCD: return "ATARI_JAGUAR_CD"
        case .Lynx: return "ATARI_LYNX"

        // NEC
        case .PCE: return "NEC_TG16"
        case .PCECD: return "NEC_TGCD"
        case .PCFX: return "NEC_PCFX"
        case .SGFX: return "NEC_SGFX"

        // SNK
        case .NGP: return "SNK_NGP"
        case .NGPC: return "SNK_NGPC"

        // Microsoft
//        case .Xbox: return "MICROSOFT_XBOX"
//        case .Xbox360: return "MICROSOFT_X360"
//        case .XboxOne: return "MICROSOFT_XBO"

        // Others
        case .WonderSwan: return "BANDAI_WS"
        case .WonderSwanColor: return "BANDAI_WSC"
        case .ColecoVision: return "COLECO_CV"
        case .Intellivision: return "MATTEL_INT"
        case .Vectrex: return "GCE_VECTREX"
        case .Odyssey2: return "MAGNAVOX_O2"
        case ._3DO: return "PANASONIC_3DO"
        case .CDi: return "PHILIPS_CDI"
        case .Supervision: return "WATARA_SV"
        
        default: return ""
        
        }
    }

    /// Create a SystemIdentifier from a ShiraGame platform ID
    static func fromShiraGameID(_ platformId: String) -> SystemIdentifier? {
        switch platformId.uppercased() {
        // Nintendo
        case "NINTENDO_NES": return .NES
        case "NINTENDO_SNES": return .SNES
        case "NINTENDO_N64": return .N64
        case "NINTENDO_N64DD": return .N64 //return .N64DD
        case "NINTENDO_GCN": return .GameCube
        case "NINTENDO_WII": return .Wii
//        case "NINTENDO_WIIU": return .WiiU
        case "NINTENDO_GB": return .GB
        case "NINTENDO_GBC": return .GBC
        case "NINTENDO_GBA": return .GBA
        case "NINTENDO_NDS": return .DS
        case "NINTENDO_DSI": return .DS //.DSi
        case "NINTENDO_3DS": return ._3DS
        case "NINTENDO_VB": return .VirtualBoy
        case "NINTENDO_FDS": return .FDS
        
        // Philips
        case "PHILIPS_CDI":  return .CDi

        // Sony
        case "SONY_PSX": return .PSX
        case "SONY_PS2": return .PS2
        case "SONY_PS3": return .PS3
//        case "SONY_PS4": return .PS4
        case "SONY_PSP": return .PSP

        // Sega
        case "SEGA_GEN": return .Genesis
        case "SEGA_SMS": return .MasterSystem
        case "SEGA_GG": return .GameGear
        case "SEGA_CD": return .SegaCD
        case "SEGA_SAT": return .Saturn
        case "SEGA_DC": return .Dreamcast
        case "SEGA_32X": return .Sega32X
        case "SEGA_SG1000": return .SG1000

        // Atari
        case "ATARI_2600": return .Atari2600
        case "ATARI_5200": return .Atari5200
        case "ATARI_7800": return .Atari7800
        case "ATARI_JAGUAR": return .AtariJaguar
        case "ATARI_JAGUAR_CD": return .AtariJaguarCD
        case "ATARI_LYNX": return .Lynx

        // NEC
        case "NEC_TG16": return .PCE
        case "NEC_TGCD": return .PCECD
        case "NEC_PCFX": return .PCFX
        case "NEC_SGFX": return .SGFX

        // SNK
        case "SNK_NGP": return .NGP
        case "SNK_NGPC": return .NGPC

        // Microsoft
//        case "MICROSOFT_XBOX": return .Xbox
//        case "MICROSOFT_X360": return .Xbox360
//        case "MICROSOFT_XBO": return .XboxOne

        // Others
        case "BANDAI_WS": return .WonderSwan
        case "BANDAI_WSC": return .WonderSwanColor
        case "COLECO_CV": return .ColecoVision
        case "MATTEL_INT": return .Intellivision
        case "GCE_VECTREX": return .Vectrex
        case "MAGNAVOX_O2": return .Odyssey2
        case "PANASONIC_3DO": return ._3DO
        case "WATARA_SV": return .Supervision

        default: return nil
        }
    }
}
