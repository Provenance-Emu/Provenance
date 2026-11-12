//
//  PauseMenuTriggerTests.swift
//  PVUI
//

import Foundation
import PVSystems
import Testing
@testable import PVUIBase

/// Pads as GameController reports them.
private enum Pad {
    /// DualSense / DualShock 4: Create/Share is `buttonOptions`, PS is Home, no separate capture button.
    static let dualSense = PauseMenuPadCapabilities(
        hasExtendedProfile: true, hasOptions: true, hasHome: true, hasThumbstickButtons: true)
    /// Xbox Series: View is `buttonOptions`, plus a Share button.
    static let xboxSeries = PauseMenuPadCapabilities(
        hasExtendedProfile: true, hasOptions: true, hasShareButton: true, hasHome: true, hasThumbstickButtons: true)
    /// Xbox One: no Share button.
    static let xboxOne = PauseMenuPadCapabilities(
        hasExtendedProfile: true, hasOptions: true, hasHome: true, hasThumbstickButtons: true)
    /// Switch Pro: "−" is `buttonOptions`, plus Capture.
    static let switchPro = PauseMenuPadCapabilities(
        hasExtendedProfile: true, hasOptions: true, hasShareButton: true, hasHome: true, hasThumbstickButtons: true)
    /// Older MFi pad with a Home button but no Options.
    static let mfiWithHome = PauseMenuPadCapabilities(hasExtendedProfile: true, hasHome: true)
    /// First-generation MFi pad: one Menu button and nothing else.
    static let mfiBare = PauseMenuPadCapabilities(hasExtendedProfile: true)
    static let siriRemote = PauseMenuPadCapabilities(hasExtendedProfile: false)
    static let switchOnlineSNES = PauseMenuPadCapabilities(
        hasExtendedProfile: true, hasOptions: true, hasProfileTrigger: true)

    static let modern: [PauseMenuPadCapabilities] = [dualSense, xboxSeries, xboxOne, switchPro]
    static let all: [PauseMenuPadCapabilities] = modern + [mfiWithHome, mfiBare, siriRemote, switchOnlineSNES]
}

@Suite("PauseMenuBindingPolicy")
struct PauseMenuBindingPolicyTests {

