//
//  ExternalDisplayBezelRulesTests.swift
//  PVSettings
//
//  Which TV surrounds the picture on an external display, and which filter runs inside it.
//

import Testing
import Defaults
@testable import PVSettings

@Suite("ExternalDisplayBezelRules")
struct ExternalDisplayBezelRulesTests {

    private typealias Rules = ExternalDisplayBezelRules

    private let candidates: [Rules.Candidate] = [
        .init(id: "studio"),
        .init(id: "computer", preferredSystems: ["com.provenance.c64", "com.provenance.amiga"]),
        .init(id: "late-claim", preferredSystems: ["com.provenance.c64"])
    ]

    /// The catalogue with the TV Automatic falls back to.
    private var withDefault: [Rules.Candidate] { candidates + [.init(id: "living-room-tv")] }

    private func bezel(chosen: String, matches: Bool = true, system: String? = "com.provenance.snes") -> String? {
        Rules.bezelID(chosen: chosen, matchesSystem: matches, systemID: system, candidates: candidates)
    }

    @Test("The chosen TV shows for a system with no screen of its own")
    func chosen() {
        #expect(bezel(chosen: "studio") == "studio")
        #expect(bezel(chosen: "studio", system: nil) == "studio")
    }

    @Test("A system's own screen replaces the chosen TV while matching is on")
    func matchesSystem() {
        #expect(bezel(chosen: "studio", system: "com.provenance.amiga") == "computer")
        #expect(bezel(chosen: "studio", matches: false, system: "com.provenance.amiga") == "studio")
    }

    @Test("The first TV in the catalogue wins a system two of them claim")
    func firstClaimWins() {
        #expect(bezel(chosen: "studio", system: "com.provenance.c64") == "computer")
    }

    @Test("No TV chosen shows none, even for a system with a screen of its own",
          arguments: ["com.provenance.snes", "com.provenance.c64"])
    func noneChosen(system: String) {
        #expect(bezel(chosen: Rules.noBezelID, system: system) == nil)
    }

    @Test("A stored TV that no longer exists shows none")
    func unknownID() {
        #expect(bezel(chosen: "removed-in-an-update") == nil)
        #expect(bezel(chosen: "removed-in-an-update", system: "com.provenance.c64") == nil)
    }

    @Test("An empty catalogue shows none")
    func emptyCatalogue() {
        #expect(Rules.bezelID(chosen: "studio", matchesSystem: true, systemID: nil, candidates: []) == nil)
    }

    @Test("The TV's own look is used until the user picks a filter")
    func tubeFilterDefault() {
        #expect(Rules.tubeFilter(hasUserSelection: false, userSelectionIsOff: false, userSelectionIsBezel: false) == .tvOwn)
        // The flags describe a selection, so they mean nothing without one.
        #expect(Rules.tubeFilter(hasUserSelection: false, userSelectionIsOff: true, userSelectionIsBezel: true) == .tvOwn)
    }

    @Test("The user's filter runs inside the TV")
    func tubeFilterUser() {
        #expect(Rules.tubeFilter(hasUserSelection: true, userSelectionIsOff: false, userSelectionIsBezel: false) == .user)
    }

    @Test("Off, and a filter with a frame of its own, leave clean pixels behind the glass")
    func tubeFilterOff() {
        #expect(Rules.tubeFilter(hasUserSelection: true, userSelectionIsOff: true, userSelectionIsBezel: false) == .off)
        #expect(Rules.tubeFilter(hasUserSelection: true, userSelectionIsOff: false, userSelectionIsBezel: true) == .off)
    }

    // MARK: - Pins, game artwork and the player's own TVs

    private let library: [Rules.Candidate] = [
        .init(id: "studio"),
        .init(id: "computer", preferredSystems: ["com.provenance.c64"]),
        .init(id: "my-c64", preferredSystems: ["com.provenance.c64"], isUserAdded: true),
        .init(id: "my-snes", preferredSystems: ["com.provenance.snes"], isUserAdded: true),
        .init(id: "art-actraiser", isUserAdded: true)
    ]

    private func resolve(chosen: String = "studio", matches: Bool = true, system: String? = "com.provenance.nes",
                         pinned: String? = nil, gameArt: String? = nil) -> String? {
        Rules.bezelID(chosen: chosen, matchesSystem: matches, systemID: system, candidates: library,
                      pinned: pinned, gameArt: gameArt)
    }

    @Test("A pinned TV beats everything, and a pinned None shows the picture alone")
    func pinned() {
        #expect(resolve(system: "com.provenance.c64", pinned: "studio", gameArt: "art-actraiser") == "studio")
        #expect(resolve(pinned: Rules.noBezelID, gameArt: "art-actraiser") == nil)
        #expect(resolve(chosen: Rules.noBezelID, pinned: "computer") == "computer")
    }

