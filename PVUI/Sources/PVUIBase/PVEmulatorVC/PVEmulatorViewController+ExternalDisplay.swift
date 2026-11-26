//
//  PVEmulatorViewController+ExternalDisplay.swift
//  PVUI
//
//  The game picture on an external display (cabled or AirPlay).
//

#if os(iOS)
import UIKit
import Defaults
import PVLogging
import PVSettings
import PVShaders
import SkinKitBezels
import SkinKitCore
import SkinKitUI

extension PVEmulatorViewController {

    /// Whether the core hands its frames to the Metal presenter, which can then draw them on a
    /// second screen. Cores that draw into a view of their own (Dolphin, Azahar, native PPSSPP)
    /// do not, and are mirrored by the system instead.
    var coreCanPresentExternally: Bool {
        core.supportsExternalDisplay && hostGPUViewDrawsGame
            && (gpuViewController as? PVMetalViewController)?.presentsCoreFrames == true
    }

    /// What each screen shows right now, from the settings and how the game is being played.
    var externalDisplayPlan: ExternalDisplayPlan {
        ExternalDisplayPlan(.init(
            mode: Defaults[.externalDisplayMode],
            externalDisplayConnected: ExternalDisplayCoordinator.shared.isConnected,
            coreCanPresentExternally: coreCanPresentExternally,
            hardwareControllerConnected: PVControllerManager.shared.hasControllers,
            deviceSkin: externalDisplayDeviceSkin,
            devicePicture: Defaults[.externalDisplayDevicePicture],
            externalSkin: Defaults[.externalDisplaySkin],
            bezelChosen: externalDisplayBezel != nil))
    }

    /// The TV set to surround this game's picture on an external display, from the settings
    /// and the game's system. `nil` for none, and for layouts a TV cannot frame (two screens).
    var externalDisplayBezel: TVBezel? {
        guard filtersApplyToCurrentLayout else { return nil }
        return resolvedBezel().bezel
    }

    /// The running game as the bezel options and The Bezel Project's lists know it.
    var externalDisplayGameContext: ExternalDisplayGameContext? {
        guard let game, !game.isInvalidated, let systemID = shaderSystemID else { return nil }
        let romName = ((game.romPath as NSString).lastPathComponent as NSString).deletingPathExtension
        return ExternalDisplayGameContext(md5: game.md5Hash, systemID: systemID, romName: romName, title: game.title)
    }

    /// Looks for artwork made for this game once per session and style, downloading it the
    /// first time. Nothing is said when it fails: the chosen TV keeps showing.
    private func findExternalDisplayGameArt() {
        guard Defaults[.externalDisplayGameBezels], filtersApplyToCurrentLayout,
              let context = externalDisplayGameContext else { return }
        let style = Defaults[.externalDisplayBezelProjectStyle]
        let found = ExternalDisplayGameArtwork.shared
        guard found.begin(game: context.md5, style: style) else { return }
        Task { @MainActor [weak self] in
            let bezel = await BezelProjectService.shared.artwork(for: context, style: style)
            guard let bezel, found.finish(game: context.md5, style: style, bezelID: bezel.id) else { return }
            self?.updateExternalDisplay()
        }
    }

    @objc private func bezelLibraryDidChange() {
        // A pinned or chosen bezel may have arrived or gone.
        refreshBezels()
    }

    /// What supplies the controls on the device: the generated touch controls, a skin that
    /// ships with the app, or one the user installed.
    private var externalDisplayDeviceSkin: ExternalDisplayPlan.DeviceSkin {
        guard isDeltaSkinEnabled, let skin = currentSkin, !isProgrammaticOverlayActive else { return .generatedControls }
        return skin.isCaseControllerSkin ? .builtIn : .real
    }

    /// Whether the external display is showing the game picture on its own right now.
    var isGameOnExternalDisplay: Bool { externalDisplayWindow != nil }

