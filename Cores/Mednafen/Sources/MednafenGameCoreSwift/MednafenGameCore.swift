//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
import Foundation

import PVCoreBridge

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
public import PVEmulatorCore

import Foundation

class OERingBuffer {}

@objc
public enum MednaSystem: Int {
    case gb, gba, gg, lynx, md, nes, neoGeo, pce, pcfx, ss, sms, snes, psx, virtualBoy, wonderSwan
}

// Input maps
@objc public class InputMaps: NSObject {
    @objc public static let PCEMap: [Int32] = [4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12]
    @objc public static let PCFXMap: [Int32] = [8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6, 12]
    @objc public static let SNESMap: [Int32] = [4, 5, 6, 7, 8, 0, 9, 1, 10, 11, 3, 2]
    @objc public static let GBMap: [Int32] = [6, 7, 5, 4, 0, 1, 3, 2]
    @objc public static let GBAMap: [Int32] = [6, 7, 5, 4, 0, 1, 9, 8, 3, 2]
    @objc public static let NESMap: [Int32] = [4, 5, 6, 7, 0, 1, 3, 2]
    @objc public static let LynxMap: [Int32] = [6, 7, 4, 5, 0, 1, 3, 2]
    @objc public static let PSXMap: [Int32] = [4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17]
    @objc public static let VBMap: [Int32] = [9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11]
    @objc public static let WSMap: [Int32] = [0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11]
    @objc public static let NeoMap: [Int32] = [0, 1, 2, 3, 4, 5, 6]
    @objc public static let SSMap: [Int32] = [4, 5, 6, 7, 10, 8, 9, 2, 1, 0, 15, 3, 11]
    @objc public static let GenesisMap: [Int32] = [5, 7, 11, 10, 0, 1, 2, 3, 4, 6, 8, 9]
}
                                           
@objc
@objcMembers
open class MednafenGameCore: PVEmulatorCore, @unchecked Sendable {
    @objc var isStartPressed: Bool = false
    @objc var isSelectPressed: Bool = false
    @objc var isAnalogModePressed: Bool = false
    @objc var isL3Pressed: Bool = false
    @objc var isR3Pressed: Bool = false
    
    @objc var inputBuffer: [[UInt32]] = Array(repeating: [], count: 13)
    @objc var axis: [Int16] = Array(repeating: 0, count: 8)
    @objc var videoWidth: Int = 0
    @objc var videoHeight: Int = 0
    @objc var videoOffsetX: Int = 0
    @objc var videoOffsetY: Int = 0
    @objc var multiTapPlayerCount: Int = 0
//    private var romName: String = ""
//    private var sampleRate: Double = 0
    @objc var masterClock: Double = 0
    
    @objc var _isSBIRequired: Bool = false
    
    @objc var mednafenCoreModule: String = ""
    @objc var mednafenCoreTiming: TimeInterval = 0
    
    @objc var systemType: MednaSystem = .gb
    @objc var maxDiscs: UInt = 0
    
    @objc var video_opengl: Bool = false
    
    @objc func setMedia(_ open: Bool, forDisc disc: UInt) {}
    @objc func changeDisplayMode() {}
    @objc func getGame() -> UnsafeRawPointer? { return nil }
}

@objc public extension MednafenGameCore {
    // MARK: - Controls
    
    @objc func didPushLynxButton(_ button: PVLynxButton, forPlayer player: Int) {}
    @objc func didReleaseLynxButton(_ button: PVLynxButton, forPlayer player: Int) {}
    @objc func lynxControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    
    // MARK: SNES
    @objc func didPushSNESButton(_ button: PVSNESButton, forPlayer player: Int) {}
    @objc func didReleaseSNESButton(_ button: PVSNESButton, forPlayer player: Int) {}
    
    // MARK: NES
    @objc func didPushNESButton(_ button: PVNESButton, forPlayer player: Int) {}
    @objc func didReleaseNESButton(_ button: PVNESButton, forPlayer player: Int) {}
    
    // MARK: GB / GBC
    @objc func didPushGBButton(_ button: PVGBButton, forPlayer player: Int) {}
    @objc func didReleaseGBButton(_ button: PVGBButton, forPlayer player: Int) {}
    
