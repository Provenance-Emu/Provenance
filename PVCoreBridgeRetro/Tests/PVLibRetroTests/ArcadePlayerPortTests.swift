//
//  ArcadePlayerPortTests.swift
//  PVLibRetroTests
//
//  The pause menu's arcade tiles press Insert Coin, Start and Select for
//  players 1 to 4. Each press must reach the core on the libretro port of
//  that player and on the joypad button the arcade cores read: SELECT for the
//  coin slot, START for start. No controller is connected in these tests, as
//  for a player who only has a tile.
//

import Testing
import PVCoreBridge
@testable import PVCoreBridgeRetro

struct ArcadePlayerPortTests {

    private static let playerCount = 4

    /// What the core reads for one joypad button on one port.
    private func state(_ core: PVThinLibretroCore, port: Int, button: RetroJoypad) -> Int16 {
        core._bridge._testInputState(
            forPort: UInt32(port),
            device: UInt32(RETRO_DEVICE_JOYPAD),
            index: 0,
            id: button.rawValue
        )
    }

    @Test(arguments: 0..<4)
    func coinReachesThePlayersPortAsSelect(player: Int) {
        let core = PVThinLibretroCore()

        core.didPush(PVMAMEButton.coin, forPlayer: player)

        for port in 0..<Self.playerCount {
            #expect(state(core, port: port, button: .select) == (port == player ? 1 : 0))
            #expect(state(core, port: port, button: .start) == 0)
        }

        core.didRelease(PVMAMEButton.coin, forPlayer: player)
        #expect(state(core, port: player, button: .select) == 0)
    }

    @Test(arguments: 0..<4)
    func startReachesThePlayersPortAsStart(player: Int) {
        let core = PVThinLibretroCore()

        core.didPush(PVMAMEButton.start, forPlayer: player)

        for port in 0..<Self.playerCount {
            #expect(state(core, port: port, button: .start) == (port == player ? 1 : 0))
            #expect(state(core, port: port, button: .select) == 0)
        }

        core.didRelease(PVMAMEButton.start, forPlayer: player)
        #expect(state(core, port: player, button: .start) == 0)
    }

    @Test(arguments: 0..<4)
    func selectReachesThePlayersPortAsSelect(player: Int) {
        let core = PVThinLibretroCore()

        core.didPush(PVMAMEButton.select, forPlayer: player)
        #expect(state(core, port: player, button: .select) == 1)

        core.didRelease(PVMAMEButton.select, forPlayer: player)
        #expect(state(core, port: player, button: .select) == 0)
    }

    /// The per-frame controller poll must not drop a tile's press on a port
    /// that has no controller, or the core would never sample it.
    @Test(arguments: 0..<4)
    func aHeldPressSurvivesTheControllerPoll(player: Int) {
        let core = PVThinLibretroCore()

        core.didPush(PVMAMEButton.coin, forPlayer: player)
        core.pollControllers()
        #expect(state(core, port: player, button: .select) == 1)

        core.didRelease(PVMAMEButton.coin, forPlayer: player)
        core.pollControllers()
        #expect(state(core, port: player, button: .select) == 0)
    }

    /// The joypad bitmask query, which newer cores use in place of one call
    /// per button, carries the same bit.
    @Test func coinShowsInTheBitmaskOfThePlayersPort() {
        let core = PVThinLibretroCore()
        let lastPlayer = Self.playerCount - 1

        core.didPush(PVMAMEButton.coin, forPlayer: lastPlayer)

        let mask = core._bridge._testInputState(
            forPort: UInt32(lastPlayer),
            device: UInt32(RETRO_DEVICE_JOYPAD),
            index: 0,
            id: UInt32(RETRO_DEVICE_ID_JOYPAD_MASK)
        )
        #expect(mask == Int16(1 << RetroJoypad.select.rawValue))
    }
}
