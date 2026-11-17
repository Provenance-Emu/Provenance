//
//  ThinFDSDiskActionTests.swift
//  PVLibRetroTests
//
//  The libretro NES cores put the Famicom Disk System drive on RetroPad L and R,
//  which the NES layout cannot press. The pause menu offers the actions instead.
//  The button for each was read from the shipped dylib's input descriptors:
//  FCEUmm and Nestopia use L for the side and R for insert/eject; Mesen uses
//  R for the side and L for the next disk.
//

import Testing
import PVSystems
@testable import PVCoreBridgeRetro

struct ThinFDSDiskActionTests {

    private func actions(_ system: SystemIdentifier?, _ core: String?) -> [ThinFDSDiskAction] {
        ThinFDSDiskAction.actions(system: system, coreIdentifier: core)
    }

    // MARK: Which core gets which actions

    @Test(arguments: ["fceumm.libretro.framework", "nestopia.libretro.framework"])
    func fceummAndNestopiaTurnTheDiskWithLAndEjectWithR(core: String) {
        #expect(actions(.FDS, core) == [
            ThinFDSDiskAction(title: "Switch Disk Side", button: .l),
            ThinFDSDiskAction(title: "Insert or Eject Disk", button: .r)
        ])
    }

    @Test func mesenTurnsTheDiskWithRAndTakesTheNextDiskWithL() {
        #expect(actions(.FDS, "mesen.libretro.framework") == [
            ThinFDSDiskAction(title: "Switch Disk Side", button: .r),
            ThinFDSDiskAction(title: "Insert Next Disk", button: .l)
        ])
    }

    @Test func theSideActionComesFirstOnEveryCore() {
        for core in ["fceumm.libretro.framework", "nestopia.libretro.framework", "mesen.libretro.framework"] {
            #expect(actions(.FDS, core).first?.title == ThinFDSDiskAction.switchSideTitle, "\(core)")
        }
    }

    @Test func coreIdentifierCaseDoesNotMatter() {
        #expect(actions(.FDS, "FCEUmm.libretro.framework").count == 2)
        #expect(actions(.FDS, "Mesen.libretro.framework").first?.button == .r)
    }

    // Mesen-S is the SNES core; its name starts the same way.
    @Test func mesenSIsNotMesen() {
        #expect(actions(.FDS, "mesen-s.libretro.framework").isEmpty)
    }

    @Test func coresWhoseButtonsWereNotReadGetNothing() {
        #expect(actions(.FDS, "quicknes.libretro.framework").isEmpty)
        #expect(actions(.FDS, nil).isEmpty)
    }

    // A cartridge game has no disk drive, and L and R mean nothing to it.
    @Test func onlyDiskSystemGamesGetTheActions() {
        #expect(actions(.NES, "fceumm.libretro.framework").isEmpty)
        #expect(actions(.SNES, "mesen.libretro.framework").isEmpty)
        #expect(actions(nil, "nestopia.libretro.framework").isEmpty)
    }

    @Test func theButtonsAreTheLibretroShoulderIDs() {
        #expect(RetroJoypad.l.rawValue == 10)
        #expect(RetroJoypad.r.rawValue == 11)
    }

    // MARK: The press, counted in frames

    private func steps(of pulse: ThinButtonPulse, polls: Int) -> [ThinButtonPulse.Step] {
        var pulse = pulse
        return (0..<polls).map { _ in pulse.advance() }
    }

    @Test func aPulsePressesHoldsThenReleases() {
        let pulse = ThinButtonPulse(button: .l, heldFrames: 4)
        #expect(steps(of: pulse, polls: 5) == [.press, .hold, .hold, .hold, .release])
    }

    @Test func theDefaultPulseHoldsTheButtonForItsFrames() {
        let all = steps(of: ThinButtonPulse(button: .r), polls: ThinButtonPulse.heldFrames + 1)
        #expect(all.first == .press)
        #expect(all.last == .release)
        #expect(all.filter { $0 == .release }.count == 1)
        #expect(all.dropFirst().dropLast().allSatisfy { $0 == .hold })
    }

    @Test func aPulseIsFinishedOnlyAfterItsRelease() {
        var pulse = ThinButtonPulse(button: .l, heldFrames: 2)
        #expect(!pulse.isFinished)
        #expect(pulse.advance() == .press)
        #expect(!pulse.isFinished)
        #expect(pulse.advance() == .hold)
        #expect(!pulse.isFinished)
        #expect(pulse.advance() == .release)
        #expect(pulse.isFinished)
    }

    // The button must never be left down, whatever length is asked for.
    @Test(arguments: [1, 0, -3])
    func theShortestPulseStillPressesAndReleases(heldFrames: Int) {
        let pulse = ThinButtonPulse(button: .l, heldFrames: heldFrames)
        #expect(steps(of: pulse, polls: 2) == [.press, .release])
    }

    @Test func advancingAFinishedPulseOnlyReleasesAgain() {
        var pulse = ThinButtonPulse(button: .r, heldFrames: 1)
        _ = pulse.advance()
        _ = pulse.advance()
        #expect(pulse.advance() == .release)
        #expect(pulse.isFinished)
    }
}