    // MARK: GBA
    @objc func didPushGBAButton(_ button: PVGBAButton, forPlayer player: Int) {}
    @objc func didReleaseGBAButton(_ button: PVGBAButton, forPlayer player: Int) {}
    
    // MARK: Sega
    @objc func didPushSegaButton(_ button: PVGenesisButton, forPlayer player: Int) {}
    @objc func didReleaseSegaButton(_ button: PVGenesisButton, forPlayer player: Int) {}
    
    // MARK: Neo Geo
    @objc func didPushNGPButton(_ button: PVNGPButton, forPlayer player: Int) {}
    @objc func didReleaseNGPButton(_ button: PVNGPButton, forPlayer player: Int) {}
    
    // MARK: PC-*
    // MARK: PCE aka TurboGFX-16 & SuperGFX
    @objc func didPushPCEButton(_ button: PVPCEButton, forPlayer player: Int) {}
    @objc func didReleasePCEButton(_ button: PVPCEButton, forPlayer player: Int) {}
    
    // MARK: PCE-CD
    func didPushPCECDButton(_ button: PVPCECDButton, forPlayer player: Int) {}
    func didReleasePCECDButton(_ button: PVPCECDButton, forPlayer player: Int) {}
    
    // MARK: PCFX
    @objc func didPushPCFXButton(_ button: PVPCFXButton, forPlayer player: Int) {}
    @objc func didReleasePCFXButton(_ button: PVPCFXButton, forPlayer player: Int) {}
    
    // MARK: SS Sega Saturn
    @objc func didPushSSButton(_ button: PVSaturnButton, forPlayer player: Int) {}
    @objc func didReleaseSSButton(_ button: PVSaturnButton, forPlayer player: Int) {}
    
    // MARK: PSX
    @objc func didPushPSXButton(_ button: PVPSXButton, forPlayer player: Int) {}
    @objc func didReleasePSXButton(_ button: PVPSXButton, forPlayer player: Int) {}
    @objc func didMovePSXJoystickDirection(_ button: PVPSXButton, withValue value: CGFloat, forPlayer player: Int) {}
    
    // MARK: Virtual Boy
    func didPushVBButton(_ button: PVVBButton, forPlayer player: Int) {}
    @objc func didReleaseVBButton(_ button: PVVBButton, forPlayer player: Int) {}
    
    // MARK: WonderSwan
    @objc func didPushWSButton(_ button: PVWSButton, forPlayer player: Int) {}
    @objc func didReleaseWSButton(_ button: PVWSButton, forPlayer player: Int) {}
    
    @objc func controllerValue(forButtonID buttonID: UInt, forPlayer player: Int, withAnalogMode analogMode: Bool) -> Int { return 0 }
    
    // MARK: Button Values
    @objc func ssValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func gbValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func gbaValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func snesValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func nesValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func neoGeoValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func pceValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func psxAnalogControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Float { return 0 }
    @objc func psxControllerValue(forButtonID buttonID: UInt, forController controller: GCController, withAnalogMode analogMode: Bool) -> Int { return 0 }
    @objc func virtualBoyControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
    @objc func wonderSwanControllerValue(forButtonID buttonID: UInt, forController controller: GCController) -> Int { return 0 }
}

let DEADZONE: Float = 0.1
func OUTSIDE_DEADZONE(_ gamepad: GCController, _ x: KeyPath<GCControllerDirectionPad, GCControllerButtonInput>) -> Bool {
    gamepad.extendedGamepad?.leftThumbstick[keyPath: x].value ?? 0.0 > DEADZONE
}
func DPAD_PRESSED(_ gamepad: GCController, _ x: KeyPath<GCControllerDirectionPad, GCControllerButtonInput>) -> Bool {
    guard let extendedGamepad = gamepad.extendedGamepad else { return false }
    return extendedGamepad.dpad[keyPath: x].isPressed || OUTSIDE_DEADZONE(gamepad, x)
}


