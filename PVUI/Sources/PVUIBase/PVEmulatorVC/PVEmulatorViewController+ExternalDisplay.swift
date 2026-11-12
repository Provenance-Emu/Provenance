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
            skinHasOwnArt: isDeltaSkinEnabled && currentSkin != nil && !isProgrammaticOverlayActive,
            devicePicture: Defaults[.externalDisplayDevicePicture]))
    }

    /// Whether the external display is showing the game picture on its own right now.
    var isGameOnExternalDisplay: Bool { externalDisplayWindow != nil }

    func observeExternalDisplay() {
        NotificationCenter.default.addObserver(self, selector: #selector(externalDisplayInputsDidChange),
                                               name: ExternalDisplayCoordinator.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(externalDisplayFilterDidChange),
                                               name: ShaderLibraryStore.didChangeNotification, object: nil)
        externalDisplaySettingsObservation = Task { @MainActor [weak self] in
            for await _ in Defaults.updates([.externalDisplayMode, .externalDisplayDevicePicture, .imageSmoothingMode],
                                            initial: false) {
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
        let plan = externalDisplayPlan
        let metalVC = gpuViewController as? PVMetalViewController
        if plan.gameOnExternalDisplay,
           let scene = ExternalDisplayCoordinator.shared.scene,
           let metalVC, let device = metalVC.device {
            if externalDisplayWindow?.windowScene !== scene {
                removeExternalDisplayWindow()
                let output = GameExternalOutputView(device: device)
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
        } else {
            removeExternalDisplayWindow()
        }
        metalVC?.blanksPicture = !plan.pictureOnDevice
        // Emulation may be paused (the pause menu changes these settings): show the result now.
        metalVC?.redrawPausedFrame()
    }

    /// Hands the external display its filter: its own selection if one is set, else the game's.
    func updateExternalDisplayFilter() {
        guard let output = (gpuViewController as? PVMetalViewController)?.externalOutput else { return }
        let resolved = ShaderLibraryStore.shared.resolvedShader(on: .external,
                                                                 gameMD5: shaderGameMD5,
                                                                 systemID: shaderSystemID,
                                                                 screenType: core.screenType)
        output.filter.update(resolved, smoothing: Defaults[.imageSmoothingMode].usesLinearFiltering)
        (gpuViewController as? PVMetalViewController)?.redrawPausedFrame()
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
