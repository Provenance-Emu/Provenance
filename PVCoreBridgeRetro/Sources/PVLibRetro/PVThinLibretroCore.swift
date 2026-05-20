//
//  PVThinLibretroCore.swift
//  PVCoreBridgeRetro
//
//  Created by Joe Mattiello on 2026-03-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Swift `PVEmulatorCore` subclass that wraps `PVThinLibretroFrontend`.
//  This class is the `principleClass` registered in dynamically-scanned
//  libretro core plists, giving `PVCoreFactory.createInstance(forSystem:)`
//  a proper `PVEmulatorCore` subclass to instantiate.
//

import Combine
import Foundation
import os
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import PVSystems
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
#endif
#if canImport(UIKit)
import UIKit
#endif

public extension Notification.Name {
    /// Posted (on main) when the active thin-libretro core reports new AV info via
    /// `RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO` or `SET_GEOMETRY`. SwiftUI views that
    /// cache aspect-ratio data derived from the core should invalidate on receipt
    /// so the next layout pass re-reads the core's current geometry.
    static let PVThinLibretroCoreAVInfoDidUpdate = Notification.Name("PVThinLibretroCoreAVInfoDidUpdate")

    // Note: `pvThinLibretroFrontendCoreDidThrow` and `pvRetroArchCoreDidThrow`
    // are defined in `PVUI/Sources/PVUIBase/PVEmulatorVC/CoreDidThrow+NotificationName.swift`
    // because PVUI doesn't import PVCoreBridgeRetro (different tier).
    // The ObjC `NSNotificationName` constants in the respective wrappers'
    // headers (`PVThinLibretroFrontend.h`, `PVRetroArchCore+ExceptionTrampoline.h`)
    // remain the source of truth for the string values.
}

