//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
import Foundation
// import PVMednafen.Private

extension MednafenGameCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        switch systemType {
        case .PSX:
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
    public static var options: [CoreOption] = {
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
    }()
    
    // MARK: Global - Video
    static var video_blit_timesync: CoreOption = {
        .bool(.init(
            title: "Enable time synchronization(waiting) for frame blitting",
            description: "Disable to reduce latency, at the cost of potentially increased video \"juddering\", with the maximum reduction in latency being about 1 video frame's time. Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.",
            requiresRestart: true),
              defaultValue: true)
    }()
    
    static var video_fs: CoreOption = {
        .bool(.init(
            title: "Fullscreen",
            description: "Enable fullscreen mode. May effect performance and scaling.",
            requiresRestart: true),
                                         defaultValue: false)
    }()
    
    static var video_openglOption: CoreOption = {
        .bool(.init(
            title: "Use OpenGL",
            description: "Experimental OpenGL mode.",
            requiresRestart: true),
                                         defaultValue: false)
    }()
    
    // MARK: Global - CD
    // cd.image_memcach
    static var cd_image_memcache: CoreOption = {
        .bool(.init(
            title: "Cache CD in memory",
            description: "Reads the entire CD image(s) into memory at startup(which will cause a small delay). Can help obviate emulation hiccups due to emulated CD access. May cause more harm than good on low memory systems.",
            requiresRestart: true), defaultValue: false)
    }()

    // MARK: PCE
    static var pceFastOption: CoreOption = {
		.bool(.init(
            title: "PCE Fast",
            description: "Use a faster but possibly buggy PCEngine version.",
            requiresRestart: true),
                                         defaultValue: false)
    }()

    // MARK: SNES
    static var snesFastOption: CoreOption = {
		.bool(.init(
            title: "SNES Fast",
            description: "Use faster but maybe more buggy SNES core (default)",
            requiresRestart: true), defaultValue: true)
    }()
    
    static var snesFastSpexOption: CoreOption = {
        .bool(.init(
            title: "1-frame speculative execution",
            description: "Hack to reduce input->output video latency by 1 frame. Enabling will increase CPU usage, and may cause video glitches(such as \"jerkiness\") in some oddball games, but most commercially-released games should be fine.",
            requiresRestart: true), defaultValue: false)
    }()
    
    // MARK: PSX
    static var psx_h_overscan: CoreOption = {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }()
    
    // MARK: SS
    static var ss_h_overscan: CoreOption = {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }()
    
    // ss.cart.auto_default
    // none, backup*, extram1, extram4, cs1ram16
    static var ss_cart_autodefault: CoreOption = {
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
    }()

    // ss.region_default
    static var ss_region_default: CoreOption = {
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
    }()
    
    // MARK: VB
    static var vb_instant_display_hack: CoreOption = {
        .bool(.init(
            title: "Display latency reduction hack",
            description: "Reduces latency in games by displaying the framebuffer 20ms earlier. This hack has some potential of causing graphical glitches, so it is disabled by default.",
            requiresRestart: true), defaultValue: false)
    }()
    
    static var vb_sidebyside: CoreOption = {
        .bool(.init(
            title: "Side by side mode",
            description: "The left-eye image is displayed on the left, and the right-eye image is displayed on the right.",
            requiresRestart: true), defaultValue: false)
    }()
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