extension MednafenGameCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        switch systemType {
        case .psx:
            return numberOfDiscs > 1
        default:
            return false
        }
    }

    public func swapDisc(number: UInt) {
        setPauseEmulation(false)

        let index = number - 1
        setMedia(true, forDisc: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setMedia(false, forDisc: index)
        }
    }
}

extension MednafenGameCore: CoreActions {
    public var coreActions: [CoreAction]? {
        switch systemType {
        case .virtualBoy:
            return [CoreAction(title: "Change Palette", options: nil)]
        default:
            return nil
        }
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case "Change Palette":
            changeDisplayMode()
        default:
            print("Unknown action: " + action.title)
        }
    }
}

extension MednafenGameCore: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try self.setCheat(code, setType: type, setCodeType:codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }

    public var cheatCodeTypes: [String] {
        return self.getCheatCodeTypes()
    }

    public var supportsCheatCode: Bool
    {
        return self.getCheatSupport();
    }
}

extension MednafenGameCore: CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let globalGroup:CoreOption = .group(.init(title: "Core",
                                                description: "Global options for all Mednafen cores."),
                                          subOptions: [cd_image_memcache])
        options.append(globalGroup)
        
            // These seem to be broken, mednafen console says not found
//        let videoGroup:CoreOption = .group(.init(title: "Video",
//                                                description: "Video options for all Mednafen cores."),
//                                          subOptions: [video_blit_timesync, video_fs, video_openglOption])
//
//
//        options.append(videoGroup)
        
        
		let fastGroup:CoreOption = .group(.init(title: "Fast Cores",
												description: "Alternative versions of cores that trade accuracy for speed"),
										  subOptions: [pceFastOption, snesFastOption])
        
        options.append(fastGroup)
        
        let snesFaustGroup:CoreOption = .group(.init(title: "SNES Faust",
                                                     description: ""),
                                          subOptions: [snesFastSpexOption])
        
        options.append(snesFaustGroup)
        
        let psxGroup:CoreOption = .group(.init(title: "PlayStation",
                                                     description: ""),
                                          subOptions: [psx_h_overscan])
        
        options.append(psxGroup)
        
        let ssGroup:CoreOption = .group(.init(title: "Sega Saturn",
                                                     description: ""),
                                          subOptions: [ss_region_default, ss_cart_autodefault, ss_h_overscan])
        /*
         ss.input.port1,2,3,4 gamepad default
         none
         gamepad
         3dpad // https://segaretro.org/3D_Control_Pad
         mouse
         wheel
         mission
         dmission
         gun
         keyboard
         jpkeyboard
         
         ---
         ss.input.port1.3dpad.mode.defpos    enum    digital
         analog    digital    Default position for switch "Mode".
         Sets the position for the switch to the value specified upon startup and virtual input device change.

         digital - Digital(+)

         analog - Analog(○)
         Analog mode is not compatible with all games. For some compatible games, analog mode reportedly must be enabled before the game boots up for the game to recognize it properly.
         
         ---
         ss.region_default    enum    jp
         na
         eu
         kr
         tw
         as
         br
         la    jp    Default region to use.
         Used if region autodetection fails or is disabled.

         jp - Japan

         na - North America

         eu - Europe

         kr - South Korea

         tw - Taiwan

         as - China

         br - Brazil

         la - Latin America
         
         --
         ss.scsp.resamp_quality    integer    0 through 10    4    SCSP output resampler quality.
         0 is lowest quality and CPU usage, 10 is highest quality and CPU usage. The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using. Changing Mednafen's output rate, via the "sound.rate" setting, to "44100" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors.
         
         --
          
         ss.slend    integer    0 through 239    239    Last displayed scanline in NTSC mode.
          
         --
         
         ss.slendp    integer    -16 through 271    255    Last displayed scanline in PAL mode.
         
         --
         
         ss.smpc.autortc.lang    enum    english
         german
         french
         spanish
         italian
         japanese    english    BIOS language.
         Also affects language used in some games(e.g. the European release of "Panzer Dragoon").

         english - English

         german - Deutsch

         french - Français

         spanish - Español

         italian - Italiano

         japanese - 日本語
         */

        options.append(ssGroup)
        
        var vbOptions = [vb_instant_display_hack, vb_sidebyside]
        vbOptions.append(.range(.init(
            title: "Side-by-side separation",
            description: "How many pixels (to VB scale) to seperate left and right images.",
            requiresRestart: true), range: .init(defaultValue: 0, min: 0, max: 100),
                               defaultValue: 0))

        
        let vbGroup:CoreOption = .group(.init(title: "VirtualBoy",
                                                     description: ""),
                                          subOptions: vbOptions)
        

        options.append(vbGroup)

        return options
    }
    
    // MARK: Global - Video
    static var video_blit_timesync: CoreOption {
        .bool(.init(
            title: "Enable time synchronization(waiting) for frame blitting",
            description: "Disable to reduce latency, at the cost of potentially increased video \"juddering\", with the maximum reduction in latency being about 1 video frame's time. Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.",
            requiresRestart: true),
              defaultValue: true)
    }
    
    static var video_fs: CoreOption {
        .bool(.init(
            title: "Fullscreen",
            description: "Enable fullscreen mode. May effect performance and scaling.",
            requiresRestart: true),
                                         defaultValue: false)
    }
    
    static var video_openglOption: CoreOption {
        .bool(.init(
            title: "Use OpenGL",
            description: "Experimental OpenGL mode.",
            requiresRestart: true),
                                         defaultValue: false)
    }
    
    // MARK: Global - CD
    // cd.image_memcach
    static var cd_image_memcache: CoreOption {
        .bool(.init(
            title: "Cache CD in memory",
            description: "Reads the entire CD image(s) into memory at startup(which will cause a small delay). Can help obviate emulation hiccups due to emulated CD access. May cause more harm than good on low memory systems.",
            requiresRestart: true), defaultValue: false)
    }

    // MARK: PCE
    static var pceFastOption: CoreOption {
		.bool(.init(
            title: "PCE Fast",
            description: "Use a faster but possibly buggy PCEngine version.",
            requiresRestart: true),
                                         defaultValue: false)
    }

    // MARK: SNES
    static var snesFastOption: CoreOption {
		.bool(.init(
            title: "SNES Fast",
            description: "Use faster but maybe more buggy SNES core (default)",
            requiresRestart: true), defaultValue: true)
    }
    
    static var snesFastSpexOption: CoreOption {
        .bool(.init(
            title: "1-frame speculative execution",
            description: "Hack to reduce input->output video latency by 1 frame. Enabling will increase CPU usage, and may cause video glitches(such as \"jerkiness\") in some oddball games, but most commercially-released games should be fine.",
            requiresRestart: true), defaultValue: false)
    }
    
    // MARK: PSX
    static var psx_h_overscan: CoreOption {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }

    static var psx_temporal_blur: CoreOption {
        .bool(.init(
            title: "Temporal Blur",
            description: "Enable video temporal blur(50/50 previous/current frame by default).",
            requiresRestart: true), defaultValue: false)
    }

    static var psx_temporal_blur_color: CoreOption {
        .bool(.init(
            title: "Temporal Color",
            description: "Accumulate color data rather than discarding it. Also requires Temporal Blur.",
            requiresRestart: true), defaultValue: false)
    }

            /*
             Enable specified special video scaler.
             The destination rectangle is NOT altered by this setting, so if you have xscale and yscale set to "2", and try to use a 3x scaling filter like hq3x, the image is not going to look that great. The nearest-neighbor scalers are intended for use with bilinear interpolation enabled, at high resolutions(such as 1280x1024; nn2x(or nny2x) + bilinear interpolation + fullscreen stretching at this resolution looks quite nice).

             none - None/Disabled

             hq2x - hq2x

             hq3x - hq3x

             hq4x - hq4x

             scale2x - scale2x

             scale3x - scale3x

             scale4x - scale4x

             2xsai - 2xSaI

             super2xsai - Super 2xSaI

             supereagle - Super Eagle

             nn2x - Nearest-neighbor 2x

             nn3x - Nearest-neighbor 3x

             nn4x - Nearest-neighbor 4x

             nny2x - Nearest-neighbor 2x, y axis only

             nny3x - Nearest-neighbor 3x, y axis only

             nny4x - Nearest-neighbor 4x, y axis only
             */
    static var psx_video_scaler: CoreOption {
        .enumeration(.init(title: "Enable specified special video scaler",
                           description: " The destination rectangle is NOT altered by this setting, so if you have xscale and yscale set to \"2\", and try to use a 3x scaling filter like hq3x, the image is not going to look that great. The nearest-neighbor scalers are intended for use with bilinear interpolation enabled, at high resolutions(such as 1280x1024; nn2x(or nny2x) + bilinear interpolation + fullscreen stretching at this resolution looks quite nice).",
                           requiresRestart: true),
                     values: [
                        .init(title: "None", description: "None/Disabled", value: 0),
                        .init(title: "hq2x", description: "hq2x", value: 1),
                        .init(title: "hq3x", description: "hq3x", value: 2),
                        .init(title: "hq4x", description: "hq4x", value: 3),
                        .init(title: "scale2x", description: "scale2x", value: 4),
                        .init(title: "scale3x", description: "scale3x", value: 5),
                        .init(title: "scale4x", description: "scale4x", value: 6),
                        .init(title: "2xsai", description: "2xSaI", value: 7),
                        .init(title: "super2xsai", description: "Super 2xSaI", value: 8),
                        .init(title: "supereagle", description: "Super Eagle", value: 9),
                        .init(title: "nn2x", description: "Nearest-neighbor 2x", value: 10),
                        .init(title: "nn3x", description: "Nearest-neighbor 3x", value: 11),
                        .init(title: "nn4x", description: "Nearest-neighbor 4x", value: 12),
                        .init(title: "nny2x", description: "Nearest-neighbor 2x, y axis only", value: 13),
                        .init(title: "nny3x", description: "Nearest-neighbor 2x, y axis only", value: 14),
                        .init(title: "nny4x", description: "Nearest-neighbor 2x, y axis only", value: 15),
                     ],
                     defaultValue: 0)
    }
            /*
             0 - Disabled

             full - Full
             Full-screen stretch, disregarding aspect ratio.

             aspect - Aspect Preserve
             Full-screen stretch as far as the aspect ratio(in this sense, the equivalent xscalefs == yscalefs) can be maintained.

             aspect_int - Aspect Preserve + Integer Scale
             Full-screen stretch, same as "aspect" except that the equivalent xscalefs and yscalefs are rounded down to the nearest integer.

             aspect_mult2 - Aspect Preserve + Integer Multiple-of-2 Scale
             Full-screen stretch, same as "aspect_int", but rounds down to the nearest multiple of 2.
             */
    static var psx_stretch: CoreOption {
        .enumeration(.init(title: "Stretch to fill screen",
                           description: "",
                           requiresRestart: true),
                     values: [
                        .init(title: "Disabled", description: "Disabled", value: 0),
                        .init(title: "Full", description: "Full-screen stretch, disregarding aspect ratio", value: 1),
                        .init(title: "extram1", description: "1MiB Extended RAM", value: 2),
                        .init(title: "extram4", description: "4MiB Extended RAM", value: 3),
                        .init(title: "cs1ram16", description: "Aspect Preserve + Integer Multiple-of-2 Scale Full-screen stretch, same as \"aspect_int\", but rounds down to the nearest multiple of 2.", value: 4),
                     ],
                     defaultValue: 0)
    }

    // MARK: SS
    static var ss_h_overscan: CoreOption {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }
    
    // ss.cart.auto_default
    // none, backup*, extram1, extram4, cs1ram16
    static var ss_cart_autodefault: CoreOption {
        .enumeration(.init(title: "Default cart",
                           description: "Default expansion cart when autodetection fails.",
                           requiresRestart: true),
                     values: [
                        .init(title: "none", description: "None", value: 0),
                        .init(title: "backup", description: "Backup Memory(512KiB)", value: 1),
                        .init(title: "extram1", description: "1MiB Extended RAM", value: 2),
                        .init(title: "extram4", description: "4MiB Extended RAM", value: 3),
                        .init(title: "cs1ram16", description: "16MiB RAM mapped in A-bus CS1", value: 4),
                     ],
                     defaultValue: 1)
    }

    // ss.region_default
    static var ss_region_default: CoreOption {
        .enumeration(.init(title: "Default region",
                           description: "Used if region autodetection fails.",
                           requiresRestart: true),
                     values: [
                        .init(title: "jp", description: "Japan", value: 0),
                        .init(title: "na", description: "North America", value: 1),
                        .init(title: "eu", description: "Europe", value: 2),
                        .init(title: "kr", description: "South Korea", value: 3),
                        .init(title: "tw", description: "Taiwan", value: 4),
                        .init(title: "as", description: "China", value: 5),
                        .init(title: "br", description: "Brazil", value: 6),
                        .init(title: "la", description: "Latin Ameica", value: 7),
                     ],
                     defaultValue: 0)
    }
    
    // MARK: VB
    static var vb_instant_display_hack: CoreOption {
        .bool(.init(
            title: "Display latency reduction hack",
            description: "Reduces latency in games by displaying the framebuffer 20ms earlier. This hack has some potential of causing graphical glitches, so it is disabled by default.",
            requiresRestart: true), defaultValue: false)
    }
    
    static var vb_sidebyside: CoreOption {
        .bool(.init(
            title: "Side by side mode",
            description: "The left-eye image is displayed on the left, and the right-eye image is displayed on the right.",
            requiresRestart: true), defaultValue: false)
    }
}