/// Internal to keep `PVEmulatorCore` out of the generated
/// `PVCoreBridgeRetro-Swift.h` header (which would break every
/// downstream ObjC core target). `@objc` ensures the class is
/// registered with the ObjC runtime so `NSClassFromString` /
/// `principleClass` lookups still work.
// swiftlint:disable:next attributes
@objc(PVThinLibretroCore) @objcMembers
class PVThinLibretroCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Lifecycle

    /// Weak reference to the currently-active thin core instance.
    /// Used by the static `options` accessor since `CoreOptional` is static.
    /// Only one emulation runs at a time so this is safe.
    nonisolated(unsafe) static weak var current: PVThinLibretroCore?

    /// Monotonic generation counter bumped on every `init` and on
    /// `stopEmulation` / `deinit`. Captured by the libretro `inputPollBlock`
    /// closure so a stale poll fired from the emu thread after a core swap
    /// (or during this core's tear-down) becomes a no-op before it touches
    /// `pollControllers()` and the half-deinit'd `_bridge` state.
    private static let generationLock = OSAllocatedUnfairLock<Int>(initialState: 0)

    /// This instance's generation tag — captured at `init`. The poll closure
    /// bails out when this no longer matches `Self.currentGeneration`.
    private let myGeneration: Int

    /// Bumps and returns the new generation value. Called from `init` (to
    /// claim a fresh tag) and from `stopEmulation` / `deinit` (to invalidate
    /// any in-flight poll closures still referencing this instance).
    @discardableResult
    private static func bumpGeneration() -> Int {
        return generationLock.withLock { gen in
            gen &+= 1
            return gen
        }
    }

    /// Snapshot of the current generation. The poll closure compares against
    /// its captured `myGeneration`; a mismatch means this core was superseded
    /// or torn down and the closure must not touch `self`.
    private static var currentGeneration: Int {
        return generationLock.withLock { $0 }
    }

    lazy var _bridge: PVThinLibretroFrontend = .init()

    // MARK: - MIDI destination observation
    /// Cancellable for the Combine subscription that routes MIDIDeviceManager
    /// destination changes to the thin libretro frontend.
    /// Only set on platforms with CoreMIDI (iOS, macOS, Catalyst); nil on tvOS.
    @MainActor var _midiDestinationCancellable: AnyCancellable?

    // MARK: - RetroAchievements backing storage
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?
    var _hardcoreMode: Bool = false
    var _achievementsActive: Bool = false

    // MARK: - Transfer Pak backing storage (for TransferPakSupport conformance)
    /// In-memory Transfer Pak slot map: controller port (0-based) → mounted GB/GBC ROM.
    /// Only populated when the core is a Mupen64Plus-based core.
    var _transferPakSlots: [Int: TransferPakROM] = [:]

    // MARK: - N64 C-button state
    /// Per-player C-button press state for N64. Mupen64plus-libretro expects C-buttons on
    /// `RETRO_DEVICE_INDEX_ANALOG_RIGHT` (X/Y axes), not digital retropad buttons, so digital
    /// C-button presses from DeltaSkin are accumulated here and written to the right analog
    /// stick each frame during `pollControllers()`.
    struct N64CButtonState { var up = false; var down = false; var left = false; var right = false }
    var _n64CButtons: [Int: N64CButtonState] = [:]

    // MARK: - Responder-asserted joypad mask
    /// Bits asserted by the responder protocol path (DeltaSkin on-screen buttons,
    /// TurboManager auto-fire, and any other `didPush`/`didRelease` source). The
    /// per-frame `pollControllers()` writes physical-controller state directly into
    /// `_bridge`'s joypad bitmask using `setButton(false)` when a physical button is
    /// up — which would CLOBBER a press asserted by the responder a few ms earlier
    /// on the main thread.
    ///
    /// Concretely this breaks TurboManager (#tester-turbo-thin-wrapper): TurboManager
    /// fires `didPush`/`didRelease` at ~10Hz from the main run-loop, but the 60Hz
    /// emulation-thread poll then overwrites the same bit with the physical pad's
    /// (un-pressed) state.
    ///
    /// Fix: track responder-asserted bits per player here, and OR this mask in
    /// during `pollControllers()` so a responder-asserted bit survives a physical
    /// poll cycle. Cleared on `didRelease`.
    ///
    /// Locked because writes come from the main thread (responder/TurboManager) and
    /// reads come from the emulation thread (`pollControllers`).
    @nonobjc let _responderJoypadMaskLock = OSAllocatedUnfairLock<[UInt16]>(initialState: [0, 0, 0, 0])

    // MARK: - Mouse / pointer input state
    /// Previous normalized cursor position (0–1 range) used to compute per-event deltas
    /// for RETRO_DEVICE_MOUSE systems. Updated by `mouseMoved(atPoint:)`.
    var _mousePrevNorm: CGPoint = .init(x: 0.5, y: 0.5)
    /// Whether `_mousePrevNorm` has been set at least once since the last button release.
    var _mousePrevValid: Bool = false
    /// Whether the DS touchscreen pointer is currently pressed (finger down).
    /// Used by `mouseMoved(atPoint:)` to maintain pressed state during drag.
    var _dsPointerPressed: Bool = false
    /// Previous touchpad position for DualSense touchpad → mouse delta computation.
    var _padTouchPrevX: Float = 0
    var _padTouchPrevY: Float = 0
    var _padTouchPrevValid: Bool = false

    /// Set by `updateHatariTOSPath()` when TOS validation fails.
    /// Checked by `startEmulation()` to abort before `retro_load_game` crashes.
    private var _hatariTOSError: String?

    // MARK: - Skin support

    /// Systems that don't have adequate skin support — disable skins to show
    /// the native on-screen controls or core-specific overlays instead.
    private static let skinUnsupportedSystems: Set<String> = [
        "com.provenance.3ds",
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

    public override var supportsSkins: Bool {
        guard let sysId = systemIdentifier else { return true }
        return !Self.skinUnsupportedSystems.contains(sysId)
    }

    required init() {
        // Claim a fresh generation BEFORE super.init so the poll closure
        // installed during startEmulation captures a value that's guaranteed
        // unique to this instance, even if a previous core is still mid-swap.
        self.myGeneration = PVThinLibretroCore.bumpGeneration()
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
        PVThinLibretroCore.current = self
        // Broadcast libretro AV-info changes so SwiftUI skin views invalidate their
        // cached aspect ratio when the core resizes mid-run (e.g. DS dual-screen
        // toggle). The block fires on the emulation thread; hop to main before any
        // observers touch UI state.
        _bridge.avInfoDidUpdateBlock = {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .PVThinLibretroCoreAVInfoDidUpdate,
                    object: nil
                )
            }
        }
        ILOG("ThinCore: initialized PVThinLibretroCore (bridge=\(_bridge), self=\(self))")
    }

    public override func startEmulation() {
        // Wire system profile for better haptic tuning.
        if let sysId = systemIdentifier {
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.setSystemProfile(forSystemIdentifier: sysId)
            }
#endif
        }
        // Apply per-core iOS-specific option defaults before the emulation loop starts.
        // These match what PVRetroArchCore+Options.swift sets for the full RA bridge.
        applyPlatformDefaults()
        // Translate the user's Display Scaling preference into the per-core libretro
        // options that gate widescreen / stretch / aspect overrides
        // (mupen64plus-aspect, dolphin_aspect_ratio, ppsspp_stretch, etc.). Must run
        // AFTER applyPlatformDefaults so the user's choice wins over any default we
        // would seed for the same key, and BEFORE retro_load_game so the core sees
        // the option at startup. Also start an observer so pause-menu changes
        // propagate into the running core. See PVThinLibretroCore+Scaling.swift.
        applyScalingModeToCoreOptions()
        startScalingModeObservation()
        // Register a post-load hook so port device types are restored AFTER retro_load_game
        // (which triggers SET_CONTROLLER_INFO) but BEFORE the emulation loop thread starts,
        // avoiding a potential race condition with retro_set_controller_port_device.
        _bridge.afterROMLoadBlock = { [weak self] in
            self?.restorePortDeviceTypes()
        }
        // Wire physical GCController polling into the emulation thread's input poll.
        //
        // Capture `myGeneration` so a stale poll fired by the libretro emu thread
        // after a core swap (or while this instance is being torn down) sees a
        // mismatched generation and bails out before touching `self`. The
        // generation is bumped in `init`, `stopEmulation`, and `deinit`, which
        // means: as soon as a new core is created OR this core's stopEmulation
        // begins teardown, any in-flight or about-to-fire poll closure becomes
        // a no-op. This closes the race where the emu thread's one-more-poll
        // could read input state from a partially-torn-down `_bridge`.
        let capturedGeneration = self.myGeneration
        _bridge.inputPollBlock = { [weak self] in
            guard PVThinLibretroCore.currentGeneration == capturedGeneration else {
                // Superseded by a newer core or already torn down — drop the poll.
                return
            }
            guard let strongSelf = self else { return }
            strongSelf.pollControllers()
        }
        // Start observing MIDIDeviceManager so MIDI output goes to the user-selected device.
#if canImport(CoreMIDI) && !os(tvOS)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.startMIDIDestinationObservation()
        }
