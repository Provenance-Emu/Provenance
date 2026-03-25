//
//  PVRetroArchCoreCore.swift
//  PVRetroArchCore
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
#if canImport(GameController)
import GameController
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif
import PVLogging
import PVAudio
import PVEmulatorCore
import PVCoreObjCBridge
import Combine
import Defaults
import PVSettings
import PVCoreBridge
import PVSystems

@objc
@objcMembers
public class PVRetroArchCoreCore: PVEmulatorCore {

    public override var rendersToOpenGL: Bool { true }
    public override var isDoubleBuffered: Bool { true }
    public override var supportsFilters: Bool {
        let unsupportedCores = [
            "com.provenance.ps2",
            "com.provenance.gamecube",
            "com.provenance.wii",
            "com.provenance.vectrex"
        ]
        let sysName = EmulationState.shared.stateSubject.value.systemName
        DLOG("[RA] self.systemIdentifier: \(self.systemIdentifier ?? ""), systemName: \(sysName))")
        return (!unsupportedCores.contains(self.systemIdentifier ?? "")
                && !unsupportedCores.contains(sysName))
    }
    public override var supportsSkins: Bool {
        let unsupportedCores = [
            "com.provenance.ds",
            "com.provenance.dos",
            "com.provenance.mame",
            "com.provenance.arcade",
            "com.provenance.palmos",
            "com.provenance.cps1",
            "com.provenance.cps2",
            "com.provenance.cps3",
            "com.provenance.msx",
            "com.provenance.msx2"
        ]
        let sysName = EmulationState.shared.stateSubject.value.systemName
        DLOG("[RA] self.systemIdentifier: \(self.systemIdentifier ?? ""), systemName: \(sysName))")
        return (!unsupportedCores.contains(self.systemIdentifier ?? "")
                && !unsupportedCores.contains(sysName))
    }
    public override var supportsAudioVisualizer: Bool { true }
    /// Ignores late pause/unpause requests after core teardown starts.
    public override func setPauseEmulation(_ flag: Bool) {
        guard isOn else {
            DLOG("PVRetroArchCoreCore setPauseEmulation ignored because core is off (\(flag ? "pause" : "resume"))")
            return
        }
        ILOG("PVRetroArchCoreCore  setPauseEmulation: \(flag ? "paused" : "resumed")")
        _bridge.setPauseEmulation(flag)
        super.setPauseEmulation(flag)
    }
    public override var supportsSaveStates: Bool {
        let unsupportedCores: [String] = [
            // "com.provenance.dreamcast"
//            "com.provenance.dos"
        ]
        let sysName = EmulationState.shared.stateSubject.value.systemName
        DLOG("[RA] self.systemIdentifier: \(self.systemIdentifier ?? ""), systemName: \(sysName))")
        return (!unsupportedCores.contains(self.systemIdentifier ?? "")
                && !unsupportedCores.contains(sysName))
                || core_info_current_supports_savestate()
    }

    // MARK: Lifecycle
    public lazy var _bridge: PVRetroArchCoreBridge = .init()
    private var showFPSCancellable: AnyCancellable?

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
        configureShowFPSPreferenceObservation()
    }

    // MARK: - RetroAchievements backing storage

    /// Weak reference to the OSD delegate.
    /// RetroArch renders its own achievement OSD in the GL buffer; this
    /// delegate is used only for events that need to reach native Swift
    /// UI (sounds, CloudKit tracking, etc.).
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?

    /// Hardcore mode is controlled via RetroArch config; this mirrors it.
    var _hardcoreMode: Bool = false

    private func configureShowFPSPreferenceObservation() {
        _bridge.setShowFPSCounterVisible(Defaults[.showFPSCount])
        showFPSCancellable = Defaults.publisher(.showFPSCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?._bridge.setShowFPSCounterVisible(change.newValue)
            }
    }

    // MARK: - Haptic profile lifecycle

    /// Apply the per-system haptic profile so GCControllerHapticsManager tunes
    /// rumble to the loaded system's motor characteristics.
    public override func startEmulation() {
        if let sysId = systemIdentifier {
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.setSystemProfile(forSystemIdentifier: sysId)
            }
#endif
        }
        super.startEmulation()
        // Apply per-port device type defaults after the game has loaded.
        // RetroArch loads the game synchronously inside startVM: (called from the ObjC
        // bridge's startEmulation), so by the time super.startEmulation() returns the
        // core's retro_load_game has already run and port device types can be configured.
        restorePortDeviceTypes()
    }

    /// Reset the haptic profile so the next core starts with neutral tuning.
    public override func stopEmulation() {
#if canImport(GameController) && canImport(CoreHaptics)
        if #available(iOS 14.0, tvOS 14.0, *) {
            GCControllerHapticsManager.shared.resetSystemProfile()
        }
