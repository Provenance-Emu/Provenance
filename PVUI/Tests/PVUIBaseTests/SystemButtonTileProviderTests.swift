//
//  SystemButtonTileProviderTests.swift
//  PVUIBaseTests
//
//  Which Start / Select / Insert Coin tiles the pause menu shows for which
//  system and players, and what an arcade tile sends.
//

import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVUIBase

struct SystemButtonTileProviderTests {

    private typealias Slot = SystemButtonTileProvider.PlayerSlot

    /// A pad with Start and an Options button.
    private static let fullPad = Slot(hasController: true, needsMissingButtons: false)
    /// A Siri Remote, or a pad without an Options button.
    private static let limitedPad = Slot(hasController: true, needsMissingButtons: true)

    private func tileIDs(
        _ system: SystemIdentifier,
        slots: [SystemButtonTileProvider.PlayerSlot],
        missingButtonsAlwaysOn: Bool = false
    ) -> [String] {
        SystemButtonTileProvider
            .tiles(for: system, slots: slots, missingButtonsAlwaysOn: missingButtonsAlwaysOn)
            .map(\.id)
    }

    private func id(_ player: Int, _ button: String) -> String {
        SystemButtonTileProvider.tileID(player: player, buttonID: button)
    }

    // MARK: Arcade

    /// The tvOS report: a Siri Remote only, and nothing for players 3 and 4.
    @Test(arguments: [SystemIdentifier.MAME, .CPS1, .CPS2])
    func fourPlayerCabinetsShowEveryTileForFourPlayers(system: SystemIdentifier) {
        let ids = tileIDs(system, slots: [Self.limitedPad])

        var expected: [String] = []
        for player in 0..<4 {
            expected += [id(player, "start"), id(player, "select"), id(player, "coin")]
        }
        #expect(ids == expected)
    }

    /// A player who has no controller still gets tiles: nothing else can
    /// credit or start that player.
    @Test func arcadeTilesDoNotDependOnConnectedControllers() {
        #expect(tileIDs(.MAME, slots: []).count == 12)
    }

    @Test(arguments: [SystemIdentifier.MAME, .CPS1, .CPS2])
    func fourPlayerCabinetActionsWithFullPads(system: SystemIdentifier) {
        let ids = tileIDs(system, slots: Array(repeating: Self.fullPad, count: 4))
        #if os(tvOS)
        let expected = (0..<4).flatMap { player in
            [id(player, "start"), id(player, "select"), id(player, "coin")]
        }
        #expect(ids == expected)
        #else
        #expect(ids == (0..<4).map { id($0, "coin") })
        #endif
    }

    @Test func forcingMissingButtonsShowsAllTwelveArcadeTiles() {
        let slots = [Self.fullPad, Self.fullPad, Self.fullPad, Self.fullPad]

        #expect(tileIDs(.MAME, slots: slots, missingButtonsAlwaysOn: true).count == 12)
    }

    @Test func cps3StopsAtTwoPlayers() {
        let ids = tileIDs(.CPS3, slots: [])

        #expect(ids == [
            id(0, "start"), id(0, "select"), id(0, "coin"),
            id(1, "start"), id(1, "select"), id(1, "coin")
        ])
    }

    @Test func arcadeLabelsNameThePlayer() {
        let tiles = SystemButtonTileProvider.tiles(for: .MAME, slots: [Self.fullPad], missingButtonsAlwaysOn: false)

        #expect(tiles.map(\.label).allSatisfy { $0.hasPrefix("P") })
        #expect(tiles.first { $0.id == id(2, "coin") }?.label.hasPrefix("P3 ") == true)
        #expect(tiles.first { $0.id == id(3, "start") }?.label.hasPrefix("P4 ") == true)
    }

    @Test func playerSlotsPerSystem() {
        #expect(systemMenuButtonPlayerSlots(for: .MAME) == 4)
        #expect(systemMenuButtonPlayerSlots(for: .CPS1) == 4)
        #expect(systemMenuButtonPlayerSlots(for: .CPS2) == 4)
        #expect(systemMenuButtonPlayerSlots(for: .CPS3) == 2)
        #expect(systemMenuButtonPlayerSlots(for: .SNES) == nil)
        #expect(systemMenuButtonPlayerSlots(for: .NeoGeo) == nil)
    }

    // MARK: Consoles keep their rule

    @Test func consoleShowsPlayerOneOnlyWithoutASecondController() {
        #expect(tileIDs(.SNES, slots: [Self.limitedPad]) == [id(0, "start"), id(0, "select")])
    }

    @Test func consoleAddsPlayerTwoWhenItsPadLacksTheButtons() {
        let ids = tileIDs(.SNES, slots: [Self.limitedPad, Self.limitedPad, Self.limitedPad])

        #expect(ids == [id(0, "start"), id(0, "select"), id(1, "start"), id(1, "select")])
    }

    @Test func consoleShowsNothingForFullPads() {
        #expect(tileIDs(.SNES, slots: [Self.fullPad, Self.fullPad]).isEmpty)
    }

    @Test func systemsWithoutMenuButtonsShowNothing() {
        #expect(tileIDs(.Atari2600, slots: [], missingButtonsAlwaysOn: true).isEmpty)
    }

    // MARK: Tile to press

    @Test(arguments: 0..<4)
    func everyArcadeTileParsesBackToItsPlayer(player: Int) {
        for tile in SystemButtonTileProvider.tiles(for: .MAME, slots: [], missingButtonsAlwaysOn: false)
        where tile.id.hasPrefix(id(player, "")) {
            #expect(SystemButtonTileProvider.arcadePress(forTileID: tile.id)?.player == player)
        }
    }

    @Test(arguments: 0..<4)
    func arcadeTilesPressTheirButtonForTheirPlayer(player: Int) {
        let coin = SystemButtonTileProvider.arcadePress(forTileID: id(player, "coin"))
        let start = SystemButtonTileProvider.arcadePress(forTileID: id(player, "start"))
        let select = SystemButtonTileProvider.arcadePress(forTileID: id(player, "select"))

        #expect(coin?.button == .coin)
        #expect(coin?.player == player)
        #expect(start?.button == .start)
        #expect(start?.player == player)
        #expect(select?.button == .select)
        #expect(select?.player == player)
    }

    @Test func theCoinSlotIsHeldLongerThanAButton() {
        let coin = SystemButtonTileProvider.arcadePress(player: 2, buttonID: "coin")
        let start = SystemButtonTileProvider.arcadePress(player: 2, buttonID: "start")

        #expect(coin?.holdDuration == HardwareSwitchTiming.coinPressDuration)
        #expect(start?.holdDuration == HardwareSwitchTiming.pressDuration)
    }

    @Test func unknownButtonsAndPlayersPressNothing() {
        #expect(SystemButtonTileProvider.arcadePress(player: 0, buttonID: "mode") == nil)
        #expect(SystemButtonTileProvider.arcadePress(player: 4, buttonID: "coin") == nil)
        #expect(SystemButtonTileProvider.arcadePress(player: -1, buttonID: "coin") == nil)
        #expect(SystemButtonTileProvider.arcadePress(forTileID: "hardwareSwitch_reset") == nil)
    }
}