#endif
        // Abort if Hatari TOS validation failed during applyPlatformDefaults().
        // Without valid TOS, Hatari's Reset_Cold() fails and triggers a GUI dialog
        // that crashes (null input_poll_cb in input_gui → EXC_BAD_ACCESS).
        if let tosError = _hatariTOSError {
            ELOG("ThinCore: aborting startEmulation — \(tosError)")
            return
        }

        ILOG("ThinCore: startEmulation — inputPollBlock wired, sysId=\(systemIdentifier ?? "nil")")
        super.startEmulation()
    }

    public override func stopEmulation() {
        // Invalidate the input-poll generation BEFORE [super stopEmulation] so any
        // poll fired from the libretro emu thread during teardown becomes a no-op
        // before reaching `pollControllers()`. `[super stopEmulation]` waits on
        // `emulationLoopThreadLock`, which already serialises with the loop, but
        // bumping here closes the gap where a final in-flight poll could still
        // run between teardown signalling and the loop noticing.
        PVThinLibretroCore.bumpGeneration()
        // Reset haptic profile to generic so the next core doesn't inherit this system's tuning.
        // Also stop any in-flight rumble on all ports — if emulation is torn down mid-burst
        // (user exits while controller is rumbling), the core won't get a chance to fire
        // set_rumble_state(0) and the long-duration haptic would keep playing past shutdown.
#if canImport(GameController) && canImport(CoreHaptics)
        if #available(iOS 14.0, tvOS 14.0, *) {
            for player in 0..<4 {
                GCControllerHapticsManager.shared.stopRumble(player: player)
            }
            GCControllerHapticsManager.shared.resetSystemProfile()
        }
#endif
        // Stop MIDI destination observation (does NOT clear the frontend cache —
        // the shared retro_midi_interface is also used by PVLibRetroCore, which
        // relies on the -1 legacy fallback if it never wired its own observer).
#if canImport(CoreMIDI) && !os(tvOS)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopMIDIDestinationObservation()
        }
