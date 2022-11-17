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
    public func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
    {
        do {
            try self.setCheat(code, setType: type, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }
    
    public func supportsCheatCode() -> Bool
    {
        return self.getCheatSupport();
    }
}

extension MednafenGameCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()
        
        let videoGroup:CoreOption = .group(.init(title: "Video",
                                                description: "Video options for all Mednafen cores."),
                                          subOptions: [video_blit_timesync, video_fs, video_openglOption])
        

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
                                          subOptions: [psx_h_overscan])
        

        options.append(psxGroup)
        
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

    static var pceFastOption: CoreOption = {
		.bool(.init(
            title: "PCE Fast",
            description: "Use a faster but possibly buggy PCEngine version.",
            requiresRestart: true),
                                         defaultValue: false)
    }()

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
    
    static var psx_h_overscan: CoreOption = {
        .bool(.init(
            title: "Overscan",
            description: "Show horizontal overscan area.",
            requiresRestart: true), defaultValue: true)
    }()
    
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
    @objc(video_blit_timesync) var video_blit_timesync: Bool { MednafenGameCore.valueForOption(MednafenGameCore.video_blit_timesync).asBool }
    @objc(video_fs) var video_fs: Bool { MednafenGameCore.valueForOption(MednafenGameCore.video_fs).asBool }
    
    @objc(mednafen_pceFast) var mednafen_pceFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.pceFastOption).asBool }
    @objc(mednafen_snesFast) var mednafen_snesFast: Bool { MednafenGameCore.valueForOption(MednafenGameCore.snesFastOption).asBool }

    @objc(mednafen_snesFast_spex) var mednafen_snesFast_spex: Bool { MednafenGameCore.valueForOption(MednafenGameCore.snesFastSpexOption).asBool }
        
    @objc(psx_h_overscan) var psx_h_overscan: Bool { MednafenGameCore.valueForOption(MednafenGameCore.psx_h_overscan).asBool }

    @objc(vb_instant_display_hack) var vb_instant_display_hack: Bool { MednafenGameCore.valueForOption(MednafenGameCore.vb_instant_display_hack).asBool }
    
    @objc(vb_sidebyside) var vb_sidebyside: Bool { MednafenGameCore.valueForOption(MednafenGameCore.vb_sidebyside).asBool }

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
    
    func parseOptions() {
        self.video_opengl = MednafenGameCore.valueForOption(MednafenGameCore.video_openglOption).asBool;
    }
}