#endif
        super.stopEmulation()
    }
}

/// Resolves which virtual input overlays a RetroArch session can legitimately expose.
///
/// RetroArch's Objective-C categories add keyboard and mouse selectors to the shared
/// `PVRetroArchCoreBridge` class, so plain protocol casts can over-report support for
/// unrelated libretro cores. Prefer the loaded system identifier, then fall back to the
/// selected core binary only when the session is still in the generic RetroArch bucket.
private struct RetroArchVirtualInputSupport {
    let supportsKeyboard: Bool
    let requiresKeyboard: Bool
    let supportsMouse: Bool
    let requiresMouse: Bool

    /// No virtual input overlay is available.
    static let unsupported = Self(
        supportsKeyboard: false,
        requiresKeyboard: false,
        supportsMouse: false,
        requiresMouse: false
    )

    /// Keyboard-only support.
    static func keyboard(required: Bool = false) -> Self {
        .init(
            supportsKeyboard: true,
            requiresKeyboard: required,
            supportsMouse: false,
            requiresMouse: false
        )
    }

    /// Mouse/pointer-only support (e.g. DS touchscreen via RETRO_DEVICE_POINTER).
    static func mouse(required: Bool = false) -> Self {
        .init(
            supportsKeyboard: false,
            requiresKeyboard: false,
            supportsMouse: true,
            requiresMouse: required
        )
    }

    /// Keyboard + mouse support.
    static func keyboardAndMouse(requiredKeyboard: Bool = false, requiredMouse: Bool = false) -> Self {
        .init(
            supportsKeyboard: true,
            requiresKeyboard: requiredKeyboard,
            supportsMouse: true,
            requiresMouse: requiredMouse
        )
    }

    /// Returns the effective support for the currently loaded RetroArch session.
    static func resolve(systemIdentifier: String?, coreIdentifier: String?) -> Self {
        if let systemIdentifier, let support = supportBySystemIdentifier[systemIdentifier] {
            return support
        }

        guard isGenericRetroArchSystem(systemIdentifier),
              let coreIdentifier,
              let support = supportByCoreIdentifier[coreIdentifier] else {
            return .unsupported
        }

        return support
    }

    /// Whether the system identifier is still unresolved/generic and needs a core fallback.
    private static func isGenericRetroArchSystem(_ systemIdentifier: String?) -> Bool {
        guard let systemIdentifier, !systemIdentifier.isEmpty else {
            return true
        }

        return systemIdentifier == "com.provenance.retroarch"
    }

