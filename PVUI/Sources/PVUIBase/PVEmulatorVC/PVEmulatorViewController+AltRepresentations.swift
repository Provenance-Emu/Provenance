// PVEmulatorViewController+AltRepresentations.swift
// PVUI
//
// Ignited's `altRepresentations`: a skin can carry a second layout set that its
// `toggleAltRepresentations` button switches to during play (5 DS skins in the catalog).
//
// The choice is persisted per game and skin by SkinKitManager (same scope as the game's
// skin pick) and read back into `DeltaSkinTraits.usesAltRepresentations` by every place
// that builds skin traits: `skinRenderTraits()` (dual-screen / Metal layout) and
// `EmulatorWithSkinView.createSkinTraits()` (the SwiftUI skin). Both read the same stored
// value, so the drawn skin and the game viewport never use different sets.

import UIKit
import PVLibrary
import PVLogging
import SkinKitCore
import SkinKitManager
import SkinKitUI

extension PVEmulatorViewController {

    /// Every key the game's skin pick may be stored under (pickers write `PVGame.id`; rotation read md5 and crc).
    var altRepresentationsGameKeys: [String] {
        guard let game else { return [] }
        return [game.id, game.md5Hash, game.crc].filter { !$0.isEmpty }
    }

    /// Whether `skin`'s alternate layout is on for this game. `false` for a skin without `altRepresentations`.
    func usesAltRepresentations(for skin: (any DeltaSkinProtocol)?) -> Bool {
        guard let skin, skin.hasAltRepresentations else { return false }
        return DeltaSkinSelectionManager.shared.usesAltRepresentations(skinIdentifier: skin.identifier,
                                                                       gameIds: altRepresentationsGameKeys)
    }

    /// Routes the skin's `toggleAltRepresentations` button to this controller.
    func installAltRepresentationsToggle(on inputHandler: DeltaSkinInputHandler) {
        inputHandler.altRepresentationsToggleHandler = { [weak self] in
            Task { @MainActor in self?.toggleAltRepresentations() }
        }
    }

    /// Flips and persists the alternate layout for the current skin and game, then re-runs the layout.
    ///
    /// `DeltaSkinSelectionManager` posts `altRepresentationsChangedNotification`; `EmulatorWithSkinView`
    /// rebuilds its traits from it, and SkinKitUI's `DeltaSkinView` reloads its artwork, buttons and screens on
    /// the trait change. This controller re-runs the viewport from the active set's `screens`.
    @MainActor
    func toggleAltRepresentations() {
        guard let skin = currentSkin, skin.hasAltRepresentations else {
            DLOG("skins: toggleAltRepresentations ignored: the current skin has no altRepresentations")
            return
        }
        let keys = altRepresentationsGameKeys
        guard !keys.isEmpty else { return }
        let nowAlt = DeltaSkinSelectionManager.shared.toggleAltRepresentations(skinIdentifier: skin.identifier, gameIds: keys)
        ILOG("skins: altRepresentations \(nowAlt ? "on" : "off") for \(skin.identifier)")
        relayoutForAltRepresentations()
    }

    /// Re-runs the game viewport for the active layout set: the DS/3DS dual-screen split (Metal or core-side),
    /// the single-screen viewport otherwise, and the GPU view on a dedicated external display.
    @MainActor
    func relayoutForAltRepresentations() {
        // Frames reported by the skin view belong to the old set; the reloaded view reports new ones.
        clearReceivedScreenFrames()
        lastAppliedViewportFrame = nil

        // Dedicated external display: the GPU view is that window's root view and keeps filling it. The
        // device-sized skin geometry below does not apply to it and would pull the view back under the skin.
        if let externalView = secondaryWindow?.rootViewController?.view {
            externalView.setNeedsLayout()
            externalView.layoutIfNeeded()
            return
        }

        applyDualScreenViewport()   // falls back to applyViewportFromCurrentSkin() for single-screen cores

        // The SwiftUI skin re-renders asynchronously; run the layout again once its new screens have settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.secondaryWindow == nil else { return }
            self.lastAppliedViewportFrame = nil
            self.applyDualScreenViewport()
            NotificationCenter.default.post(name: .deltaSkinForceRecalculate, object: nil)
        }
    }
}
