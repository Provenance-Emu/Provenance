//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import Foundation
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore
import PVSettings

@objc
public final class MednafenGameCoreOptions: NSObject, CoreOptions, CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let globalGroup:CoreOption = .group(.init(title: "Core",
                                                description: "Global options for all Mednafen cores."),
                                          subOptions: [cd_image_memcache_option])
        options.append(globalGroup)
        
            // These seem to be broken, mednafen console says not found
        let videoGroup:CoreOption = .group(.init(title: "Video",
                                                description: "Video options for all Mednafen cores."),
                                           subOptions: [video_blit_timesync_option, video_fs_option, video_openglOption])

        options.append(videoGroup)
        
        
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
                                          subOptions: [psx_h_overscan_option])
        
        options.append(psxGroup)
        
        let ssGroup:CoreOption = .group(.init(title: "Sega Saturn",
                                                     description: ""),
                                          subOptions: [ss_region_default_option, ss_cart_autodefault_option, ss_h_overscan_option])
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
        
        var vbOptions = [vb_instant_display_hack_option, vb_sidebyside_option]
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
    static var video_blit_timesync_option: CoreOption {
        .bool(.init(
            title: "Enable time synchronization(waiting) for frame blitting",
            description: "Disable to reduce latency, at the cost of potentially increased video \"juddering\", with the maximum reduction in latency being about 1 video frame's time. Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.",
            requiresRestart: true),
              defaultValue: true)
    }
    
    static var video_fs_option: CoreOption {
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
    static var cd_image_memcache_option: CoreOption {
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
    static var psx_h_overscan_option: CoreOption {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }

    static var psx_temporal_blur_option: CoreOption {
        .bool(.init(
            title: "Temporal Blur",
            description: "Enable video temporal blur(50/50 previous/current frame by default).",
            requiresRestart: true), defaultValue: false)
    }

    static var psx_temporal_blur_color_option: CoreOption {
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
    static var psx_video_scaler_option: CoreOption {
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
    static var psx_stretch_option: CoreOption {
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
    static var ss_h_overscan_option: CoreOption {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }
    
    // ss.cart.auto_default
    // none, backup*, extram1, extram4, cs1ram16
    static var ss_cart_autodefault_option: CoreOption {
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
    static var ss_region_default_option: CoreOption {
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
    static var vb_instant_display_hack_option: CoreOption {
        .bool(.init(
            title: "Display latency reduction hack",
            description: "Reduces latency in games by displaying the framebuffer 20ms earlier. This hack has some potential of causing graphical glitches, so it is disabled by default.",
            requiresRestart: true), defaultValue: false)
    }
    
    static var vb_sidebyside_option: CoreOption {
        .bool(.init(
            title: "Side by side mode",
            description: "The left-eye image is displayed on the left, and the right-eye image is displayed on the right.",
            requiresRestart: true), defaultValue: false)
    }
}

@objc public extension MednafenGameCoreOptions {
    // Global Video
    @objc(video_blit_timesync) static var video_blit_timesync: Bool { valueForOption(video_blit_timesync_option).asBool }
    @objc(video_fs) static var video_fs: Bool { valueForOption(video_fs_option).asBool }
    @objc(video_opengl) static var video_opengl: Bool { valueForOption(video_openglOption).asBool }

    // Global - CD
    @objc(cd_image_memcache) static var cd_image_memcache: Bool { valueForOption(cd_image_memcache_option).asBool }
    
    // PCE
    @objc(mednafen_pceFast) static var mednafen_pceFast: Bool { valueForOption(pceFastOption).asBool }
    
    // SNES Fast
    @objc(mednafen_snesFast) static var mednafen_snesFast: Bool { valueForOption(snesFastOption).asBool }

    @objc(mednafen_snesFast_spex) static var mednafen_snesFast_spex: Bool { valueForOption(snesFastSpexOption).asBool }
        
    // PSX
    @objc(psx_h_overscan) static var psx_h_overscan: Bool { valueForOption(psx_h_overscan_option).asBool }

    // SS
    @objc(ss_region_default) static var ss_region_default: Int { valueForOption(ss_region_default_option).asInt ?? 0 }
    @objc(ss_h_overscan) static var ss_h_overscan: Bool { valueForOption(ss_h_overscan_option).asBool }
    @objc(ss_cart_autodefault) static var ss_cart_autodefault: Int { valueForOption(ss_cart_autodefault_option).asInt ?? 1}
    
    // VB
    @objc(vb_instant_display_hack) static var vb_instant_display_hack: Bool { valueForOption(vb_instant_display_hack_option).asBool }
    
    @objc(vb_sidebyside) static var vb_sidebyside: Bool { valueForOption(vb_sidebyside_option).asBool }
}
