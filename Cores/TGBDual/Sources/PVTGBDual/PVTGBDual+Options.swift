//
//  PVTGBDualCore+Options.swift
//  PVTGBDualCore
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging
import libtgbdual
import PVEmulatorCore

/*
 { "tgbdual_gblink_enable", "Link cable emulation (reload); disabled|enabled" },
 { "tgbdual_screen_placement", "Screen layout; left-right|top-down" },
 { "tgbdual_switch_screens", "Switch player screens; normal|switched" },
 { "tgbdual_single_screen_mp", "Show player screens; both players|player 1 only|player 2 only" },
 { "tgbdual_audio_output", "Audio output; Game Boy #1|Game Boy #2" },
 */

extension PVTGBDualCore: @preconcurrency CoreOptional {
    @MainActor public static var options: [CoreOption] {
        var options = [CoreOption]()

        let consoleGroup = CoreOption.group(.init(title: "Console",
                                                description: nil),
                                          subOptions: [linkCableEmulationOption])

        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [screenPlacementOption, switchScreensOptions, showPlayerScreensOption])

        let audioGroup = CoreOption.group(.init(title: "Audio",
                                                description: nil),
                                          subOptions: [audioOutputOption])

        options.append(consoleGroup)
        options.append(videoGroup)
        options.append(audioGroup)

        return options
    }

    // MARK: Link Cable
    @MainActor static var linkCableEmulationOption: CoreOption {
        .bool(.init(title: "tgbdual_gblink_enable",
                    description: "Link cable emulation (reload)",
                    requiresRestart: true), defaultValue: false)
    }

    // MARK: Video
    @MainActor static var screenPlacementOption: CoreOption {
        .enumeration(.init(title: "Screen layout"),
                     values: [
                        .init(title: "Left/Right", value: 0),
                        .init(title: "Top/Down", value: 1),
                     ])
    }

    @MainActor static var switchScreensOptions: CoreOption {
        .enumeration(.init(title: "Switch Screen"),
                     values: [
                        .init(title: "Normal", value: 0),
                        .init(title: "Switched", value: 1),
                     ])
    }

    @MainActor static var showPlayerScreensOption: CoreOption {
        .enumeration(.init(title: "Show player screens"),
                     values: [
                        .init(title: "Both Players", value: 0),
                        .init(title: "Player 1 Only", value: 1),
                        .init(title: "Player 2 Only", value: 2),
                     ])
    }

    // MARK: Audio
    @MainActor static var audioOutputOption: CoreOption {
        .enumeration(.init(title: "Audio output"),
                     values: [
                        .init(title: "Game Boy #1", value: 0),
                        .init(title: "Game Boy #2", value: 1),
                     ])
    }


    @MainActor @objc(getVariable:)
    public func get(variable: String) -> Any? {
        switch variable {
        case "tgbdual_gblink_enable":
            return Self.valueForOption(Self.linkCableEmulationOption).asBool
        case "tgbdual_screen_placement":
            switch Self.valueForOption(Self.screenPlacementOption).asInt ?? 0 {
            case 0: return "left-right"
            case 1: return "top-down"
            default: return "left-right"
            }
        case "tgbdual_switch_screens":
            switch Self.valueForOption(Self.switchScreensOptions).asInt ?? 0 {
            case 0: return "normal"
            case 1: return "switched"
            default: return "normal"
            }
        case "tgbdual_single_screen_mp":
            switch Self.valueForOption(Self.showPlayerScreensOption).asInt ?? 0 {
            case 0: return "both players"
            case 1: return "player 1 only"
            case 2: return "player 2 only"
            default: return "both players"
            }
        case "tgbdual_audio_output":
            switch Self.valueForOption(Self.audioOutputOption).asInt ?? 0 {
            case 0: return "Game Boy #1"
            case 1: return "Game Boy #2"
            default: return "Game Boy #1"
            }
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
