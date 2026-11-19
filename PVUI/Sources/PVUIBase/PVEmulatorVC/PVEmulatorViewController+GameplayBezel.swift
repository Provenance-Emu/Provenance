//
//  PVEmulatorViewController+GameplayBezel.swift
//  PVUI
//
//  The TV around the game picture on the device itself.
//

#if os(iOS) || os(tvOS)
import Defaults
import PVPrimitives
import PVSettings
import PVShaders
import UIKit

extension PVEmulatorViewController {

    /// A choice being tried in the pause menu's switcher. It is read ahead of the saved
    /// settings and saved nowhere. `choice` is a TV's id, `ExternalDisplayBezelRules.noBezelID`
    /// for Off or `automaticBezelID`; no preview at all is a `nil` `bezelPreview`.
    struct BezelPreview: Equatable {
        var choice: String
        var lightsRoom: Bool
    }

    /// The reason given when the GPU view is sized to the whole view for a TV.
    static let tvViewportReason = "viewport-tv"

    var gameplayBezelGame: ExternalDisplayGameContext? {
        guard let game, !game.isInvalidated, let systemID = shaderSystemID else { return nil }
        let rom = (game.romPath as NSString).lastPathComponent as NSString
        return ExternalDisplayGameContext(md5: game.md5Hash, systemID: systemID, romName: rom.deletingPathExtension, title: game.title)
    }

    /// The game's system was played on a TV or monitor. From the system's `PVScreenType`,
    /// which is copied onto every core at launch.
    var systemSuitsTV: Bool { core.screenType == .crt }

    /// The TV pinned to the running game: `nil` for none pinned, `noBezelID` for no TV.
    var pinnedBezelID: String? { shaderGameMD5.flatMap { Defaults[.externalDisplayBezelByGame][$0] } }

    /// What the rules decide for the running game, for the device and an external display
    /// alike: the switcher's preview first, then the pin, game artwork and the saved choice.
    func resolvedBezel() -> (resolution: ExternalDisplayBezelRules.Resolution, bezel: TVBezel?) {
        let matchesSystem = Defaults[.externalDisplayBezelMatchesSystem]
        if let preview = bezelPreview {
            return TVBezelCatalog.resolve(chosen: preview.choice, matchesSystem: matchesSystem,
                                          systemID: shaderSystemID, systemSuitsTV: systemSuitsTV)
        }
        let gameArt = Defaults[.externalDisplayGameBezels]
            ? ExternalDisplayGameArtwork.shared.bezelID(forGame: shaderGameMD5) : nil
        return TVBezelCatalog.resolve(chosen: Defaults[.externalDisplayBezel], matchesSystem: matchesSystem,
                                      systemID: shaderSystemID, systemSuitsTV: systemSuitsTV,
                                      pinned: pinnedBezelID, gameArt: gameArt)
    }

    /// The game picture's frame in `view` coordinates while a TV shows: the part of the scene
    /// inside the tube. Pointers that map a touch or a cursor onto the game use it in place of
    /// the GPU view's frame, which then holds the whole scene. `nil` with no TV.
    var gameplayBezelPictureFrame: CGRect? {
        guard isGameplayBezelShowing, let metalVC = gpuViewController as? PVMetalViewController,
              let picture = metalVC.localBezelPictureFrame() else { return nil }
        return metalVC.view.convert(picture, to: view)
    }

    /// Whether the picture lights the room: the switcher's preview first, then the setting.
    var bezelLightsRoom: Bool { bezelPreview?.lightsRoom ?? TVBezelRoomLight.isOn }

    /// What `GameplayBezelPlacement` needs to know about the game as it is being played now.
    func bezelPlacementInputs(choiceIsAutomatic: Bool) -> GameplayBezelPlacement.Inputs {
        let presentsFrames = filtersApplyToCurrentLayout && hostGPUViewDrawsGame
            && (gpuViewController as? PVMetalViewController)?.presentsCoreFrames == true
        #if os(tvOS)
        return .init(isAppleTV: true, isLandscape: true, controls: .bare, layoutSupportsTV: presentsFrames,
                     choiceIsAutomatic: choiceIsAutomatic, droppedForSession: gameplayBezelDropped)
        #else
        // The light gun's touch layer aims against the GPU view's own frame and cannot follow
        // the tube, so a TV steps aside while it is up.
        let layoutSupportsTV = presentsFrames && !isLightGunVisible
        let controls: GameplayBezelPlacement.Controls
        if controllerHidesOnScreenControls {
            controls = .hiddenByController
        } else if isProgrammaticOverlayActive {
            controls = .generated
        } else {
            // A skin is on screen, or one is still on its way: wait for it rather than flash a TV.
            controls = isDeltaSkinEnabled ? .skin : .bare
        }
        let size = view.bounds.size
        let isLandscape = size.width > 0 && size.height > 0 ? size.width > size.height : currentOrientation == .landscape
        return .init(isAppleTV: false, isLandscape: isLandscape, controls: controls,
                     layoutSupportsTV: layoutSupportsTV, choiceIsAutomatic: choiceIsAutomatic,
                     editingLayout: isOverlayLayoutEditing, droppedForSession: gameplayBezelDropped)
        #endif
    }

