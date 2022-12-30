import Foundation

extension PVFlycastCore: CoreOptional {
     static var resolutionOption: CoreOption = {
         /*
          Internal resolution (restart) [flycast_internal_resolution] (640x480|1280x960|1920x1440|2560x1920|3200x2400|3840x2880|
          4480x3360|5120x3840|5760x4320|6400x4800|7040x5280|7680x5760|8320x6240|8960x6720|
          9600x7200|10240x7680|10880x8160|11520x8640|12160x9120|12800x9600)
          */
          .enumeration(.init(title: "Resolution Upscaling",
                description: "(Requires Restart)",
                requiresRestart: true),
            values: [
                .init(title: "1X", description: "1X", value: 1),
                .init(title: "2X", description: "2X", value: 2),
                .init(title: "3X", description: "3X", value: 3),
                .init(title: "4X", description: "4X", value: 4),
                .init(title: "5X", description: "5X", value: 5),
                .init(title: "6X", description: "6X", value: 6),
                .init(title: "7X", description: "7X", value: 7),
                .init(title: "8X", description: "8X", value: 8),
                .init(title: "16X", description: "16X", value: 16),
            ],
            defaultValue: 2)
            }()
    
    /*
     ## System
     Region [flycast_region] (Default|Japan|USA|Europe)

     Language [flycast_language] (Default|Japanese|English|German|French|Spanish|Italian)
     HLE BIOS [flycast_hle_bios] (disabled|enabled)

     Force use of high-level emulation BIOS.

     Boot to BIOS [flycast_boot_to_bios] (disabled|enabled)

     Boot directly into the Dreamcast BIOS menu.

     Enable DSP [flycast_enable_dsp] (enabled|disabled)

     Enable emulation of the Dreamcast's audio DSP (digital signal processor). Improves the accuracy of generated sound, but increases performance requirements.

     Force Windows CE Mode [flycast_force_windows_ce_modee] (disabled|enabled)

     Enable full MMU (Memory Management Unit) emulation and other settings for Windows CE games.
 
     ## Video

     Configure visual buffers & effects, display parameters, framerate/-skip and rendering/texture parameters.

     Internal resolution (restart) [flycast_internal_resolution] (640x480|1280x960|1920x1440|2560x1920|3200x2400|3840x2880|
     4480x3360|5120x3840|5760x4320|6400x4800|7040x5280|7680x5760|8320x6240|8960x6720|
     9600x7200|10240x7680|10880x8160|11520x8640|12160x9120|12800x9600)

     Modify rendering resolution.

     Internal resolution - 640x480
     Internal resolution - 1920x1440
     Cable Type [flycast_cable_type] (TV (Composite)2|TV (RGB)|VGA(RGB))

     The output signal type. 'TV (Composite)' is the most widely supported.

     Broadcast Standard [flycast_brodcast] (Default|PAL-M (Brazil)|PAL-N (Argentina, Paraguay, Uruguay)|NTSC|PAL (World))

     Screen Orientation [flycast_screen_orientation] (Horizontal|Vertical)

     Alpha Sorting [flycast_alpha_sorting] (Per-Strip (fast, least accurate)|Per-Triangle (normal)|"Per-Pixel (accurate, but slowest)1)

     Enable RTT (Render To Texture) Buffer (Off|On)

     Mipmapping (Off|On)

     Volume modifier (On|off)

     A GPU feature that is typically used by games to draw shadows of objects. You should typically leave this on - performance impact should be minimal to negligible.

     Anisotropic Filtering [flycast_anistropic_filtering] (4|2|8|16)

     Enhance the quality of textures on surfaces that are at oblique viewing angles with respect to the camera.

     Delay Frame Swapping [flycast_delay_frame_swapping] (disabled|enabled)

     Useful to avoid flashing screens or glitchy videos. Not recommended on slow platforms. Note: This setting only applies when 'Threaded Rendering' is enabled.

     PowerVR2 Post-processing Filter [flycast_pvr2_filtering] (disabled|enabled)

     Post-process the rendered image to simulate effects specific to the PowerVR2 GPU and analog video signals.
     
     Performance¶

     Configure threaded rendering, integer division optimisations and frame skip settings

     Threaded Rendering (Restart Required) [flycast_threaded_rendering] (enabled|disabled)

     Runs the GPU and CPU on different threads. Highly recommended.

     Auto Skip Frame [flycast_skip_frame] (disabled|enabled)

     Automatically skip frames when the emulator is running slow. Note: This setting only applies when 'Threaded Rendering' is enabled.

     Frame Skipping [flycast_frame_skipping] (disabled|1|2|3|4|5|6)

     Sets the number of frames to skip between each displayed frame.

     Widescreen Cheats (Restart Required) [flycast_widescreen_cheats] (Off|On)

     Activates cheats that allow certain games to display in widescreen format.

     Widescreen Hack [flycast_widescreen_hack] (Off|On)

     Draw geometry outside of the normal 4:3 aspect ratio. May produce graphical glitches in the revealed areas.

     GD-ROM Fast Loading (inaccurate) [flycast_gdrom_fast_loading] (On|Off)

     Speeds up GD-ROM loading.

     Load Custom Textures [flycast_custom_textures] (Off|On)

     Dump Textures [flycast_dump_textures] (Off|On)

     Input¶

     Configure gamepad and light gun settings.

     Analog Stick Deadzone [flycast_analog_stick_deadzone] (15%|0%|5%|10%|20%|25%|30%)

     Trigger Deadzone [flycast_trigger_deadzone] (0%|5%|10%|15%|20%|25%|30%)

     Digital Triggers [flycast_digital_triggers] (Off|On)

     Purupuru Pack/Vibration Pack [flycast_enable_purupuru] (On|Off)

     Enables controller force feedback.

     Gun crosshair 1 Display [flycast_lightgun1_crosshair] (Off|White|Red|Green|Blue)

     Gun crosshair 2 Display [flycast_lightgun2_crosshair] (Off|White|Red|Green|Blue)

     Gun crosshair 3 Display [flycast_lightgun3_crosshair] (Off|White|Red|Green|Blue)

     Gun crosshair 4 Display [flycast_lightgun4_crosshair] (Off|White|Red|Green|Blue)

     ## Visual Memory Unit¶

     Configure per-game VMU save files and on-scren VMU visibility sttings.

     Per-Game VMUs [flycast_per_content_vmus] (disabled|VMU A1|All VMUs)

     When disabled, all games share 4 VMU save files (A1, B1, C1, D1) located in RetroArch's system directory. The 'VMU A1' setting creates a unique VMU 'A1' file in RetroArch's save directory for each game that is launched. The 'All VMUs' setting creates 4 unique VMU files (A1, B1, C1, D1) for each game that is launched.

     VMU Screen 1 Display [flycast_vmu1_screen_display] (Off|enabled)

     VMU Screen 1 Position [flycast_vmu1_screen_position] (Upper Left|Upper Right|Lower Left|Lower Right)

     VMU Screen 1 Size [flycast_vmu1_screen_size] (1x|2x|3x|4x|5x)

     VMU Screen 1 Pixel On Color [flycast_vmu1_pixel_on_color] (Default ON|Default OFF|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 1 Pixel Off Color [flycast_vmu1_pixel_off_color] (Default OFF|Default ON|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 1 Opacity [flycast_vmu1_screen_opacity] (100%|10%|20%|30%|40%|50%|60%|70%|80%|90%)

     VMU Screen 2 Display [flycast_vmu2_screen_display] (Off|enabled)

     VMU Screen 2 Position [flycast_vmu2_screen_position] (Upper Left|Upper Right|Lower Left|Lower Right)

     VMU Screen 2 Size [flycast_vmu2_screen_size] (1x|2x|3x|4x|5x)

     VMU Screen 2 Pixel On Color [flycast_vmu2_pixel_on_color] (Default ON|Default OFF|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 2 Pixel Off Color [flycast_vmu2_pixel_off_color] (Default OFF|Default ON|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 2 Opacity [flycast_vmu2_screen_opacity] (100%|10%|20%|30%|40%|50%|60%|70%|80%|90%)

     VMU Screen 3 Display [flycast_vmu3_screen_display] (Off|enabled)

     VMU Screen 3 Position [flycast_vmu3_screen_position] (Upper Left|Upper Right|Lower Left|Lower Right)

     VMU Screen 3 Size [flycast_vmu3_screen_size] (1x|2x|3x|4x|5x)

     VMU Screen 3 Pixel On Color [flycast_vmu3_pixel_on_color] (Default ON|Default OFF|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 3 Pixel Off Color [flycast_vmu3_pixel_off_color] (Default OFF|Default ON|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 3 Opacity [flycast_vmu3_screen_opacity] (100%|10%|20%|30%|40%|50%|60%|70%|80%|90%)

     VMU Screen 4 Display [flycast_vmu4_screen_display] (Off|enabled)

     VMU Screen 4 Position [flycast_vmu4_screen_position] (Upper Left|Upper Right|Lower Left|Lower Right)

     VMU Screen 4 Size [flycast_vmu4_screen_size] (1x|2x|3x|4x|5x)

     VMU Screen 4 Pixel On Color [flycast_vmu4_pixel_on_color] (Default ON|Default OFF|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 4 Pixel Off Color [flycast_vmu4_pixel_off_color] (Default OFF|Default ON|Black|Blue|Light Blue|Green|Cyan|Cyan Blue|Light Green|Cyan Green|Light Cyan|Red|Purple|Light Purple|Yellow|Gray|Light Purple (2)|Light Green (2)|Light Green (3)|Light Cyan (2)|Light Red(2)|Magenta|Light Purple (3)|Light Oragen|Orange|Light Purple(4)|Light Yellow|Light Yellow (2)|White)

     VMU Screen 4 Opacity [flycast_vmu4_screen_opacity] (100%|10%|20%|30%|40%|50%|60%|70%|80%|90%)
     */
    