    /// Runtime capability keyed by the loaded content's system identifier.
    private static let supportBySystemIdentifier: [String: Self] = [
        "com.provenance.3DO": .keyboard(),
        "com.provenance.appleII": .keyboard(),
        "com.provenance.atari8bit": .keyboardAndMouse(requiredKeyboard: true),
        "com.provenance.atarist": .keyboardAndMouse(),
        "com.provenance.c64": .keyboard(),
        "com.provenance.cdi": .keyboard(),
        "com.provenance.colecovision": .keyboard(),
        "com.provenance.doom": .keyboardAndMouse(),
        "com.provenance.dos": .keyboardAndMouse(),
        "com.provenance.dreamcast": .keyboardAndMouse(),
        "com.provenance.ds": .keyboard(),    // DS uses native touchscreen via RETRO_DEVICE_POINTER
        "com.provenance.ep128": .keyboardAndMouse(requiredKeyboard: true),
        "com.provenance.macintosh": .keyboardAndMouse(),
        "com.provenance.mame": .keyboard(),
        "com.provenance.msx": .keyboardAndMouse(),
        "com.provenance.msx2": .keyboardAndMouse(),
        "com.provenance.n64": .keyboard(),
        "com.provenance.palmos": .keyboard(),
        "com.provenance.pc98": .keyboardAndMouse(),
        "com.provenance.psx": .keyboardAndMouse(), // PSX Mouse peripheral
        "com.provenance.quake": .keyboardAndMouse(),
        "com.provenance.quake2": .keyboardAndMouse(),
        "com.provenance.saturn": .keyboardAndMouse(), // Saturn Shuttle Mouse
        "com.provenance.snes": .keyboardAndMouse(), // SNES Mouse (Mario Paint, etc.)
        "com.provenance.tic80": .keyboard(),
        "com.provenance.wolf3d": .keyboardAndMouse(),
        "com.provenance.zxspectrum": .keyboardAndMouse(requiredKeyboard: true)
    ]

    /// Conservative fallback keyed by the selected libretro core when the system is still generic.
    private static let supportByCoreIdentifier: [String: Self] = [
        "atari800.libretro.framework": .keyboardAndMouse(requiredKeyboard: true),
        "cap32.libretro.framework": .keyboard(),
        "dosbox.pure.libretro.framework": .keyboardAndMouse(),
        "ecwolf.libretro.framework": .keyboardAndMouse(),
        "flycast-jitless.libretro.framework": .keyboardAndMouse(),
        "flycast.libretro.framework": .keyboardAndMouse(),
        "fuse.libretro.framework": .keyboardAndMouse(requiredKeyboard: true),
        "hatari.libretro.framework": .keyboardAndMouse(),
        "m2000.libretro.framework": .keyboard(),
        "minivmac.libretro.framework": .keyboardAndMouse(),
        "mu.libretro.framework": .keyboard(),
        "np2kai.libretro.framework": .keyboardAndMouse(),
        "numero.libretro.framework": .keyboard(),
        "opera.libretro.framework": .keyboard(),
        "prboom.libretro.framework": .keyboardAndMouse(),
        "theodore.libretro.framework": .keyboard(),
        "tyrquake.libretro.framework": .keyboardAndMouse(),
        "vice.x128.libretro.framework": .keyboard(),
        "vice.x64.libretro.framework": .keyboard(),
        "vice.xpet.libretro.framework": .keyboard(),
        "vice.xvic.libretro.framework": .keyboard(),
        "vitaquake2-rogue.libretro.framework": .keyboardAndMouse(),
        "vitaquake2-xatrix.libretro.framework": .keyboardAndMouse(),
        "vitaquake2-zaero.libretro.framework": .keyboardAndMouse(),
        "vitaquake2.libretro.framework": .keyboardAndMouse(),
        "tic80.libretro.framework": .keyboard(),
        "x1.libretro.framework": .keyboard()
    ]
}
// MARK: RetroArch
extension PVRetroArchCoreCore: PVRetroArchCoreResponderClient {
}

extension PVRetroArchCoreCore: DiscSwappable {
    public var currentGameSupportsMultipleDiscs: Bool {
        return _bridge.currentGameSupportsMultipleDiscs
    }

    public var numberOfDiscs: UInt {
        return _bridge.numberOfDiscs
    }
    public func swapDisc(number: UInt) {
        _bridge.swapDisc(withNumber: number)
    }
}