    /// A display is attached, whether or not it is showing the game picture. In Mirror Device
    /// mode on iOS 27 the app holds no scene for it, so the accessory is asked instead.
    var isExternalDisplayAttached: Bool {
        if ExternalDisplayCoordinator.shared.isConnected { return true }
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), let registration = externalDisplayAccessory as? UISceneAccessoryRegistration {
            return registration.isAvailable
        }
        #endif
        return false
    }

    /// Asks the system for the external display's scene.
    ///
    /// An app built with the iOS 27 SDK is no longer handed that scene when a display connects:
    /// it gets one only while a view controller has an external-display scene accessory
    /// registered. Without this the display is always a mirror and
    /// `ExternalDisplayCoordinator` never hears about it. Earlier systems still connect the
    /// scene by themselves (`PVSystemEvents.application(_:configurationForConnecting:options:)`).
    private func registerExternalDisplayAccessory() {
        #if compiler(>=6.4)
        guard #available(iOS 27.0, *), externalDisplayAccessory == nil else { return }
        let configuration = UISceneConfiguration(name: nil, sessionRole: .windowExternalDisplayNonInteractive)
        configuration.delegateClass = PVExternalDisplaySceneDelegate.self
        let registration = registerSceneAccessory(.externalNonInteractive(sceneConfiguration: configuration))
        // Off until `updateExternalDisplay` knows the game goes there: a scene with no window
        // must not take the display away from mirroring.
        registration.isEnabled = false
        externalDisplayAccessory = registration
        ILOG("External display: scene accessory registered")
        #endif
    }

    func unregisterExternalDisplayAccessory() {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), let registration = externalDisplayAccessory as? UISceneAccessoryRegistration {
            unregisterSceneAccessory(registration)
        }
        #endif
        externalDisplayAccessory = nil
    }

    /// Takes the external display's scene only while the game picture is meant to go there;
    /// otherwise the system mirrors the device.
    private func updateExternalDisplayAccessory() {
        #if compiler(>=6.4)
        guard #available(iOS 27.0, *),
              let registration = externalDisplayAccessory as? UISceneAccessoryRegistration else { return }
        let wanted = Defaults[.externalDisplayMode] == .dedicated && coreCanPresentExternally
        guard registration.isEnabled != wanted else { return }
        registration.isEnabled = wanted
        ILOG("External display: scene accessory \(wanted ? "enabled" : "disabled")")
        #endif
    }

    func observeExternalDisplay() {
        registerExternalDisplayAccessory()
        NotificationCenter.default.addObserver(self, selector: #selector(externalDisplayInputsDidChange),
                                               name: ExternalDisplayCoordinator.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(externalDisplayFilterDidChange),
                                               name: ShaderLibraryStore.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bezelLibraryDidChange),
                                               name: TVBezelLibrary.didChangeNotification, object: nil)
        ProvenanceBezels.configure()
        TVBezelLibrary.shared.refreshIfNeeded()
        externalDisplaySettingsObservation = Task { @MainActor [weak self] in
            for await _ in Defaults.updates([.externalDisplayMode, .externalDisplayDevicePicture, .externalDisplaySkin,
                                             .externalDisplayBezel, .externalDisplayBezelMatchesSystem,
                                             .externalDisplayBezelLightsRoom, .externalDisplayBezelSeat,
                                             .externalDisplayGameBezels,
                                             .externalDisplayBezelProjectStyle, .externalDisplayBezelByGame,
                                             .imageSmoothingMode, .hideOnScreenControlsWithController],
                                            initial: false) {
                // The controls switch sits with the display options, and is otherwise read only
                // when a controller connects.
                self?.updateOnScreenControlsVisibility()
                self?.updateGameplayBezel()
                self?.updateExternalDisplay()
            }
        }
    }

    @objc private func externalDisplayInputsDidChange() {
        updateExternalDisplay()
    }

    @objc private func externalDisplayFilterDidChange() {
        updateExternalDisplayFilter()
    }

    /// Brings both screens in line with `externalDisplayPlan`. Cheap and safe to call whenever
    /// one of its inputs may have changed.
    func updateExternalDisplay() {
        // The scene arrives later through `ExternalDisplayCoordinator.didChangeNotification`,
        // which calls back here.
        updateExternalDisplayAccessory()
        if ExternalDisplayCoordinator.shared.isConnected { findExternalDisplayGameArt() }
        let plan = externalDisplayPlan
        let metalVC = gpuViewController as? PVMetalViewController
        if plan.gameOnExternalDisplay,
           let scene = ExternalDisplayCoordinator.shared.scene,
           let metalVC, let device = metalVC.device {
            if externalDisplayWindow?.windowScene !== scene {
                removeExternalDisplayWindow()
                let output = GameExternalOutputView(device: device) { [weak metalVC] in
                    metalVC?.redrawPausedFrame()
                }
                let controller = UIViewController()
                controller.view = output
                let window = UIWindow(windowScene: scene)
                window.rootViewController = controller
                // Shown, never key: the device's window keeps keyboard and controller focus.
                window.isHidden = false
                // Size the drawable now, so a paused game appears without waiting for a layout pass.
                window.layoutIfNeeded()
                externalDisplayWindow = window
                metalVC.externalOutput = output
                ILOG("External display: showing the game picture (\(scene.screen.bounds.size))")
            }
            updateExternalDisplayFilter()
            updateExternalDisplaySkin()
        } else {
            removeExternalDisplayWindow()
        }
        metalVC?.blanksPicture = !plan.pictureOnDevice
        // Emulation may be paused (the pause menu changes these settings): show the result now.
        metalVC?.redrawPausedFrame()
    }

    /// Hands the external display its filter: its own selection if one is set, else the game's.
    ///
    /// Inside a TV the filter is the tube's look: the TV's own until the player picks one for
    /// this display, and never a filter that draws a frame of its own. The TV is updated with
    /// it, since what the glass does depends on the filter under it.
    func updateExternalDisplayFilter() {
        guard let metalVC = gpuViewController as? PVMetalViewController, let output = metalVC.externalOutput else { return }
        let store = ShaderLibraryStore.shared
        let smoothing = Defaults[.imageSmoothingMode].usesLinearFiltering
        var resolved = store.resolvedShader(on: .external, gameMD5: shaderGameMD5, systemID: shaderSystemID,
                                            screenType: core.screenType)
        let bezel = externalDisplayPlan.bezelOnExternalDisplay ? externalDisplayBezel : nil
        if bezel?.presetID != nil {
            // A standalone preset includes its own tube treatment.
            resolved = nil
        } else if let bezel, bezel.image != nil {
            // An image bezel has no look or glass of its own: the filter runs as it does with
            // no TV, except one that brings a frame, which cannot go inside another.
            if let picked = resolved, TVBezelShader.isBezelFilter(picked.entry) { resolved = nil }
        } else if let bezel {
            switch ExternalDisplayBezelRules.tubeFilter(
                hasUserSelection: store.selection(for: .screen(.external)) != nil,
                userSelectionIsOff: resolved == nil,
                userSelectionIsBezel: resolved.map { TVBezelShader.isBezelFilter($0.entry) } ?? false) {
            case .tvOwn:
                resolved = bezel.look.flatMap { look in
                    ShaderCatalog.shared.entry(for: look.shaderID).map { entry in
                        // Never the player's saved values: this is the TV's look, not their pick.
                        ResolvedShader(entry: entry,
                                       values: look.values.merging(TVBezelShader.curvatureOffValues(for: entry)) { _, off in off },
                                       revision: bezel.id.hashValue)
                    }
                }
            case .user:
                resolved = resolved.map { picked in
                    ResolvedShader(entry: picked.entry,
                                   values: picked.values.merging(TVBezelShader.curvatureOffValues(for: picked.entry)) { _, off in off },
                                   revision: picked.revision)
                }
            case .off:
                resolved = nil
            }
        }
        output.filter.update(resolved, smoothing: smoothing)
        let flatGlass = resolved.map { TVBezelShader.bendsPictureItself($0.entry) } ?? false
        output.showBezel(bezel, lightsRoom: bezelLightsRoom, flatGlass: flatGlass, pictureAspect: metalVC.bezelPictureAspect) { [weak metalVC] in
            metalVC?.redrawPausedFrame()
        }
        metalVC.redrawPausedFrame()
    }

    /// Draws the device's skin around the picture on the external display when the settings ask
    /// for it and the skin has a layout that frames one game screen; else the picture alone.
    func updateExternalDisplaySkin() {
        guard let metalVC = gpuViewController as? PVMetalViewController,
              let output = metalVC.externalOutput else { return }
        var skin: (any DeltaSkinRenderable)?
        var layout: ExternalDisplaySkinLayout?
        if externalDisplayPlan.skinOnExternalDisplay, let renderable = currentSkin as? any DeltaSkinRenderable {
            let deviceTraits = skinRenderTraits()
            layout = ExternalDisplaySkinLayout.resolve(gameIdentifiers: deviceTraits.gameIdentifiers,
                                                       usesAltRepresentations: deviceTraits.usesAltRepresentations,
                                                       containerSize: output.bounds.size,
                                                       screens: { renderable.screens(for: $0) },
                                                       mappingSize: { renderable.mappingSize(for: $0) })
            skin = layout == nil ? nil : renderable
            if let layout {
                ILOG("External display: skin '\(renderable.name)' with its \(layout.traits.description) layout")
            } else {
                ILOG("External display: skin '\(renderable.name)' has no landscape layout that frames one screen; showing the picture alone")
            }
        }
        output.showSkin(skin, layout: layout) { [weak metalVC] in
            metalVC?.redrawPausedFrame()
        }
    }

    /// Takes the game picture off the external display; the system goes back to mirroring.
    func removeExternalDisplayWindow() {
        guard let window = externalDisplayWindow else { return }
        (gpuViewController as? PVMetalViewController)?.externalOutput = nil
        window.isHidden = true
        window.rootViewController = nil
        externalDisplayWindow = nil
        ILOG("External display: back to mirroring")
    }
}
#endif
