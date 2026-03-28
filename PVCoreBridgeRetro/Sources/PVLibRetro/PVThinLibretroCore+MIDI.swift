//
//  PVThinLibretroCore+MIDI.swift
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Observes MIDIDeviceManager.selectedDestinationIDs and routes changes to
//  PVThinLibretroFrontend so that thin libretro cores (e.g. DOSBox-Pure)
//  send MIDI output to the user-selected device rather than always using
//  the hardcoded first destination.
//
//  Threading: all observation and sync work runs on the @MainActor to match
//  MIDIDeviceManager's isolation domain. The ObjC class method
//  +setMIDIOutputEndpoints: is thread-safe and may be called from any thread.
//

import Combine
import Foundation
import PVCoreBridge
import PVLogging

#if canImport(CoreMIDI) && !os(tvOS)
import CoreMIDI

// MARK: - MIDI destination routing for thin libretro cores

extension PVThinLibretroCore {

    // MARK: Internal — called from PVThinLibretroCore.swift

    /// Begin observing `MIDIDeviceManager` and forwarding destination changes
    /// to `PVThinLibretroFrontend.setMIDIOutputEndpoints(_:)`.
    /// Must be called on the main actor.
    @MainActor
    func startMIDIDestinationObservation() {
        let manager = MIDIDeviceManager.shared
        // Initial sync so the frontend has the correct endpoints immediately.
        syncMIDIDestinations(manager: manager)
        // Observe future changes (either destination list or selection changes).
        _midiDestinationCancellable = manager.$selectedDestinationIDs
            .combineLatest(manager.$destinations)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.syncMIDIDestinations(manager: manager)
            }
        DLOG("ThinCore MIDI: started destination observation")
    }

    /// Stop observing further destination changes.
    /// Must be called on the main actor.
    ///
    /// Does NOT clear the frontend's destination cache: the shared retro_midi_interface
    /// (and its cache) is also used by the full RetroArch bridge (PVLibRetroCore).
    /// Clearing the cache here would force it to zero, disabling the legacy fallback
    /// (-1 = MIDIGetDestination(0)) for any subsequent libretro core that does not
    /// wire its own MIDIDeviceManager observer. No MIDI is sent while emulation is
    /// stopped, so leaving the cache intact is harmless; startMIDIDestinationObservation()
    /// will re-sync on the next session.
    @MainActor
    func stopMIDIDestinationObservation() {
        _midiDestinationCancellable = nil
        DLOG("ThinCore MIDI: stopped destination observation")
    }

    // MARK: Private

    /// Resolve the currently selected destinations to endpoint refs and push
    /// them to the thin frontend's thread-safe cache.
    @MainActor
    private func syncMIDIDestinations(manager: MIDIDeviceManager) {
        let selectedIDs = manager.selectedDestinationIDs
        let endpointRefs = manager.destinations
            .filter { selectedIDs.contains($0.id) }
            .map { NSNumber(value: UInt32($0.endpointRef)) }
        PVThinLibretroFrontend.setMIDIOutputEndpoints(endpointRefs)
        ILOG("ThinCore MIDI: synced \(endpointRefs.count) output destination(s) to thin frontend")
    }
}

#endif // canImport(CoreMIDI) && !os(tvOS)
