//
//  CoreEnumerator.swift
//  PVCoreLoader
//
//  Created by Joseph Mattiello on 8/1/24.
//

import Foundation
import PVEmulatorCore

#if canImport(PVAtari800)
@_exported public import PVAtari800
@_exported public import PVAtari800Swift
#endif
#if canImport(PVPicoDrive)
@_exported public import PVPicoDrive
@_exported public import PVPicoDriveSwift
#endif
#if canImport(PVPokeMini)
@_exported public import PVPokeMini
@_exported public import PokeMiniSwift
#endif
#if canImport(PVStella)
@_exported public import PVStella
@_exported public import PVStellaSwift
#endif
#if canImport(PVTGBDual)
@_exported public import PVTGBDual
@_exported public  import PVTGBDualSwift
#endif
#if canImport(PVVirtualJaguar)
@_exported public import PVVirtualJaguar
@_exported public import PVVirtualJaguarSwift
#endif
#if canImport(PVVisualBoyAdvance)
@_exported public import PVVisualBoyAdvance
@_exported public import PVVisualBoyAdvanceSwift
#endif

public enum CoreEnumerator: String, CaseIterable, Codable, Hashable {
#if canImport(PVAtari800)
    case Atari800
#endif
#if canImport(PVPicoDrive)
    case PicoDrive
#endif
#if canImport(PVPokeMini)
    case PokeMini
#endif
#if canImport(PVStella)
    case Stella
#endif
#if canImport(PVTGBDual)
    case TGBDual
#endif
#if canImport(PVVirtualJaguar)
    case VirtualJaguar
#endif
#if canImport(PVVisualBoyAdvance)
    case PVVisualBoyAdvance
#endif

    var core: PVEmulatorCore {
        switch self {
#if canImport(PVAtari800)
        case .Atari800: return ATR800GameCore()
#endif
#if canImport(PVPicoDrive)
        case .PicoDrive: return PicodriveGameCore()
#endif
#if canImport(PVPokeMini)
        case .PokeMini: return PVPokeMiniEmulatorCore()
#endif
#if canImport(PVStella)
        case .Stella: return PVStellaGameCore()
#endif
#if canImport(PVTGBDual)
        case .TGBDual: return PVTGBDualCore()
#endif
#if canImport(PVVirtualJaguar)
        case .VirtualJaguar: return PVJaguarGameCore()
            #endif
#if canImport(PVVisualBoyAdvance)
        case .PVVisualBoyAdvance: return PVVisualBoyAdvanceCore()
#endif
        }
    }
}
