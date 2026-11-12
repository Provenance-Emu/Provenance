//
//  ExternalDisplayBezelRulesTests.swift
//  PVSettings
//
//  Which TV surrounds the picture on an external display, and which filter runs inside it.
//

import Testing
@testable import PVSettings

@Suite("ExternalDisplayBezelRules")
struct ExternalDisplayBezelRulesTests {

    private typealias Rules = ExternalDisplayBezelRules

    private let candidates: [Rules.Candidate] = [
        .init(id: "studio"),
        .init(id: "computer", preferredSystems: ["com.provenance.c64", "com.provenance.amiga"]),
        .init(id: "late-claim", preferredSystems: ["com.provenance.c64"])
    ]

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
}