    private func triggers(_ pad: PauseMenuPadCapabilities, select: Bool) -> [PauseMenuTrigger] {
        PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select).triggers
    }

    @Test("DualSense: Create opens the menu where the system has no Select")
    func dualSenseWithoutSelect() {
        #expect(triggers(Pad.dualSense, select: false) == [.options, .thumbstickChord, .startSelectChord])
    }

    @Test("DualSense: Create stays Select where the system uses it, and the chords open the menu")
    func dualSenseWithSelect() {
        #expect(triggers(Pad.dualSense, select: true) == [.thumbstickChord, .startSelectChord])
    }

    @Test("Xbox Series and Switch Pro: the capture button comes first on every system",
          arguments: [Pad.xboxSeries, Pad.switchPro], [true, false])
    func captureButtonIsPrimary(pad: PauseMenuPadCapabilities, select: Bool) {
        #expect(PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select).primary == .shareButton)
    }

    @Test("Xbox Series: View also opens the menu only where the system has no Select")
    func xboxSeriesViewButton() {
        #expect(triggers(Pad.xboxSeries, select: false) == [.shareButton, .options, .thumbstickChord, .startSelectChord])
        #expect(triggers(Pad.xboxSeries, select: true) == [.shareButton, .thumbstickChord, .startSelectChord])
    }

    @Test("Xbox One has no capture button and behaves like a PlayStation pad")
    func xboxOne() {
        #expect(triggers(Pad.xboxOne, select: false) == triggers(Pad.dualSense, select: false))
        #expect(triggers(Pad.xboxOne, select: true) == triggers(Pad.dualSense, select: true))
    }

    @Test("A pad with an Options button never opens the menu from Home", arguments: Pad.modern, [true, false])
    func homeIsNotUsedOnModernPads(pad: PauseMenuPadCapabilities, select: Bool) {
        #expect(!PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select).triggers.contains(.home))
    }

    @Test("Every modern pad keeps a backup input on every system", arguments: Pad.modern, [true, false])
    func modernPadsHaveABackup(pad: PauseMenuPadCapabilities, select: Bool) {
        let plan = PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select)
        #expect(plan.primary != nil)
        #expect(!plan.backups.isEmpty)
    }

    @Test("Home is the fallback for an older MFi pad without Options")
    func olderMFiUsesHome() {
        #expect(triggers(Pad.mfiWithHome, select: true) == [.home])
    }

    @Test("A pad with only a Menu button pauses from it")
    func bareMFiUsesItsMenuButton() {
        #expect(triggers(Pad.mfiBare, select: true) == [.legacyPause])
    }

    @Test("The Siri Remote pauses from Menu")
    func siriRemote() {
        #expect(triggers(Pad.siriRemote, select: false) == [.legacyPause])
    }

    @Test("A Switch Online pad pauses only from its own trigger")
    func switchOnlinePad() {
        #expect(triggers(Pad.switchOnlineSNES, select: true) == [.profileTrigger])
        #expect(PauseMenuBindingPolicy.plan(for: Pad.switchOnlineSNES, systemUsesSelect: true).polledTriggers.isEmpty)
    }

    @Test("Every pad can open the menu on every system", arguments: Pad.all, [true, false])
    func everyPadHasATrigger(pad: PauseMenuPadCapabilities, select: Bool) {
        #expect(PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select).primary != nil)
    }

    @Test("Only a pad's single Menu button answers to the iOS setting")
    func onlyLegacyPauseIsGated() {
        for trigger in PauseMenuTrigger.allCases {
            #expect(trigger.alwaysOpensMenu == (trigger != .legacyPause))
        }
    }

    @Test("Systems with a Select button keep Options for the game",
          arguments: [SystemIdentifier.NES, .SNES, .GB, .GBA, .PSX, .PCE])
    func systemsThatUseSelect(system: SystemIdentifier) {
        #expect(PauseMenuBindingPolicy.systemUsesSelect(system))
    }

    @Test("Systems without one free Options for the menu",
          arguments: [SystemIdentifier.N64, .Dreamcast, .Saturn, .GameCube, .Genesis, .SegaCD, .MAME, .NeoGeo])
    func systemsThatDoNotUseSelect(system: SystemIdentifier) {
        #expect(!PauseMenuBindingPolicy.systemUsesSelect(system))
    }

    @Test("An unknown system is assumed to use Select")
    func unknownSystemKeepsSelect() {
        #expect(PauseMenuBindingPolicy.systemUsesSelect(nil))
        #expect(PauseMenuBindingPolicy.systemUsesSelect(.Unknown))
    }

    @Test("A pause request carries its trigger")
    func notificationRoundTrip() {
        let note = Notification(name: .pvPauseGame, object: nil,
                                userInfo: [PauseMenuTrigger.userInfoKey: PauseMenuTrigger.thumbstickChord.rawValue])
        #expect(PauseMenuTrigger(pauseRequest: note) == .thumbstickChord)
        #expect(PauseMenuTrigger(pauseRequest: Notification(name: .pvPauseGame)) == nil)
        #expect(PauseMenuTrigger(pauseRequest: nil) == nil)
    }
}

@Suite("PauseMenuTriggerDetector")
struct PauseMenuTriggerDetectorTests {

    /// Feeds `samples` to a fresh detector and returns what each one fired.
    /// `update` is mutating, and `#expect` evaluates its argument in a closure
    /// that can't mutate captured state, so the calls happen here.
    private func fired(_ pad: PauseMenuPadCapabilities, select: Bool,
                       _ samples: PauseMenuButtonSample...) -> [PauseMenuTrigger?] {
        var detector = PauseMenuTriggerDetector(plan: PauseMenuBindingPolicy.plan(for: pad, systemUsesSelect: select))
        return samples.map { detector.update(with: $0) }
    }

    private let idle = PauseMenuButtonSample()

    @Test("A press fires once, however long it is held")
    func pressFiresOnce() {
        let down = PauseMenuButtonSample(options: true)
        #expect(fired(Pad.dualSense, select: false, idle, down, down, down, idle) == [nil, .options, nil, nil, nil])
    }

    @Test("A second press fires again")
    func secondPressFires() {
        let down = PauseMenuButtonSample(options: true)
        #expect(fired(Pad.dualSense, select: false, idle, down, idle, down) == [nil, .options, nil, .options])
    }

    @Test("A button held when sampling starts fires nothing until it is pressed again")
    func heldAtStartIsIgnored() {
        let down = PauseMenuButtonSample(share: true)
        #expect(fired(Pad.xboxSeries, select: true, down, down, idle, down) == [nil, nil, nil, .shareButton])
    }

    @Test("Start alone never opens the menu", arguments: Pad.modern, [true, false])
    func startAloneNeverFires(pad: PauseMenuPadCapabilities, select: Bool) {
        let start = PauseMenuButtonSample(menu: true)
        #expect(fired(pad, select: select, idle, start, start, idle, start) == [nil, nil, nil, nil, nil])
    }

