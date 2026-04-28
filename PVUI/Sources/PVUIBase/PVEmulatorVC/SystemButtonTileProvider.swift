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

    /// Builds the system-button tiles for the active system, scoped to P1
    /// and (if connected and lacking buttons) P2.
    @MainActor
    public static func tiles(
        for system: SystemIdentifier,
        controllerManager: PVControllerManager,
        missingButtonsAlwaysOn: Bool
    ) -> [PauseMenuTile] {
        let buttons = systemMenuButtons(for: system)
        guard !buttons.isEmpty else { return [] }

        let players = activePlayerIndices(
            controllerManager: controllerManager,
            missingButtonsAlwaysOn: missingButtonsAlwaysOn
        )
        guard !players.isEmpty else { return [] }

        var tiles: [PauseMenuTile] = []
        for playerIdx in players {
            let needsTiles = controllerManager.controllerNeedsMissingButtons(forPlayer: playerIdx)
            for btn in buttons {
                guard btn.alwaysShow || missingButtonsAlwaysOn || needsTiles else { continue }
                let prefix = players.count > 1 ? "P\(playerIdx + 1) " : ""
                tiles.append(PauseMenuTile(
                    id: "\(tileIDPrefix)p\(playerIdx)_\(btn.id)",
                    icon: btn.icon,
                    label: prefix + btn.label,
                    description: String(localized: "Send a momentary press to this system button."),
                    colorKey: btn.id == "coin" ? .yellow : .blue,
                    dismissOnTap: false
                ))
            }
        }
        return tiles
    }

    /// Player indices that should receive tiles. P1 is always included.
    /// P2 is included only when a P2 controller is connected AND (missing-buttons
    /// is forced on OR the P2 pad lacks the buttons).
    @MainActor
    private static func activePlayerIndices(
        controllerManager: PVControllerManager,
        missingButtonsAlwaysOn: Bool
    ) -> [Int] {
        var players: [Int] = [0]
        if controllerManager.player2 != nil &&
            (missingButtonsAlwaysOn || controllerManager.controllerNeedsMissingButtons(forPlayer: 1)) {
            players.append(1)
        }
        return players
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
