//
//  HardwareSwitchLatchTests.swift
//  PVUI
//

import PVCoreBridge
import Testing
@testable import PVUIBase

@Suite("HardwareSwitchTokens")
struct HardwareSwitchTokensTests {

    @Test("Colour tokens stay distinct from black-and-white tokens",
          arguments: [
              ("color", "color"), ("clr", "color"), ("colour", "color"),
              ("colorbw", "colorbw"), ("bw", "colorbw"), ("blackwhite", "colorbw"),
              ("COLOR", "color"), (" bw ", "colorbw")
          ])
    func tvTypeTokens(token: String, expected: String) {
        #expect(HardwareSwitchTokens.canonicalTVType(token) == expected)
    }

    @Test("Unrelated and single-token ids are left to the caller",
          arguments: ["tvtype", "fire", "leftdiffa", ""])
    func unrelatedTokens(token: String) {
        #expect(HardwareSwitchTokens.canonicalTVType(token) == nil)
    }
}

@Suite("HardwareSwitchLatch")
struct HardwareSwitchLatchTests {

    private func latch2600() -> HardwareSwitchLatch {
        HardwareSwitchLatch(descriptors: PV2600Button.hardwareSwitches ?? [])
    }

    /// `resolve` is mutating, so drive it from a helper rather than inside `#expect`.
    private func presses(_ latch: inout HardwareSwitchLatch, _ tokens: [String]) -> [String?] {
        tokens.map { latch.resolve($0, isPressed: true) }
    }

    @Test("Single-token TV type alternates, starting from the colour default")
    func tvTypeAlternates() {
        var latch = latch2600()
        #expect(presses(&latch, ["tvtype", "tvtype", "tvtype"]) == ["colorbw", "color", "colorbw"])
    }

    @Test("Difficulty tokens start at B and flip to A",
          arguments: [
              ("leftdifficulty", ["leftdiffa", "leftdiffb"]),
              ("leftdiff", ["leftdiffa", "leftdiffb"]),
              ("rightdifficulty", ["rightdiffa", "rightdiffb"])
          ])
    func difficultyAlternates(token: String, expected: [String]) {
        var latch = latch2600()
        #expect(presses(&latch, [token, token]) == expected)
    }

    @Test("Switches latch independently")
    func independentSwitches() {
        var latch = latch2600()
        let out = presses(&latch, ["leftdifficulty", "tvtype", "leftdifficulty", "rightdifficulty"])
        #expect(out == ["leftdiffa", "colorbw", "leftdiffb", "rightdiffa"])
    }

    @Test("Release repeats whatever the matching press emitted")
    func releaseMatchesPress() {
        var latch = latch2600()
        let down = latch.resolve("tvtype", isPressed: true)
        let up = latch.resolve("tvtype", isPressed: false)
        #expect(down == "colorbw")
        #expect(up == "colorbw")
        let down2 = latch.resolve("tvtype", isPressed: true)
        let up2 = latch.resolve("tvtype", isPressed: false)
        #expect(down2 == "color")
        #expect(up2 == "color")
    }

    @Test("A release with no press is dropped")
    func strayRelease() {
        var latch = latch2600()
        #expect(latch.resolve("tvtype", isPressed: false) == nil)
    }

    @Test("Two-token ids pass through unchanged and keep the latch in step")
    func explicitPositionsSyncState() {
        var latch = latch2600()
        // Skin explicitly selects A; a following single-token press must go back to B.
        #expect(latch.resolve("leftdiffa", isPressed: true) == "leftdiffa")
        #expect(latch.resolve("leftdiffa", isPressed: false) == "leftdiffa")
        #expect(latch.resolve("leftdifficulty", isPressed: true) == "leftdiffb")
    }

    @Test("Explicit B&W then a single-token press switches back to colour")
    func explicitTVTypeSyncState() {
        var latch = latch2600()
        #expect(latch.resolve("colorbw", isPressed: true) == "colorbw")
        #expect(latch.resolve("tvtype", isPressed: true) == "color")
    }

    @Test("Other buttons are untouched", arguments: ["fire1", "up", "reset", "select"])
    func otherButtons(token: String) {
        var latch = latch2600()
        #expect(latch.resolve(token, isPressed: true) == token)
        #expect(latch.resolve(token, isPressed: false) == token)
    }

    @Test("Press-to-toggle switches (7800 difficulty) send their one id every press")
    func pressToToggleSwitches() {
        var latch = HardwareSwitchLatch(descriptors: PV7800Button.hardwareSwitches ?? [])
        #expect(presses(&latch, ["leftdiff", "leftdiff"]) == ["leftdiff", "leftdiff"])
        #expect(latch.resolve("leftdiff", isPressed: false) == "leftdiff")
    }

    @Test("A system with no switches passes everything through")
    func noSwitches() {
        var latch = HardwareSwitchLatch(descriptors: [])
        #expect(latch.resolve("tvtype", isPressed: true) == "tvtype")
    }
}

@Suite("HardwareSwitchDescriptor audit")
struct HardwareSwitchDescriptorTests {

    @Test("2600 positions are distinct, so the UI can say which one it wants")
    func atari2600HasDistinctPositions() {
        let switches = PV2600Button.hardwareSwitches ?? []
        #expect(switches.count == 3)
        #expect(switches.allSatisfy { !$0.isPressToToggle })
    }

    @Test("Descriptors whose positions share an id are press-to-toggle")
    func sharedIdsAreToggles() {
        // Built up step by step: a single `+` chain over optionals makes the
        // type checker time out on CI's compiler.
        var all: [HardwareSwitchDescriptor] = []
        all += PV7800Button.hardwareSwitches ?? []
        all += PV5200Button.hardwareSwitches ?? []
        all += PVMSXButton.hardwareSwitches ?? []
        all += PVA8Button.hardwareSwitches ?? []
        all += PVPCEButton.hardwareSwitches ?? []
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { $0.isPressToToggle })
    }

    @Test("The two 2600 position ids both parse to distinct buttons")
    func tvTypePositionsParse() throws {
        let tv = try #require(PV2600Button.hardwareSwitches?.first { $0.id == "color_bw" })
        #expect(PV2600Button(tv.positions.on.buttonId) == .color)
        #expect(PV2600Button(tv.positions.off.buttonId) == .colorBW)
    }
}