@objc public extension MednafenGameCore {
    // Global Video
    @objc(video_blit_timesync) var video_blit_timesync: Bool { MednafenGameCore.valueForOption(MednafenGameCore.video_blit_timesync).asBool }
    @objc(video_fs) var video_fs: Bool { MednafenGameCore.valueForOption(MednafenGameCore.video_fs).asBool }
    
    // Global - CD
    @objc(cd_image_memcache) var cd_image_memcache: Bool { MednafenGameCore.valueForOption(MednafenGameCore.cd_image_memcache).asBool }
    
    // PCE
    @objc(mednafen_pceFast) var mednafen_pceFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.pceFastOption).asBool }
    
    // SNES Fast
    @objc(mednafen_snesFast) var mednafen_snesFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.snesFastOption).asBool }

    @objc(mednafen_snesFast_spex) var mednafen_snesFast_spex: Bool { MednafenGameCore.valueForOption(MednafenGameCore.snesFastSpexOption).asBool }
        
    // PSX
    @objc(psx_h_overscan) var psx_h_overscan: Bool { MednafenGameCore.valueForOption(MednafenGameCore.psx_h_overscan).asBool }

    // SS
    @objc(ss_region_default) var ss_region_default: Int { MednafenGameCore.valueForOption(MednafenGameCore.ss_region_default).asInt ?? 0 }
    @objc(ss_h_overscan) var ss_h_overscan: Bool { MednafenGameCore.valueForOption(MednafenGameCore.ss_h_overscan).asBool }
    @objc(ss_cart_autodefault) var ss_cart_autodefault: Int { MednafenGameCore.valueForOption(MednafenGameCore.ss_cart_autodefault).asInt ?? 1}
    
    // VB
    @objc(vb_instant_display_hack) var vb_instant_display_hack: Bool { MednafenGameCore.valueForOption(MednafenGameCore.vb_instant_display_hack).asBool }
    
    @objc(vb_sidebyside) var vb_sidebyside: Bool { MednafenGameCore.valueForOption(MednafenGameCore.vb_sidebyside).asBool }

    // Helpers
    static func bool(forOption option: String) -> Bool {
        return storedValueForOption(Bool.self, option) ?? false
    }

    static func int(forOption option: String) -> Int {
        let value = storedValueForOption(Int.self, option)
        return value ?? 0
    }

    static func float(forOption option: String) -> Float {
        let value = storedValueForOption(Float.self, option)
        return value ?? 0
    }

    static func string(forOption option: String) -> String? {
        let value = storedValueForOption(String.self, option)
        return value
    }
    
    
    // TODO: Fix me, FINISH FOR MAKE BETTER
    func parseOptions() {
        self.video_opengl = MednafenGameCore.valueForOption(MednafenGameCore.video_openglOption).asBool;
    }
}