// MARK: GameBoy
extension PVRetroArchCoreCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGBButton, forPlayer player: Int) {
        (_bridge as! PVGBSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: GameBoy Advance
extension PVRetroArchCoreCore: PVGBASystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVGBAButton, forPlayer player: Int) {
        (_bridge as! PVGBASystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 2600
extension PVRetroArchCoreCore: PV2600SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PV2600Button, forPlayer player: Int) {
        (_bridge as! PV2600SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 5200
extension PVRetroArchCoreCore: PV5200SystemResponderClient {
    /// Keep joystick deadzone behavior aligned with the Atari 5200 bridge implementation.
    private static let atari5200JoystickDeadzone: CGFloat = 0.5

    /// Converts generic x/y joystick movement into 5200 directional analog calls.
    /// This avoids forwarding to a selector path the RetroArch 5200 Obj-C bridge does not implement.
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        /// Only Atari 5200 sessions may use this generic joystick entry point.
        /// Other RetroArch systems can conform to JoystickResponder but do not implement 5200 selectors.
        guard SystemIdentifier(rawValue: systemIdentifier ?? "") == .Atari5200 else {
            DLOG("Ignoring generic joystick input for non-Atari5200 system: \(systemIdentifier ?? "nil")")
            return
        }

        /// Atari 5200 only has one stick; ignore right-stick style events.
        guard button == 0 else { return }

        /// Use optional cast to avoid selector crashes if the bridge state is unexpected.
        guard let responder = _bridge as? PV5200SystemResponderClient else {
            ELOG("PVRetroArch bridge does not conform to PV5200SystemResponderClient for Atari5200 system")
            return
        }
        let deadzone = Self.atari5200JoystickDeadzone
        let xMagnitude = min(1, abs(xValue))
        let yMagnitude = min(1, abs(yValue))

        if xValue > deadzone {
            responder.didMoveJoystick(.right, withValue: xMagnitude, forPlayer: player)
            responder.didMoveJoystick(.left, withValue: 0, forPlayer: player)
        } else if xValue < -deadzone {
            responder.didMoveJoystick(.left, withValue: xMagnitude, forPlayer: player)
            responder.didMoveJoystick(.right, withValue: 0, forPlayer: player)
        } else {
            responder.didMoveJoystick(.right, withValue: 0, forPlayer: player)
            responder.didMoveJoystick(.left, withValue: 0, forPlayer: player)
        }

        if yValue > deadzone {
            responder.didMoveJoystick(.down, withValue: yMagnitude, forPlayer: player)
            responder.didMoveJoystick(.up, withValue: 0, forPlayer: player)
        } else if yValue < -deadzone {
            responder.didMoveJoystick(.up, withValue: yMagnitude, forPlayer: player)
            responder.didMoveJoystick(.down, withValue: 0, forPlayer: player)
        } else {
            responder.didMoveJoystick(.up, withValue: 0, forPlayer: player)
            responder.didMoveJoystick(.down, withValue: 0, forPlayer: player)
        }
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PV5200Button, withValue value: CGFloat, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PV5200Button, forPlayer player: Int) {
        (_bridge as! PV5200SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari 7800
extension PVRetroArchCoreCore: PV7800SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV7800Button, forPlayer player: Int) {
        (_bridge as! PV7800SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Atari Jaguar
extension PVRetroArchCoreCore: PVJaguarSystemResponderClient {
    public func didPush(jaguarButton button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didPush(jaguarButton: button, forPlayer: player)
    }
    public func didRelease(jaguarButton button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didRelease(jaguarButton: button, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didPush(jaguarButton: button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVJaguarButton, forPlayer player: Int) {
        (_bridge as! PVJaguarSystemResponderClient).didRelease(jaguarButton: button, forPlayer: player)
    }
}

// MARK: Atari Lynx
extension PVRetroArchCoreCore: PVLynxSystemResponderClient {
    public func didPush(LynxButton button: PVCoreBridge.PVLynxButton, forPlayer player: Int) {
        (_bridge as! PVLynxSystemResponderClient).didPush(LynxButton: button, forPlayer: player)
    }

    public func didRelease(LynxButton button: PVCoreBridge.PVLynxButton, forPlayer player: Int) {
        (_bridge as! PVLynxSystemResponderClient).didRelease(LynxButton: button, forPlayer: player)
    }
}

// MARK: NeoGeo PVNeoGeoSystemResponderClient
extension PVRetroArchCoreCore: PVNeoGeoSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVNeoGeoButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVNeoGeoButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNeoGeoButton, forPlayer player: Int) {
        (_bridge as! PVNeoGeoSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: NES
extension PVRetroArchCoreCore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: SNES
extension PVRetroArchCoreCore: PVSNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (_bridge as! PVSNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: N64
extension PVRetroArchCoreCore: PVN64SystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVN64Button, forPlayer player: Int) {
        (_bridge as! PVN64SystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: DS
extension PVRetroArchCoreCore: PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: 3DS
extension PVRetroArchCoreCore: PV3DSSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV3DSButton, forPlayer player: Int) {
        (_bridge as! PV3DSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: PSX
extension PVRetroArchCoreCore: PVPSXSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        if button == .analogMode {
            togglePSXAnalogMode()
            return
        }
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        if button == .analogMode {
            return
        }
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: PS2
extension PVRetroArchCoreCore: PVPS2SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPS2Button, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVPS2Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPS2SystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}
// MARK: Genesis
extension PVRetroArchCoreCore: PVGenesisSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGenesisButton, forPlayer player: Int) {
        (_bridge as! PVGenesisSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVGenesisButton, forPlayer player: Int) {
        (_bridge as! PVGenesisSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: SG1000
extension PVRetroArchCoreCore: PVSG1000SystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSG1000Button, forPlayer player: Int) {
        (_bridge as! PVSG1000SystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSG1000Button, forPlayer player: Int) {
        (_bridge as! PVSG1000SystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: 32X
extension PVRetroArchCoreCore: PVSega32XSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Dreamcast
extension PVRetroArchCoreCore: PVDreamcastSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVDreamcastButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDreamcastButton, forPlayer player: Int) {
        (_bridge as! PVDreamcastSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Intellivision
extension PVRetroArchCoreCore: PVIntellivisionSystemResponderClient {
    @nonobjc
    public func didMoveJoystick(_ button: PVCoreBridge.PVIntellivisionButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
//        (_bridge as! PVIntellivisionSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVIntellivisionButton, forPlayer player: Int) {
        (_bridge as! PVIntellivisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Colecovision
extension PVRetroArchCoreCore: PVColecoVisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
// MARK: Supervision
extension PVRetroArchCoreCore: PVSupervisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// MARK: Doom (PrBoom)
// PVDoomSystemResponderClient forwards directly to the ObjC Doom bridge
// (PVRetroArchCoreBridge (DoomControls)) which has correct PrBoom button mappings.
// Previously this converted through asDOSButton → DOS bridge, causing wrong mappings.
extension PVRetroArchCoreCore: PVDoomSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDoomButton, forPlayer player: Int) {
        (_bridge as? PVDoomSystemResponderClient)?.didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDoomButton, forPlayer player: Int) {
        (_bridge as? PVDoomSystemResponderClient)?.didRelease(button, forPlayer: player)
    }
}

// PVDOSSystemResponderClient + KeyboardResponder + MouseResponder
extension PVRetroArchCoreCore: PVDOSSystemResponderClient, KeyboardResponder, MouseResponder {
    /// Resolves the effective virtual-input capability for the current RetroArch session.
    private var virtualInputSupport: RetroArchVirtualInputSupport {
        RetroArchVirtualInputSupport.resolve(systemIdentifier: systemIdentifier, coreIdentifier: coreIdentifier)
    }

    public func didRelease(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as? PVDOSSystemResponderClient)?.didRelease(button, forPlayer: player)
    }

    public var gameSupportsKeyboard: Bool {
        virtualInputSupport.supportsKeyboard
    }

    public var requiresKeyboard: Bool {
        virtualInputSupport.requiresKeyboard
    }

    public func keyDown(_ key: GCKeyCode) {
        (_bridge as? PVDOSSystemResponderClient)?.keyDown(key)
    }
    public func keyUp(_ key: GCKeyCode) {
        (_bridge as? PVDOSSystemResponderClient)?.keyUp(key)
    }
    public var gameSupportsMouse: Bool {
        guard virtualInputSupport.supportsMouse else { return false }
        // For systems where only specific games use a mouse (PSX, Saturn, SNES, Dreamcast),
        // delegate to MouseGameRegistry for per-game detection so titles like Crash Bandicoot
        // don't incorrectly show the mouse cursor.
        if let sysID = SystemIdentifier(rawValue: systemIdentifier ?? ""),
           MouseGameRegistry.shared.systemHasAnyMouseSupport(sysID) {
            return MouseGameRegistry.shared.gameSupportsMouse(
                systemIdentifier: sysID,
                md5: romMD5,
                title: romName
            )
        }
        return true
    }
    public var requiresMouse: Bool {
        virtualInputSupport.requiresMouse
    }
    public func didScroll(_ cursor: GCDeviceCursor) {
        (_bridge as? PVDOSSystemResponderClient)?.didScroll(cursor)
    }

    public var mouseMovedHandler: GCMouseMoved? {
        (_bridge as? PVDOSSystemResponderClient)?.mouseMovedHandler
    }
    public func mouseMoved(at point: CGPoint) {
        (_bridge as? PVDOSSystemResponderClient)?.mouseMoved(at: point)
    }
    public func mouseMoved(atPoint point: CGPoint) {
        (_bridge as? PVDOSSystemResponderClient)?.mouseMoved(at: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        (_bridge as? PVDOSSystemResponderClient)?.leftMouseDown(at: point)
    }
    public func leftMouseDown(atPoint point: CGPoint) {
        (_bridge as? PVDOSSystemResponderClient)?.leftMouseDown(at: point)
    }
    public func leftMouseUp() {
        (_bridge as? PVDOSSystemResponderClient)?.leftMouseUp()
    }
    public func rightMouseDown(atPoint point: CGPoint) {
        (_bridge as? PVDOSSystemResponderClient)?.rightMouseDown(atPoint: point)
    }
    public func rightMouseUp() {
        (_bridge as? PVDOSSystemResponderClient)?.rightMouseUp()
    }
    public func didPush(_ button: PVCoreBridge.PVDOSButton, forPlayer player: Int) {
        (_bridge as? PVDOSSystemResponderClient)?.didPush(button, forPlayer: player)
    }
}

// MAME
extension PVRetroArchCoreCore: PVMAMESystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVMAMEButton, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVMAMEButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVMAMEButton, forPlayer player: Int) {
        (_bridge as! PVMAMESystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// 3DO
extension PVRetroArchCoreCore: PV3DOSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didRelease(button, forPlayer: player)
    }

    public func didPush(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// PCE
extension PVRetroArchCoreCore: PVPCESystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCEButton, forPlayer player: Int) {
        (_bridge as! PVPCESystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// PCE-CD
extension PVRetroArchCoreCore: PVPCECDSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCECDButton, forPlayer player: Int) {
        (_bridge as! PVPCECDSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// PCFX
extension PVRetroArchCoreCore: PVPCFXSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVPCFXButton, forPlayer player: Int) {
        (_bridge as! PVPCFXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

// PSP
extension PVRetroArchCoreCore: PVPSPSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSPButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVPSPButton, forPlayer player: Int) {
        (_bridge as! PVPSPSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// Sega Saturn
extension PVRetroArchCoreCore: PVSaturnSystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVSaturnButton, forPlayer player: Int) {
        (_bridge as! PVSaturnSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// Nintendo VirtualBoy
extension PVRetroArchCoreCore: PVVirtualBoySystemResponderClient {
    public func didRelease(_ button: PVCoreBridge.PVVBButton, forPlayer player: Int) {
        (_bridge as! PVVirtualBoySystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVVBButton, forPlayer player: Int) {
        (_bridge as! PVVirtualBoySystemResponderClient).didPush(button, forPlayer: player)
    }
}

// CDi

extension PVRetroArchCoreCore: PVCDiSystemResponderClient {
//    public func didMoveJoystick(_ button: PVCoreBridge.PVCDiButton, withValue value: CGFloat, forPlayer player: Int) {
//        (_bridge as! PVCDiSystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player)
//    }
    public func didRelease(_ button: PVCoreBridge.PVCDiButton, forPlayer player: Int) {
        (_bridge as! PVCDiSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVCDiButton, forPlayer player: Int) {
        (_bridge as! PVCDiSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// Vectrex
extension PVRetroArchCoreCore: PVVectrexSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVVectrexButton, withValue value: CGFloat, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didMoveJoystick(button, withValue: value, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVVectrexButton, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVVectrexButton, forPlayer player: Int) {
        (_bridge as! PVVectrexSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// GameCube
extension PVRetroArchCoreCore: PVGameCubeSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVGCButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// Wii
extension PVRetroArchCoreCore: PVWiiSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVWiiMoteButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didRelease(button, forPlayer: player)

    }
    public func didPush(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didPush(button, forPlayer: player)
    }
}

// MARK: - PortDeviceConfigurable

extension PVRetroArchCoreCore: PortDeviceConfigurable {

    /// RetroArch manages its own controller info UI; return empty to hide
    /// the in-app port device picker for RetroArch cores.
    public var controllerPortDescriptors: [[PortDeviceDescriptor]] { [] }

    public func currentDeviceType(forPort port: Int) -> UInt {
        let key = portDevicePersistenceKey(port: port)
        if UserDefaults.standard.object(forKey: key) != nil {
            return UInt(UserDefaults.standard.integer(forKey: key))
        }
        return LibretroDeviceType.joypad.rawValue
    }

    public func setDeviceType(_ deviceType: UInt, forPort port: Int) {
        _bridge.setControllerPortDevice(UInt32(deviceType), forPort: UInt32(port))
        let key = portDevicePersistenceKey(port: port)
        UserDefaults.standard.set(Int(deviceType), forKey: key)
    }

    /// Apply saved (or platform-default) port device types after the game has loaded.
    func restorePortDeviceTypes() {
        // Iterate ports 0 and 1 — most peripheral devices appear on port 1 (e.g. SNES Mouse).
        for port in 0..<2 {
            let key = portDevicePersistenceKey(port: port)
            if UserDefaults.standard.object(forKey: key) != nil {
                let saved = UInt(UserDefaults.standard.integer(forKey: key))
                _bridge.setControllerPortDevice(UInt32(saved), forPort: UInt32(port))
            } else if let defaultDevice = platformDefaultPortDevice(forPort: port) {
                _bridge.setControllerPortDevice(UInt32(defaultDevice), forPort: UInt32(port))
                ILOG("[RA] restorePortDeviceTypes: applied platform default device=\(defaultDevice) on port \(port)")
            }
        }
    }

    /// Returns a platform-specific default device type for a port, or nil to leave at core default.
    private func platformDefaultPortDevice(forPort port: Int) -> UInt? {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return nil }
        // SNES: port 2 (index 1) defaults to RETRO_DEVICE_MOUSE for known SNES Mouse games.
        if sysID == .SNES && port == 1 {
            if MouseGameRegistry.shared.gameSupportsMouse(
                systemIdentifier: sysID,
                md5: romMD5,
                title: romName
            ) {
                return LibretroDeviceType.mouse.rawValue
            }
        }
        return nil
    }

    /// UserDefaults key scoped to this core + game combination.
    private func portDevicePersistenceKey(port: Int) -> String {
        let md5 = romMD5 ?? "global"
        let coreID = coreIdentifier ?? String(describing: type(of: self))
        return "PVRetroArchCoreCore.\(md5).\(coreID).portDeviceType.port\(port)"
    }
}