#endif
        // Cancel the scaling-mode observer so it can't fire against a
        // tearing-down bridge after stopEmulation returns.
        stopScalingModeObservation()
        // Clear any responder-asserted joypad bits so a stuck on-screen / turbo
        // press doesn't leak into the next emulation session through our mask.
        _responderJoypadMaskLock.withLock { mask in
            for i in 0..<mask.count { mask[i] = 0 }
        }
        super.stopEmulation()
    }

    deinit {
        // Final safety net: if `stopEmulation` was skipped or this instance is
        // being released while another core is mid-init, bump the generation so
        // any captured poll closure still pinned by the bridge bails out before
        // resolving its `[weak self]` against a tearing-down instance.
        PVThinLibretroCore.bumpGeneration()
    }

    // MARK: - Per-core platform defaults

    /// Set iOS-specific core option defaults that differ from the core's
    /// built-in defaults. Only writes if the option hasn't been set yet
    /// (respects user overrides).
    private func applyPlatformDefaults() {
        let coreId = (coreIdentifier ?? "").lowercased()

        // MelonDS: enable touch mode for DS. On tvOS there is no touchscreen
        // and the user can't easily swap to the bottom screen, so flip the
        // default layout from upstream's "Top/Bottom" (256×384 portrait
        // framebuffer — letterboxed to slivers on a 16:9 TV) to "Left/Right"
        // (512×192 widescreen-ish framebuffer) which fills more of the
        // screen. The upstream key + value strings come from melonDS
        // libretro core_options (see Cores/melonDS/melonDS/src/libretro/
        // libretro.cpp ~line 185 and 322).
        if coreId.contains("melonds") {
            setDefaultOption("melonds_touch_mode", value: "Touch")
            #if os(tvOS)
            setDefaultOption("melonds_screen_layout", value: "Left/Right")
            // The melonds_ds fork (rsn8887 / kivutar) uses the same option
            // names with a `melondsds_` prefix. Setting both is harmless if
            // only one core is loaded — setDefaultOption() is a no-op when
            // the key isn't registered.
            setDefaultOption("melondsds_screen_layout", value: "Left/Right")
            setDefaultOption("melondsds_touch_mode", value: "Touch")
            #endif
        }

        // DeSmuME: enable touch mode for DS. Same rationale as melonDS —
        // upstream default `desmume_screens_layout` is "top/bottom"; on tvOS
        // switch to "left/right" so the framebuffer is landscape-friendly.
        // Option key + lowercase value strings verified against
        // Cores/Desmume2015/desmume2015/desmume/src/libretro/libretro.cpp
        // (lines 701 / 1051) — desmume and desmume2015 share the same keys.
        if coreId.contains("desmume") {
            setDefaultOption("desmume_pointer_type", value: "touch")
            #if os(tvOS)
            setDefaultOption("desmume_screens_layout", value: "left/right")
            #endif
        }

        // DOSBox Pure: use mouse pad mode + enable MIDI
        if coreId.contains("dosbox") {
            setDefaultOption("dosbox_pure_mouse_input", value: "pad")
            setDefaultOption("dosbox_pure_midi", value: "enabled")
        }

        // PPSSPP: interpreter + high res + texture scaling
        if coreId.contains("ppsspp") {
            setDefaultOption("ppsspp_cpu_core", value: "Interpreter")
            setDefaultOption("ppsspp_internal_resolution", value: "1920x1088")
            setDefaultOption("ppsspp_texture_scaling_level", value: "5x")
            setDefaultOption("ppsspp_ignore_bad_memory_access", value: "enabled")
            setDefaultOption("ppsspp_fast_memory", value: "enabled")
            // Seed PSP flash0/font files into System/PSP/ — re-seeds on every launch for tvOS cache recovery.
            seedPSPFlash0Assets()
        }

        // Flycast (Dreamcast): default to NATIVE 1× across all iOS / tvOS
        // platforms.
        //
        // Why 1× instead of the retina-baseline upscale we ship for
        // other cores: flycast on iOS runs JITless (`flycast-jitless`)
        // because the App Store / iOS doesn't allow WX-protected JIT
        // pages for sideloaded apps. The interpreter path is *much*
        // slower than the JIT path, so any default >1× makes flycast
        // chug below 60fps for most users AND pushes Vulkan resource
        // allocations large enough to trip the `vk::DeviceLostError`
        // crash we hit on iPad + iPhone with higher defaults (see
        // crash log 2026-05-19: `IOGPUMetalError: Caused GPU Address
        // Fault Error` → `vk::DeviceLostError` thrown from inside the
        // core's own `vk::Device::waitForFences`).
        //
        // Native 1× = Dreamcast hardware resolution (640×480 + variants).
        // Users with newer iPads / Apple Silicon Macs who want the
        // upscale can bump it via Core Options. The TestFlight survey
        // suggested most users hadn't even discovered the option until
        // we told them about it — they were on the upstream "640x480"
        // libretro default anyway and didn't notice.
        //
        // `reicast_delay_frame_swapping=disabled` stays — bad on
        // mobile regardless of resolution.
        // `reicast_alpha_sorting=per-triangle` stays — JITless flycast
        // is CPU-bound, not pixel-fill-bound, so per-triangle alpha
        // sort isn't the dominant cost.
        //
        // `threaded_rendering=disabled` is enforced elsewhere
        // (PVThinLibretroFrontend.mm ~line 2587) for iOS VRAM-fault-
        // handler safety; we don't repeat it here.
        //
        // Note: libretro option key prefix is `reicast_*`, not
        // `flycast_*` (CORE_OPTION_NAME defined in upstream's
        // `shell/libretro/libretro_core_option_defines.h`).
        if coreId.contains("flycast") || coreId.contains("reicast") {
            setDefaultOption("reicast_internal_resolution", value: "640x480")
            setDefaultOption("reicast_delay_frame_swapping", value: "disabled")
            setDefaultOption("reicast_alpha_sorting", value: "per-triangle")
        }

        // For cores that need system files from the libretro buildbot,
        // migrate from the legacy RetroArch/system/ directory first (if it exists),
        // then download anything still missing from the buildbot.
        // Both operations are idempotent and the download is async (non-blocking).
        migrateRetroArchSystemDirectoryIfNeeded()
        downloadBuildBotSystemFilesIfNeeded()

        // Mupen64Plus-Next: use angrylion RDP, default pak1 to "memory" so games
        // that store saves on the Controller Pak (MK4, Tony Hawk Pro Skater,
        // Body Harvest, Hexen, etc.) work out of the box. Upstream libretro
        // default IS "memory"; we previously forced "rumble" here because the
        // libretro mupen64plus-next core only fires its rumble callback when
        // pak type is PLUGIN_RAW ("rumble"), but that broke any game that
        // expects a Controller Pak for saves. Saves are more critical than
        // rumble for unknown ROMs — users who want rumble can switch via the
        // pause-menu Core Options. Apply Transfer Pak slots after.
        if coreId.contains("mupen") {
            setDefaultOption("mupen64plus-rdp-plugin", value: "angrylion")
            setDefaultOption("mupen64plus-pak1", value: "memory")
            // Re-apply Transfer Pak slots populated by TransferPakStore before this call.
            // reapplyTransferPakSlots() sets pak types for all configured ports and writes
            // the global mupen64plus-transfer-pak-path exactly once (lowest port wins),
            // avoiding the iteration-order ambiguity of calling setTransferPakROM per port.
            if !_transferPakSlots.isEmpty {
                reapplyTransferPakSlots()
            }
        }

        // PrBoom: enable rumble
        if coreId.contains("prboom") {
            setDefaultOption("prboom-rumble", value: "enabled")
        }

        // Hatari: disable HD boot + copy hatari.cfg if needed + write dynamic TOS path
        if coreId.contains("hatari") || SystemIdentifier(rawValue: systemIdentifier ?? "") == .AtariST {
            setDefaultOption("hatari_boot_hd", value: "disabled")
            copyBundledConfigIfNeeded(resourceName: "hatari", extension: "cfg",
                                      toDirectory: self.BIOSPath, fileName: "hatari.cfg")
            // Rewrite szTosImageFileName to point to the actual TOS image in the BIOS directory.
            // The bundled hatari.cfg has a placeholder path that is wrong on iOS/tvOS.
            updateHatariTOSPath()
        }

        // VecX: use software renderer — hardware mode requires a full GL context
        // that PVThinLibretroFrontend doesn't negotiate properly, causing the
        // "starting emulator..." HUD to hang indefinitely (video_refresh never fires).
        if coreId.contains("vecx") {
            setDefaultOption("vecx_use_hw", value: "Software")
        }

        // MAME: enable config read/write, boot to BIOS, cheats
        if coreId.contains("mame") {
            setDefaultOption("mame_read_config", value: "enabled")
            setDefaultOption("mame_write_config", value: "enabled")
            setDefaultOption("mame_boot_to_bios", value: "enabled")
            setDefaultOption("mame_cheats_enable", value: "enabled")
        }

        // Beetle PSX HW: use OpenGL hardware renderer instead of Vulkan.
        // Vulkan via MoltenVK has command buffer submission races with Metal
        // presentation in the thin wrapper. OpenGL works (same path as Mupen64).
        if coreId.contains("psx_hw") || coreId.contains("beetle_psx") {
            setDefaultOption("beetle_psx_hw_renderer", value: "hardware")
            setDefaultOption("beetle_psx_hw_renderer_software_fb", value: "enabled")
        }
    }

    /// Copy a bundled config file to the system/BIOS directory if it doesn't already exist.
    private func copyBundledConfigIfNeeded(resourceName: String, extension ext: String,
                                            toDirectory dir: String?, fileName: String) {
        guard let dir = dir else { return }
        let destPath = (dir as NSString).appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: destPath) else { return }

        // Look in the main bundle and all framework bundles
        let bundles = [Bundle.main] + Bundle.allFrameworks
        for bundle in bundles {
            if let srcURL = bundle.url(forResource: resourceName, withExtension: ext) {
                do {
                    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: srcURL, to: URL(fileURLWithPath: destPath))
                    ILOG("ThinLibretroCore: copied \(fileName) to \(dir)")
                    return
                } catch {
                    WLOG("ThinLibretroCore: failed to copy \(fileName): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - PSP flash0 font seeding

    /// Seed PPSSPP flash0/font files into `System/PSP/font/`.
    ///
    /// Mirrors the logic in `PPSSPPGameCore.mm:loadFileAtPath:`.
    /// Re-seeds on every launch so tvOS Caches purges don't break PSP font rendering.
    /// The PSP system directory path is derived from `BIOSPath` using the same
    /// two-component strip used by `PVThinLibretroFrontend._systemSpecificDirectory`.
    /// Only `.pgf` files are copied — other resource types are left untouched.
    private func seedPSPFlash0Assets() {
        guard let biosPath = BIOSPath, !biosPath.isEmpty else {
            WLOG("ThinCore: PSP font seeding skipped — BIOSPath not set")
            return
        }
        // BIOSPath = <docs>/BIOS/<systemIdentifier> — strip two components to get <docs>
        let docsDir = URL(fileURLWithPath: biosPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        guard docsDir != "/" && !docsDir.isEmpty else { return }
        let pspSystemDir = URL(fileURLWithPath: docsDir)
            .appendingPathComponent("System/PSP")
            .path
        let fontDest = URL(fileURLWithPath: pspSystemDir)
            .appendingPathComponent("font")
            .path

        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: fontDest, withIntermediateDirectories: true)
        } catch {
            WLOG("ThinCore: could not create PSP font dir \(fontDest): \(error.localizedDescription)")
            return
        }

        // Search all framework bundles for flash0/font resource directory (same approach as PPSSPPGameCore.mm)
        let bundles = [Bundle.main] + Bundle.allFrameworks
        for bundle in bundles {
            guard let bundleResourceURL = bundle.resourceURL else { continue }
            let fontSrc = bundleResourceURL.appendingPathComponent("flash0/font").path
            guard fm.fileExists(atPath: fontSrc) else { continue }
            guard let fonts = try? fm.contentsOfDirectory(atPath: fontSrc) else { continue }
            let pgfFonts = fonts.filter { $0.lowercased().hasSuffix(".pgf") }
            guard !pgfFonts.isEmpty else {
                WLOG("ThinCore: flash0/font bundle dir found but contains no .pgf files: \(fontSrc)")
                continue
            }
            var seededCount = 0
            for font in pgfFonts {
                let src = URL(fileURLWithPath: fontSrc).appendingPathComponent(font).path
                let dst = URL(fileURLWithPath: fontDest).appendingPathComponent(font).path
                // Skip if already seeded — idempotent (tvOS Caches purge will clear fontDest, re-triggering copy).
                guard !fm.fileExists(atPath: dst) else { continue }
                do {
                    try fm.copyItem(atPath: src, toPath: dst)
                    seededCount += 1
                } catch {
                    WLOG("ThinCore: failed to copy PSP font \(font): \(error.localizedDescription)")
                }
            }
            if seededCount > 0 {
                ILOG("ThinCore: seeded \(seededCount) PSP .pgf font(s) from \(fontSrc) → \(fontDest)")
            } else {
                DLOG("ThinCore: PSP fonts already seeded in \(fontDest) (\(pgfFonts.count) files)")
            }
            return
        }
        WLOG("ThinCore: no flash0/font bundle directory found — PPSSPP may render without fonts")
    }

    // MARK: - Hatari TOS path configuration

    /// Search `BIOSPath` for a TOS image file and rewrite `szTosImageFileName` in hatari.cfg.
    ///
    /// The bundled `hatari.cfg` ships with empty fields; older copies may have Android
    /// placeholder paths (`/storage/...`).  This method finds the first TOS image in `BIOSPath`
    /// (searching `tos*.img`, `tos*.rom`, then any `.img`/`.rom`) and updates the cfg atomically.
    /// It also clears any `/storage/` Android paths still present in `szDiskAFileName` /
    /// `szDiskImageDirectory` from previously-copied configs.
    ///
    /// Called every launch (after `copyBundledConfigIfNeeded`) so a newly-added TOS image is
    /// picked up without requiring the user to delete hatari.cfg manually.
    private func updateHatariTOSPath() {
        guard let biosDir = BIOSPath, !biosDir.isEmpty else { return }
        let cfgPath = URL(fileURLWithPath: biosDir).appendingPathComponent("hatari.cfg").path
        guard FileManager.default.fileExists(atPath: cfgPath) else { return }

        let fm = FileManager.default
        let candidates = (try? fm.contentsOfDirectory(atPath: biosDir))?.sorted() ?? []

        let tosExtensions: Set<String> = ["img", "rom"]
        var tosPath: String?
        // 1. Prefer files whose name starts with "tos" (canonical naming)
        for file in candidates {
            let lower = file.lowercased()
            let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
            if tosExtensions.contains(ext) && lower.hasPrefix("tos") {
                tosPath = URL(fileURLWithPath: biosDir).appendingPathComponent(file).path
                break
            }
        }
        // 2. Fall back to any .img or .rom in the BIOS directory
        if tosPath == nil {
            for file in candidates {
                let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
                if tosExtensions.contains(ext) {
                    tosPath = URL(fileURLWithPath: biosDir).appendingPathComponent(file).path
                    break
                }
            }
        }

        if let tos = tosPath {
            // Validate TOS header to prevent Hatari crash.
            // When TOS is invalid, Reset_Cold() fails → Dialog_DoProperty() → input_gui()
            // calls null input_poll_cb → EXC_BAD_ACCESS.
            if let validationError = Self.validateTOSHeader(atPath: tos) {
                _hatariTOSError = validationError
                ELOG("ThinCore: TOS validation failed: \(validationError)")
            }
        } else {
            _hatariTOSError = "TOS ROM image not found. Place a valid tos.img file in the Atari ST BIOS folder (BIOS/com.provenance.atarist/)."
            WLOG("ThinCore: no TOS image found in \(biosDir) — Hatari will crash without TOS")
        }

        // Rewrite szTosImageFileName in hatari.cfg and clear any Android-placeholder paths.
        // Android /storage/ paths are cleared even if no TOS image is present (one-time migration).
        // Keys whose value must be cleared when it starts with "/storage/" (Android artifact).
        // szTosImageFileName is handled separately first so it can be set OR cleared.
        let androidPlaceholderKeys: Set<String> = ["szDiskAFileName", "szDiskImageDirectory"]
        guard let cfgContent = try? String(contentsOfFile: cfgPath, encoding: .utf8) else { return }
        var androidClearedKeys: [String] = []
        let updated = cfgContent.components(separatedBy: "\n").map { line -> String in
            let stripped = line.trimmingCharacters(in: .whitespaces)
            let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            // szTosImageFileName: set to the found image, or clear if it holds an Android path.
            if stripped.hasPrefix("szTosImageFileName") {
                if let tos = tosPath {
                    return "\(indent)szTosImageFileName = \(tos)"
                }
                // No TOS image found — clear any residual Android /storage/ placeholder.
                let parts = stripped.components(separatedBy: "=")
                if parts.count >= 2 {
                    let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if value.hasPrefix("/storage/") {
                        androidClearedKeys.append("szTosImageFileName")
                        return "\(indent)szTosImageFileName ="
                    }
                }
                return line
            }
            // Clear any other key whose value is an Android /storage/ path (one-time migration).
            for key in androidPlaceholderKeys where stripped.hasPrefix(key) {
                let parts = stripped.components(separatedBy: "=")
                if parts.count >= 2 {
                    let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if value.hasPrefix("/storage/") {
                        androidClearedKeys.append(key)
                        return "\(indent)\(key) ="
                    }
                }
            }
            return line
        }.joined(separator: "\n")

        // Skip the write if nothing actually changed (avoids spurious mtime updates).
        guard updated != cfgContent else { return }

        do {
            try updated.write(toFile: cfgPath, atomically: true, encoding: .utf8)
            if let tos = tosPath {
                ILOG("ThinCore: updated hatari.cfg → szTosImageFileName = \(tos)")
            }
            if !androidClearedKeys.isEmpty {
                ILOG("ThinCore: cleared Android placeholder path(s) in hatari.cfg: \(androidClearedKeys.joined(separator: ", "))")
            }
        } catch {
            WLOG("ThinCore: failed to update hatari.cfg TOS path: \(error.localizedDescription)")
        }
    }

    /// Validate a TOS image file header (mirrors hatari/src/tos.c logic).
    /// Returns nil on success, or a user-facing error string on failure.
    private static func validateTOSHeader(atPath path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else {
            return "Cannot read TOS ROM file."
        }
        guard data.count >= 16384 else {
            return "TOS ROM is too small (\(data.count) bytes). Expected at least 16 KB."
        }
        guard data.count <= 1024 * 1024 else {
            return "TOS ROM is too large (\(data.count) bytes). Expected at most 1 MB."
        }

        // RAM TOS loader header (magic 0x46FC2700) — Hatari handles these specially
        let firstWord = UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
        if firstWord == 0x46FC2700 { return nil }

        let tosVersion = UInt16(data[2]) << 8 | UInt16(data[3])
        let tosAddress = UInt32(data[8]) << 24 | UInt32(data[9]) << 16 | UInt32(data[10]) << 8 | UInt32(data[11])

        // TOS 0.00 boot ROM (16 KB)
        if tosVersion == 0x000 && data.count == 16384 { return nil }

        if tosVersion < 0x100 || tosVersion >= 0x500 {
            return String(format: "Invalid TOS ROM: version 0x%03X outside expected range (1.00-4.xx).", tosVersion)
        }
        if tosAddress != 0xE00000 && tosAddress != 0xFC0000 && tosAddress != 0xE80000 {
            return String(format: "Invalid TOS ROM: base address 0x%06X is not a known TOS ROM address.", tosAddress)
        }
        return nil
    }

    /// Set a core option only if it hasn't been set yet (preserves user overrides).
    private func setDefaultOption(_ key: String, value: String) {
        if _bridge.coreOptions[key] == nil {
            _bridge.setCoreOption(key, value: value)
        }
    }
}

// MARK: - CoreOptional

extension PVThinLibretroCore: CoreOptional {

    static var options: [CoreOption] {
        guard let instance = PVThinLibretroCore.current else {
            return []
        }
        return instance.buildOptions()
    }

    /// Build CoreOption models from the bridge's structured option metadata.
    /// Called by the options UI each time the screen appears, so it reflects
    /// the latest state (including visibility changes).
    func buildOptions() -> [CoreOption] {
        let definitions = _bridge.coreOptionDefinitions
        let categories = _bridge.coreOptionCategories
        let visibility = _bridge.coreOptionVisibility
        let currentValues = _bridge.coreOptions

        // Filter out hidden options
        let visibleDefs = definitions.filter { dict in
            guard let key = dict["key"] as? String else { return false }
            if let vis = visibility[key] {
                return vis.boolValue
            }
            return true // visible by default
        }

        // Build a category key -> [CoreOption] map
        var categorizedOptions: [String: [CoreOption]] = [:]
        var uncategorizedOptions: [CoreOption] = []

        for dict in visibleDefs {
            guard let option = coreOptionFromDictionary(dict, currentValues: currentValues) else {
                continue
            }
            if let categoryKey = dict["category"] as? String {
                categorizedOptions[categoryKey, default: []].append(option)
            } else {
                uncategorizedOptions.append(option)
            }
        }

        // Build category groups
        var result: [CoreOption] = []
        for catDict in categories {
            guard let catKey = catDict["key"] as? String,
                  let subOptions = categorizedOptions[catKey],
                  !subOptions.isEmpty else {
                continue
            }
            let catDesc = (catDict["desc"] as? String) ?? catKey
            let catInfo = catDict["info"] as? String
            let display = CoreOptionValueDisplay(
                title: catDesc,
                description: catInfo,
                requiresRestart: false
            )
            result.append(.group(display, subOptions: subOptions))
        }

        // Append uncategorized options at the top level
        result.append(contentsOf: uncategorizedOptions)

        DLOG("ThinLibretroCore: built \(result.count) top-level options (\(visibleDefs.count) visible of \(definitions.count) total)")
        return result
    }

    /// Convert a single NSDictionary option definition to a CoreOption.
    private func coreOptionFromDictionary(
        _ dict: [String: Any],
        currentValues: [String: String]
    ) -> CoreOption? {
        guard let key = dict["key"] as? String,
              let desc = dict["desc"] as? String else {
            return nil
        }
        let info = dict["info"] as? String
        let defaultValue = dict["default"] as? String ?? ""
        let valuesArray = dict["values"] as? [[String: String]] ?? []

        // desc = human-readable label (e.g. "Video Resolution")
        // info = longer help text (e.g. "Set the internal rendering resolution")
        // key = machine identifier (e.g. "flycast_video_resolution")
        let displayTitle = desc
        let descriptionText = info

        // Detect boolean options (exactly two values: enabled/disabled or on/off etc.)
        if valuesArray.count == 2 {
            let v0 = valuesArray[0]["value"]?.lowercased() ?? ""
            let v1 = valuesArray[1]["value"]?.lowercased() ?? ""
            let boolPairs: Set<Set<String>> = [
                ["enabled", "disabled"],
                ["on", "off"],
                ["true", "false"],
                ["yes", "no"],
                ["1", "0"]
            ]
            if boolPairs.contains(Set([v0, v1])) {
                let enabledValues: Set<String> = ["enabled", "on", "true", "yes", "1"]
                let defaultBool = enabledValues.contains(defaultValue.lowercased())
                let display = CoreOptionValueDisplay(
                    title: displayTitle,
                    description: descriptionText,
                    requiresRestart: false
                )
                let enabledStr = valuesArray[0]["value"] ?? "enabled"
                let disabledStr = valuesArray[1]["value"] ?? "disabled"
                let bridgeRef = _bridge
                return .bool(display, defaultValue: defaultBool) { @Sendable newValue in
                    let boolVal = (newValue as? Bool) ?? false
                    let stringVal = boolVal ? enabledStr : disabledStr
                    bridgeRef.setCoreOption(key, value: stringVal)
                }
            }
        }

        // Multi-value option (most common for libretro)
        let multiValues: [CoreOptionMultiValue] = valuesArray.map { entry in
            let val = entry["value"] ?? ""
            let label = entry["label"] ?? val
            let isDefault = (val == defaultValue)
            // Show human label as title, raw value as description (for debugging)
            return CoreOptionMultiValue(title: label, description: val, isDefault: isDefault)
        }

        let display = CoreOptionValueDisplay(
            title: key,
            description: descriptionText,
            requiresRestart: false
        )

        let bridgeRef = _bridge
        return .multi(display, values: multiValues) { @Sendable newValue in
            if let strVal = newValue as? String {
                bridgeRef.setCoreOption(key, value: strVal)
            } else if let intVal = newValue as? Int, intVal < valuesArray.count {
                let strVal = valuesArray[intVal]["value"] ?? ""
                bridgeRef.setCoreOption(key, value: strVal)
            }
        }
    }
}

// MARK: - PortDeviceConfigurable

extension PVThinLibretroCore: PortDeviceConfigurable {

    /// Authoritative per-platform max from the ObjC frontend.
    /// Avoids duplicating the THIN_MAX_PLAYERS preprocessor constant in Swift.
    private var thinMaxPlayers: Int { Int(PVThinLibretroFrontend.maxPlayers) }

    public var controllerPortDescriptors: [[PortDeviceDescriptor]] {
        // Clamp to thinMaxPlayers — ports beyond this cannot be tracked or restored.
        let portInfo = _bridge.controllerPortInfo.prefix(thinMaxPlayers)
        return portInfo.map { portTypes in
            portTypes.compactMap { dict -> PortDeviceDescriptor? in
                guard let name = dict["desc"] as? String,
                      let typeNum = dict["id"] as? NSNumber else { return nil }
                return PortDeviceDescriptor(name: name, deviceType: typeNum.uintValue)
            }
        }
    }

    public func currentDeviceType(forPort port: Int) -> UInt {
        guard port >= 0, port < thinMaxPlayers else { return LibretroDeviceType.joypad.rawValue }
        return UInt(_bridge.currentDeviceType(forPort: UInt32(port)))
    }

    public func setDeviceType(_ deviceType: UInt, forPort port: Int) {
        guard port >= 0, port < thinMaxPlayers else { return }
        _bridge.setControllerPortDevice(UInt32(deviceType), forPort: UInt32(port))
        // Persist selection per core + game combo
        let key = portDevicePersistenceKey(port: port)
        UserDefaults.standard.set(Int(deviceType), forKey: key)
    }

    /// Restore saved device type selections (called after core loads).
    func restorePortDeviceTypes() {
        // Clamp to thinMaxPlayers — _portDeviceTypes[] only has 4 entries.
        let portCount = min(_bridge.controllerPortInfo.count, thinMaxPlayers)
        for port in 0..<portCount {
            let key = portDevicePersistenceKey(port: port)
            if UserDefaults.standard.object(forKey: key) != nil {
                let saved = UInt(UserDefaults.standard.integer(forKey: key))
                _bridge.setControllerPortDevice(UInt32(saved), forPort: UInt32(port))
            } else {
                // Migration path: fall back to legacy per-game key (no core identifier)
                let legacyKey = legacyPortDevicePersistenceKey(port: port)
                if UserDefaults.standard.object(forKey: legacyKey) != nil {
                    let saved = UInt(UserDefaults.standard.integer(forKey: legacyKey))
                    _bridge.setControllerPortDevice(UInt32(saved), forPort: UInt32(port))
                    // Re-save under the new per-core/per-game key so future lookups hit the new namespace.
                    UserDefaults.standard.set(Int(saved), forKey: key)
                } else if let defaultDevice = platformDefaultPortDevice(forPort: port) {
                    // Apply system-specific device-type defaults when no user preference is saved.
                    // This runs AFTER retro_load_game so the core's SET_CONTROLLER_INFO has fired.
                    _bridge.setControllerPortDevice(UInt32(defaultDevice), forPort: UInt32(port))
                    ILOG("ThinLibretroCore: applied platform default device=\(defaultDevice) on port \(port)")
                }
            }
        }
    }

    /// Returns a platform-specific default device type for a port, or nil to use the core's own default.
    /// Called from `restorePortDeviceTypes()` only when no user preference has been saved for that port.
    private func platformDefaultPortDevice(forPort port: Int) -> UInt? {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return nil }
        // SNES: set port 2 (index 1) to RETRO_DEVICE_MOUSE for games that use the SNES Mouse peripheral.
        // Port 2 defaults to joypad after retro_load_game; override here for known mouse-only titles.
        // Delegates to MouseGameRegistry for consistent detection with gameSupportsMouse.
        // Users can always reconfigure via the in-game Port Device picker for any SNES game.
        if sysID == .SNES && port == 1 {
            if MouseGameRegistry.shared.gameSupportsMouse(
                systemIdentifier: sysID,
                md5: romMD5,
                title: romTitleForLookup
            ) {
                return LibretroDeviceType.mouse.rawValue
            }
        }
        // Dreamcast (Flycast): explicitly set port 0 device type so the core never silently
        // activates mouse input for standard games. For known mouse titles (Typing of the Dead,
        // Planet Ring, etc.) switch port 0 to RETRO_DEVICE_MOUSE so touch/pointer events reach
        // the Maple bus mouse peripheral. For all other games force RETRO_DEVICE_JOYPAD, which
        // overrides any Flycast core-option that might enable mouse by default.
        if sysID == .Dreamcast && port == 0 {
            if MouseGameRegistry.shared.gameSupportsMouse(
                systemIdentifier: sysID,
                md5: romMD5,
                title: romTitleForLookup
            ) {
                return LibretroDeviceType.mouse.rawValue // Flycast maps this to MDT_Mouse on Maple port A
            }
            return LibretroDeviceType.joypad.rawValue // prevent Flycast from defaulting to mouse
        }
        return nil
    }

    /// Best-effort title string for registry lookups.
    /// `romName` is not populated for thin-libretro cores, so fall back to
    /// the ROM filename (without extension) for title-pattern matching.
    var romTitleForLookup: String? {
        if let name = romName, !name.isEmpty { return name }
        guard let path = _bridge.romPath else { return nil }
        let base = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return base.isEmpty ? nil : base
    }

    /// New-style per-port key: <ClassName>.<md5>.<coreIdentifier>.portDeviceType.port<port>
    private func portDevicePersistenceKey(port: Int) -> String {
        // Key format matches CoreOptions+Serialization convention: <ClassName>.<md5>.<key>
        let md5 = PVThinLibretroCore.currentGameMD5 ?? "global"
        // Prefer the coreIdentifier from PVEmulatorCore if available; fall back to the dynamic type name.
        let coreIdentifierComponent: String
        if let identifier = (self as PVEmulatorCore).coreIdentifier, !identifier.isEmpty {
            coreIdentifierComponent = identifier
        } else {
            coreIdentifierComponent = String(describing: type(of: self))
        }
        return "PVThinLibretroCore.\(md5).\(coreIdentifierComponent).portDeviceType.port\(port)"
    }

    /// Legacy per-port key used before core identifiers were included (per-game only).
    /// Format: <ClassName>.<md5>.portDeviceType.port<port>
    private func legacyPortDevicePersistenceKey(port: Int) -> String {
        let md5 = PVThinLibretroCore.currentGameMD5 ?? "global"
        return "PVThinLibretroCore.\(md5).portDeviceType.port\(port)"
    }
}
