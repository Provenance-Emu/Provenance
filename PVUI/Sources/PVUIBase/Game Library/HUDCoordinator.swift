//
//  HUDCoordinator.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/1/24.
//

import Foundation
import PVLogging

/// Coordinates HUD state updates
public actor HUDCoordinator {
    private var hudState: HudState = .hidden
    private var isHidingHUD = false
    private var hideTask: Task<Void, Never>?

    /// Updates the HUD state and manages visibility
    func updateHUD(_ newState: HudState, autoHide: Bool = false) async {
        DLOG("Updating HUD state to: \(newState)")

        if isHidingHUD {
            DLOG("HUD is currently hiding, skipping update")
            return
        }

        hudState = newState

        if autoHide {
            hideTask?.cancel()
            isHidingHUD = true
            hideTask = createHideTask()
        }
    }

    /// Creates a task to hide the HUD after a delay
    private func createHideTask() -> Task<Void, Never> {
        Task.detached { [weak self] in
            DLOG("Starting HUD hide delay")
            do {
                try await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    DLOG("Hiding HUD after delay")
                    await self?.hideHUD()
                }
            } catch {
                DLOG("Error during hide delay: \(error)")
                await self?.hideHUD()
            }
        }
    }

    /// Hides the HUD and resets state
    private func hideHUD() async {
        hudState = .hidden
        isHidingHUD = false
        hideTask?.cancel()
        hideTask = nil
        DLOG("HUD hidden and state reset")
    }

    /// Gets the current HUD state
    func getCurrentState() -> HudState {
        hudState
    }
}
