//
//  GameplayBezelPlacementTests.swift
//  PVSettings
//
//  Whether the device may draw a TV around the game.
//

import Testing
@testable import PVSettings

@Suite("GameplayBezelPlacement")
struct GameplayBezelPlacementTests {

    typealias Placement = GameplayBezelPlacement

    @Test("The placement table", arguments: [
        // Apple TV, landscape, controls, the choice is Automatic, a TV shows
        (true, true, Placement.Controls.bare, true, true),
        (false, true, .hiddenByController, true, true),
        (false, true, .generated, true, true),
        (false, true, .bare, true, true),
        (false, true, .skin, false, false),
        (false, false, .hiddenByController, false, true),   // an explicit TV, as before
        (false, false, .hiddenByController, true, false),   // Automatic never in portrait
        (false, false, .generated, false, false),
        (false, false, .skin, false, false)
    ])
    func table(appleTV: Bool, landscape: Bool, controls: Placement.Controls, automatic: Bool, expected: Bool) {
        let inputs = Placement.Inputs(isAppleTV: appleTV, isLandscape: landscape, controls: controls,
                                      layoutSupportsTV: true, choiceIsAutomatic: automatic)
        #expect(Placement.showsTV(inputs) == expected)
    }

    @Test("No TV when the layout cannot take one, or while the layout editor is open")
    func guards() {
        #expect(!Placement.showsTV(.init(isAppleTV: true, isLandscape: true, controls: .bare,
                                         layoutSupportsTV: false, choiceIsAutomatic: false)))
        #expect(!Placement.showsTV(.init(isAppleTV: false, isLandscape: true, controls: .generated,
                                         layoutSupportsTV: true, choiceIsAutomatic: false, editingLayout: true)))
    }

    @Test("A TV the GPU could not draw stays off for the rest of the game, and the switcher with it")
    func droppedForSession() {
        let inputs = Placement.Inputs(isAppleTV: false, isLandscape: true, controls: .generated,
                                      layoutSupportsTV: true, choiceIsAutomatic: false, droppedForSession: true)
        #expect(!Placement.showsTV(inputs))
        #expect(!Placement.offersSwitcher(inputs))
        #expect(!Placement.showsTV(.init(isAppleTV: true, isLandscape: true, controls: .bare,
                                         layoutSupportsTV: true, choiceIsAutomatic: false, droppedForSession: true)))
    }

    @Test("The switcher is offered wherever an explicit TV could show, and nowhere else")
    func switcher() {
        #expect(Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: true, controls: .generated,
                                               layoutSupportsTV: true, choiceIsAutomatic: true)))
        #expect(Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: false, controls: .hiddenByController,
                                               layoutSupportsTV: true, choiceIsAutomatic: true)))
        #expect(!Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: false, controls: .generated,
                                                layoutSupportsTV: true, choiceIsAutomatic: false)))
        #expect(!Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: true, controls: .skin,
                                                layoutSupportsTV: true, choiceIsAutomatic: false)))
    }
}