    @Test("Select alone does not open the menu where the system uses it", arguments: Pad.modern)
    func selectAloneStaysWithTheGame(pad: PauseMenuPadCapabilities) {
        let selectDown = PauseMenuButtonSample(options: true)
        #expect(fired(pad, select: true, idle, selectDown, selectDown, idle) == [nil, nil, nil, nil])
    }

    @Test("Home does nothing on a pad with an Options button", arguments: Pad.modern, [true, false])
    func homeIsIgnoredOnModernPads(pad: PauseMenuPadCapabilities, select: Bool) {
        #expect(fired(pad, select: select, idle, PauseMenuButtonSample(home: true)) == [nil, nil])
    }

    @Test("Select + Start opens the menu whichever button lands first")
    func startSelectChord() {
        let select = PauseMenuButtonSample(options: true)
        let start = PauseMenuButtonSample(menu: true)
        let both = PauseMenuButtonSample(options: true, menu: true)
        #expect(fired(Pad.dualSense, select: true, idle, select, both, both) == [nil, nil, .startSelectChord, nil])
        #expect(fired(Pad.dualSense, select: true, idle, start, both, start) == [nil, nil, .startSelectChord, nil])
        #expect(fired(Pad.dualSense, select: true, idle, both) == [nil, .startSelectChord])
    }

    @Test("Both thumbsticks open the menu; one does not")
    func thumbstickChord() {
        let left = PauseMenuButtonSample(leftThumbstickButton: true)
        let both = PauseMenuButtonSample(leftThumbstickButton: true, rightThumbstickButton: true)
        #expect(fired(Pad.dualSense, select: true, idle, left, both, left, both)
                == [nil, nil, .thumbstickChord, nil, .thumbstickChord])
    }

    @Test("Home opens the menu on the older pad that has nothing else")
    func homeOnOlderPad() {
        #expect(fired(Pad.mfiWithHome, select: true, idle, PauseMenuButtonSample(home: true)) == [nil, .home])
    }

    @Test("Pads that pause through a handler are never sampled",
          arguments: [Pad.siriRemote, Pad.mfiBare, Pad.switchOnlineSNES])
    func handlerPadsFireNothing(pad: PauseMenuPadCapabilities) {
        let everything = PauseMenuButtonSample(options: true, menu: true, share: true, home: true,
                                               leftThumbstickButton: true, rightThumbstickButton: true)
        #expect(fired(pad, select: false, idle, everything) == [nil, nil])
    }
}

@Suite("PauseMenuNavigationRepeater")
struct PauseMenuNavigationRepeaterTests {

    /// Feeds `(held, uptime)` pairs to a fresh repeater and returns what each one fired.
    private func fired(_ steps: (Set<PauseMenuNavigationCommand>, TimeInterval)...) -> [[PauseMenuNavigationCommand]] {
        var repeater = PauseMenuNavigationRepeater()
        return steps.map { repeater.update(with: PauseMenuNavigationSample(held: $0.0), at: $0.1) }
    }

    @Test("A button held when the menu opens does nothing until pressed again")
    func heldAtOpenIsIgnored() {
        #expect(fired(([.activate], 0), ([.activate], 1), ([], 1.1), ([.activate], 1.2)) == [[], [], [], [.activate]])
    }

    @Test("A press moves once")
    func pressMovesOnce() {
        #expect(fired(([], 0), ([.down], 0.1), ([.down], 0.2), ([], 0.3)) == [[], [.down], [], []])
    }

    @Test("A held direction repeats after the delay, then at the repeat interval")
    func heldDirectionRepeats() {
        let delay = PauseMenuNavigationRepeater.initialDelay
        let interval = PauseMenuNavigationRepeater.repeatInterval
        #expect(fired(([], 0), ([.right], 1), ([.right], 1 + delay - 0.01), ([.right], 1 + delay),
                      ([.right], 1 + delay + interval - 0.01), ([.right], 1 + delay + interval))
                == [[], [.right], [], [.right], [], [.right]])
    }

    @Test("Releasing a direction resets its repeat")
    func releaseResetsRepeat() {
        let delay = PauseMenuNavigationRepeater.initialDelay
        #expect(fired(([], 0), ([.up], 1), ([], 1.1), ([.up], 1.2), ([.up], 1.2 + delay - 0.01))
                == [[], [.up], [], [.up], []])
    }

    @Test("Activate and Back never repeat")
    func buttonsDoNotRepeat() {
        #expect(fired(([], 0), ([.activate, .back], 1), ([.activate, .back], 5)) == [[], [.activate, .back], []])
    }
}