    static var gsOption: CoreOption = {
         .enumeration(.init(title: "Graphics Handler",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "OpenGL", description: "OpenGL", value: 0),
               .init(title: "Vulkan", description: "Vulkan (Experimental)", value: 1)
          ],
          defaultValue: 0)
    }()
    
    static var forceBilinearFilteringOption: CoreOption = {
        .bool(.init(
            title: "Enable bilinear filtering.",
            description: nil,
            requiresRestart: false))
    }()
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [resolutionOption, gsOption, forceBilinearFilteringOption]
        let coreGroup:CoreOption = .group(.init(title: "Play! Core",
                                                description: "Global options for Play!"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVFlycastCore {
//    @objc var resolution: Int{
//        PVFlycastCore.valueForOption(PVPlayCore.resolutionOption).asInt ?? 0
//    }
//    @objc var gs: Int{
//        PVFlycastCore.valueForOption(PVPlayCore.gsOption).asInt ?? 0
//    }
//    @objc var bilinearFiltering: Bool {
//        PVFlycastCore.valueForOption(PVPlayCore.forceBilinearFilteringOption).asBool
//    }
    func parseOptions() {
//        self.gsPreference = NSNumber(value: gs).int8Value
//        self.resFactor = NSNumber(value: resolution).int8Value
    }
}
//
//extension PVFlycastCore: GameWithCheat {
//    @objc public func setCheat(
//        code: String,
//        type: String,
//        codeType: String,
//        cheatIndex: UInt8,
//        enabled: Bool
//    ) -> Bool
//    {
//        do {
//            NSLog("Calling setCheat %@ %@ %@", code, type, codeType)
//            try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
//            return true
//        } catch let error {
//            NSLog("Error setCheat \(error)")
//            return false
//        }
//    }
//
//    public func supportsCheatCode() -> Bool
//    {
//        return true
//    }
//
//    public func cheatCodeTypes() -> NSArray {
//        return [
//            "Code Breaker",
//            "Game Shark V3",
//            "Pro Action Replay V1",
//            "Pro Action Replay V2",
//            "Raw MemAddress:Value Pairs"
//        ];
//    }
//}
//