    @Test("A pin whose TV is gone counts as no pin")
    func stalePin() {
        #expect(resolve(pinned: "deleted") == "studio")
        #expect(resolve(pinned: "deleted", gameArt: "art-actraiser") == "art-actraiser")
        #expect(resolve(chosen: Rules.noBezelID, pinned: "deleted") == nil)
    }

    @Test("Game artwork beats the system's screen and the chosen TV, and shows with no TV chosen")
    func gameArtwork() {
        #expect(resolve(system: "com.provenance.c64", gameArt: "art-actraiser") == "art-actraiser")
        #expect(resolve(chosen: Rules.noBezelID, gameArt: "art-actraiser") == "art-actraiser")
        #expect(resolve(chosen: Rules.noBezelID, matches: false, system: nil, gameArt: "art-actraiser") == "art-actraiser")
    }

    @Test("Artwork that is not on the device is ignored")
    func missingArtwork() {
        #expect(resolve(gameArt: "not-downloaded") == "studio")
        #expect(resolve(chosen: Rules.noBezelID, gameArt: "not-downloaded") == nil)
    }

    @Test("Among TVs for a system the player's own comes first")
    func ownTVFirst() {
        #expect(resolve(system: "com.provenance.c64") == "my-c64")
        #expect(resolve(system: "com.provenance.snes") == "my-snes")
        #expect(resolve(matches: false, system: "com.provenance.c64") == "studio")
        // A TV for a system still needs a TV to be chosen.
        #expect(resolve(chosen: Rules.noBezelID, system: "com.provenance.snes") == nil)
    }

    // MARK: - Automatic

    @Test("Automatic gives a console the default TV and a handheld none")
    func automaticBySystem() {
        let tv = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                               systemSuitsTV: true, candidates: withDefault)
        #expect(tv.outcome == .bezel("living-room-tv"))
        #expect(tv.isAutomatic)
        let handheld = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.gba",
                                     systemSuitsTV: false, candidates: withDefault)
        #expect(handheld.outcome == .noneForSystem)
        #expect(handheld.bezelID == nil)
    }

    @Test("Automatic prefers a TV that lists the system, whatever Match the System's Screen says")
    func automaticPrefersListingTV() {
        let resolution = Rules.resolve(chosen: "auto", matchesSystem: false, systemID: "com.provenance.c64",
                                       systemSuitsTV: true, candidates: withDefault)
        #expect(resolution.outcome == .bezel("computer"))
    }

    @Test("Automatic with no default TV in the catalogue shows nothing")
    func automaticWithoutDefault() {
        let resolution = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                                       systemSuitsTV: true, candidates: candidates)
        #expect(resolution.outcome == .noneAvailable)
    }

    @Test("A pin and game artwork still come before Automatic, and are not Automatic")
    func pinBeatsAutomatic() {
        let pinnedNone = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                                       systemSuitsTV: true, candidates: withDefault, pinned: "")
        #expect(pinnedNone.outcome == .noneChosen)
        #expect(!pinnedNone.isAutomatic)
        let pinned = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.gba",
                                   systemSuitsTV: false, candidates: withDefault, pinned: "studio")
        #expect(pinned.outcome == .bezel("studio"))
        #expect(!pinned.isAutomatic)
    }

    @Test("A stored None stays None, and a chosen TV that is gone shows nothing")
    func storedChoicesKeepTheirMeaning() {
        #expect(Rules.resolve(chosen: "", matchesSystem: true, systemID: "com.provenance.snes",
                              systemSuitsTV: true, candidates: withDefault).outcome == .noneChosen)
        #expect(Rules.resolve(chosen: "deleted-import", matchesSystem: true, systemID: "com.provenance.snes",
                              systemSuitsTV: true, candidates: withDefault).outcome == .noneAvailable)
    }

    @Test("An explicit TV ignores whether the system suits a TV")
    func explicitIgnoresSystemSuitsTV() {
        #expect(Rules.resolve(chosen: "studio", matchesSystem: true, systemID: "com.provenance.gba",
                              systemSuitsTV: false, candidates: withDefault).outcome == .bezel("studio"))
    }

    @Test("The default choice is Automatic")
    func defaultIsAutomatic() {
        #expect(Defaults.Keys.externalDisplayBezel.defaultValue == Rules.automaticBezelID)
        #expect(Rules.automaticBezelID == "auto")
        #expect(Rules.automaticDefaultBezelID == "living-room-tv")
    }

    @Test("Room light follows the device until the player sets it")
    func roomLightByDevice() {
        #expect(Rules.lightsRoom(stored: nil, gpuIsRecent: true))
        #expect(!Rules.lightsRoom(stored: nil, gpuIsRecent: false))
        #expect(Rules.lightsRoom(stored: true, gpuIsRecent: false))
        #expect(!Rules.lightsRoom(stored: false, gpuIsRecent: true))
        #expect(Defaults.Keys.externalDisplayBezelLightsRoom.defaultValue == nil)
    }
}