    /// Whether the pause menu offers the TV switcher for the game as it is being played now.
    var offersBezelSwitcher: Bool {
        GameplayBezelPlacement.offersSwitcher(bezelPlacementInputs(choiceIsAutomatic: false))
    }

    /// Brings the device and an external display in line with the TV choice.
    func refreshBezels() {
        updateGameplayBezel()
        #if os(iOS)
        updateExternalDisplay()
        #endif
    }

    /// Shows, changes or removes the TV around the picture on the device. Cheap and safe to
    /// call whenever the choice, the controls, the window's shape or the layout may have changed.
    func updateGameplayBezel() {
        guard let renderer = gpuViewController as? PVMetalViewController else { return }
        let resolved = resolvedBezel()
        let placement = bezelPlacementInputs(choiceIsAutomatic: resolved.resolution.isAutomatic)
        let bezel = GameplayBezelPlacement.showsTV(placement) ? resolved.bezel : nil
        let store = ShaderLibraryStore.shared
        let selected = store.resolvedShader(gameMD5: shaderGameMD5, systemID: shaderSystemID, screenType: core.screenType)
        var tubeFilter: ResolvedShader?
        if let bezel, bezel.presetID == nil {
            if let selected, !TVBezelShader.isBezelFilter(selected.entry) {
                if bezel.image == nil {
                    let values = selected.values.merging(TVBezelShader.curvatureOffValues(for: selected.entry)) { _, off in off }
                    tubeFilter = ResolvedShader(entry: selected.entry, values: values, revision: selected.revision)
                } else {
                    tubeFilter = selected
                }
            } else if let look = bezel.look, let entry = ShaderCatalog.shared.entry(for: look.shaderID) {
                let values = look.values.merging(TVBezelShader.curvatureOffValues(for: entry)) { _, off in off }
                tubeFilter = ResolvedShader(entry: entry, values: values, revision: bezel.id.hashValue)
            }
        }
        renderer.updateLocalBezel(bezel, filter: tubeFilter, lightsRoom: bezelLightsRoom,
                                  flatGlass: tubeFilter.map { TVBezelShader.bendsPictureItself($0.entry) } ?? false)
        setGameplayBezelShowing(bezel != nil)

        // Artwork made for this game: looked for once per session and style, never while previewing.
        guard bezelPreview == nil, GameplayBezelPlacement.offersSwitcher(placement),
              Defaults[.externalDisplayGameBezels], pinnedBezelID == nil, let context = gameplayBezelGame else { return }
        let artwork = ExternalDisplayGameArtwork.shared
        let style = Defaults[.externalDisplayBezelProjectStyle]
        guard artwork.begin(game: context.md5, style: style) else { return }
        Task { @MainActor [weak self] in
            let downloaded = await BezelProjectService.shared.artwork(for: context, style: style)
            guard let downloaded, artwork.finish(game: context.md5, style: style, bezelID: downloaded.id) else { return }
            self?.refreshBezels()
        }
    }

    /// The GPU could not draw the TV on the device: none is shown again this game. A second
    /// try risks another GPU restart, after which the system refuses every frame.
    func gameplayBezelWasDropped() {
        guard !gameplayBezelDropped else { return }
        gameplayBezelDropped = true
        updateGameplayBezel()
    }

    /// While a TV shows, the GPU view fills the emulator view so the cabinet and room sit
    /// behind the controls and the picture goes in the tube; without one it goes back to the
    /// rect the controls or the skin publish. tvOS keeps its own layout.
    private func setGameplayBezelShowing(_ showing: Bool) {
        guard showing != isGameplayBezelShowing else { return }
        isGameplayBezelShowing = showing
        #if os(iOS)
        if showing {
            applyFrameToGPUView(view.bounds, reason: Self.tvViewportReason, force: true)
        } else if !isProgrammaticOverlayActive, let frame = currentTargetFrame {
            // A skin's frame is still the one it last published, so its next broadcast would be
            // dropped as unchanged: put the picture back in it now.
            applyFrameToGPUView(frame, reason: "viewport-tv-removed", force: true)
        } else {
            applyViewportFromCurrentSkin()
        }
        refreshVirtualMouseLayout()
        #endif
    }
}
#endif
