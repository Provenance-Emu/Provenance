//
//  PVEmulatorViewController+Shaders.swift
//  PVUI
//
//  Filter selection context for the running game.
//

import Foundation
import PVShaders

extension PVEmulatorViewController {
    /// The game's MD5 for per-game filter selections (`nil` when unknown).
    var shaderGameMD5: String? {
        guard let game, !game.isInvalidated, !game.md5Hash.isEmpty else { return nil }
        return game.md5Hash
    }

    /// The system identifier for per-system filter selections.
    var shaderSystemID: String? { core.systemIdentifier }

    /// The selection in effect for this game (game, then system, then global).
    var activeShaderSelection: ShaderSelection {
        ShaderLibraryStore.shared.effectiveSelection(gameMD5: shaderGameMD5, systemID: shaderSystemID)
    }

    /// Whether a filter would show for the current layout. Dual-screen layouts (DS, 3DS
    /// skins) blit each screen separately and are never filtered.
    var filtersApplyToCurrentLayout: Bool {
        core.supportsFilters && (gpuViewController as? PVMetalViewController)?.dualScreenLayout == nil
    }

    /// Whether the current skin ships its own screen filter (offers "Skin's Filter").
    var currentSkinProvidesScreenFilter: Bool { !currentSkinScreenFilterInfos().isEmpty }

    /// Applies a changed selection: swaps the skin's own filter in or out and redraws
    /// the paused frame so the pause menu shows the new look behind it.
    func shaderSelectionDidChange() {
        applyScreenFiltersFromCurrentSkin()
        (gpuViewController as? PVMetalViewController)?.redrawPausedFrame()
    }

    /// Redraws the paused frame after a parameter edit.
    func shaderParametersDidChange() {
        (gpuViewController as? PVMetalViewController)?.redrawPausedFrame()
    }
}
