//
//  SystemButtonTileProvider.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/27/26.
//
//  Builds pause-menu tiles for system-specific buttons (Start/Select/Coin/etc.)
//  when the active controller lacks them — most commonly the tvOS Siri Remote.
//

import Foundation
import PVCoreBridge
import PVPrimitives

/// Generates `[PauseMenuTile]` for buttons that the connected controller
/// can't reach (Siri Remote, older BT pads), plus arcade Coin tiles which
/// always show regardless of controller capability.
public struct SystemButtonTileProvider {

    /// Stable prefix used by tile IDs so the dispatcher in
    /// `PauseTileMenuView` can route taps to the right responder client.
    public static let tileIDPrefix = "systemButton_"

    /// Player slots the pause menu can address (P1 to P4).
    public static let maxPlayers = 4

    /// What the tile list needs to know about one player slot.
    public struct PlayerSlot: Equatable, Sendable {
        /// A controller is assigned to this slot.
        public let hasController: Bool
        /// The slot cannot reach Start/Select itself: no controller, a Siri
        /// Remote, or a pad without an Options button.
        public let needsMissingButtons: Bool

        public init(hasController: Bool, needsMissingButtons: Bool) {
            self.hasController = hasController
            self.needsMissingButtons = needsMissingButtons
        }

        /// A slot nobody is plugged into.
        public static let empty = PlayerSlot(hasController: false, needsMissingButtons: true)
    }

    /// Builds the system-button tiles for the active system from the
    /// connected controllers.
    @MainActor
    public static func tiles(
        for system: SystemIdentifier,
        controllerManager: PVControllerManager,
        missingButtonsAlwaysOn: Bool
    ) -> [PauseMenuTile] {
        let controllers = [
            controllerManager.player1, controllerManager.player2,
            controllerManager.player3, controllerManager.player4
        ]
        let slots = controllers.enumerated().map { index, controller in
            PlayerSlot(
                hasController: controller != nil,
                needsMissingButtons: controllerManager.controllerNeedsMissingButtons(forPlayer: index)
            )
        }
        return tiles(for: system, slots: slots, missingButtonsAlwaysOn: missingButtonsAlwaysOn)
    }

    /// Builds the system-button tiles for the active system.
    ///
    /// `slots` is indexed by player (0 is P1); slots past its end count as
    /// empty. A button shows for a player when it is always shown (Insert
    /// Coin), when missing buttons are forced on, or when that player's slot
    /// cannot reach it.
    public static func tiles(
        for system: SystemIdentifier,
        slots: [PlayerSlot],
        missingButtonsAlwaysOn: Bool
    ) -> [PauseMenuTile] {
        let buttons = systemMenuButtons(for: system)
        guard !buttons.isEmpty else { return [] }

        let players = playerIndices(for: system, slots: slots, missingButtonsAlwaysOn: missingButtonsAlwaysOn)

        var tiles: [PauseMenuTile] = []
        for playerIdx in players {
            let needsTiles = slot(playerIdx, in: slots).needsMissingButtons
            for btn in buttons {
                guard btn.alwaysShow || missingButtonsAlwaysOn || needsTiles else { continue }
                let prefix = players.count > 1 ? "P\(playerIdx + 1) " : ""
                tiles.append(PauseMenuTile(
                    id: tileID(player: playerIdx, buttonID: btn.id),
                    icon: btn.icon,
                    label: prefix + btn.label,
                    description: String(localized: "Send a momentary press to this system button."),
                    colorKey: btn.id == coinButtonID ? .yellow : .blue,
                    dismissOnTap: false
                ))
            }
        }
        return tiles
    }

    /// The tile ID for a player's button: `systemButton_pN_<btn>`.
    public static func tileID(player: Int, buttonID: String) -> String {
        "\(tileIDPrefix)p\(player)_\(buttonID)"
    }

    /// Player indices that get tiles.
    ///
    /// A coin-op system gives every slot of its cabinet tiles (see
    /// `systemMenuButtonPlayerSlots(for:)`). Elsewhere P1 is always included,
    /// and P2 only when a P2 controller is connected AND (missing-buttons is
    /// forced on OR the P2 pad lacks the buttons).
    static func playerIndices(
        for system: SystemIdentifier,
        slots: [PlayerSlot],
        missingButtonsAlwaysOn: Bool
    ) -> [Int] {
        if let cabinetSlots = systemMenuButtonPlayerSlots(for: system) {
            return Array(0..<min(cabinetSlots, maxPlayers))
        }
        var players: [Int] = [0]
        let player2 = slot(1, in: slots)
        if player2.hasController && (missingButtonsAlwaysOn || player2.needsMissingButtons) {
            players.append(1)
        }
        return players
    }

    private static func slot(_ player: Int, in slots: [PlayerSlot]) -> PlayerSlot {
        slots.indices.contains(player) ? slots[player] : .empty
    }

    // MARK: - Arcade presses

    static let startButtonID = "start"
    static let selectButtonID = "select"
    static let coinButtonID = "coin"

    /// What an arcade (MAME / FBNeo / CPS) tile sends to the core.
    public struct ArcadePress: Equatable {
        public let button: PVMAMEButton
        /// 0 is P1; the core reads it on the libretro port of the same number.
        public let player: Int
        /// Press-to-release delay.
        public let holdDuration: TimeInterval
    }

    /// The press an arcade tile stands for, or `nil` when the tile is not a
    /// system-button tile, names a button arcade systems lack, or names a
    /// player past `maxPlayers`.
    public static func arcadePress(forTileID tileID: String) -> ArcadePress? {
        guard let parsed = parse(tileID: tileID) else { return nil }
        return arcadePress(player: parsed.player, buttonID: parsed.buttonId)
    }

    /// See `arcadePress(forTileID:)`.
    public static func arcadePress(player: Int, buttonID: String) -> ArcadePress? {
        guard (0..<maxPlayers).contains(player) else { return nil }
        switch buttonID {
        case startButtonID:
            return ArcadePress(button: .start, player: player, holdDuration: HardwareSwitchTiming.pressDuration)
        case selectButtonID:
            return ArcadePress(button: .select, player: player, holdDuration: HardwareSwitchTiming.pressDuration)
        case coinButtonID:
            // The coin slot needs a longer press than the other buttons to register.
            return ArcadePress(button: .coin, player: player, holdDuration: HardwareSwitchTiming.coinPressDuration)
        default:
            return nil
        }
    }

    /// Parses a tile ID of the form `systemButton_pN_<btn>` into its
    /// `(player, buttonId)` components.
    public static func parse(tileID: String) -> (player: Int, buttonId: String)? {
        guard tileID.hasPrefix(tileIDPrefix) else { return nil }
        let rest = tileID.dropFirst(tileIDPrefix.count)
        guard rest.first == "p" else { return nil }
        let afterP = rest.dropFirst()
        let parts = afterP.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let player = Int(parts[0]) else { return nil }
        return (player, String(parts[1]))
    }
}
