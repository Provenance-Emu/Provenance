//
//  PVEmulatorCore+MIDI.swift
//  PVEmulatorCore
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Convenience properties forwarding MIDI capability queries from the app layer
//  to the emulator core bridge — following the same pattern as
//  `supportsVirtualKeyboard` / `supportsVirtualMouse`.
//

import Foundation
import PVCoreBridge

extension PVEmulatorCore {

    // MARK: MIDI capability forwarding

    /// Whether the loaded game/core supports MIDI peripherals.
    /// Forwards to `MIDIResponder.gameSupportsMIDI` when the bridge conforms;
    /// returns `false` otherwise.
    @objc open var supportsMIDI: Bool {
        (bridge as? MIDIResponder)?.gameSupportsMIDI ?? false
    }

    /// Whether the loaded game/core *requires* a MIDI device to function.
    /// Forwards to `MIDIResponder.requiresMIDI`; returns `false` when the
    /// bridge does not conform.
    @objc open var requiresMIDI: Bool {
        (bridge as? MIDIResponder)?.requiresMIDI ?? false
    }

    // MARK: MIDI routing

    /// Connect the `MIDIDeviceManager` singleton to this core so incoming MIDI
    /// messages are forwarded to the bridge.
    ///
    /// Call after the core is fully loaded and `supportsMIDI` returns `true`.
    /// Only available on platforms that ship CoreMIDI (iOS, tvOS, macOS).
    @objc open func attachMIDIResponder() {
#if canImport(CoreMIDI)
        guard #available(iOS 14.0, tvOS 14.0, macOS 11.0, macCatalyst 14.0, *) else { return }
        guard supportsMIDI, let responder = bridge as? MIDIResponder else { return }
        Task { @MainActor in
            MIDIDeviceManager.shared.setResponder(responder)
        }
#endif
    }

    /// Disconnect this core from the `MIDIDeviceManager` singleton.
    ///
    /// Call when stopping emulation so the manager does not dispatch to a
    /// deallocated bridge.
    @objc open func detachMIDIResponder() {
#if canImport(CoreMIDI)
        guard #available(iOS 14.0, tvOS 14.0, macOS 11.0, macCatalyst 14.0, *) else { return }
        Task { @MainActor in
            MIDIDeviceManager.shared.setResponder(nil)
        }
#endif
    }
}
