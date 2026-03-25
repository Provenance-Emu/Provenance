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

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, *)
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

    /// Stop observing and clear the frontend's destination cache (no-op output).
    /// Must be called on the main actor.
    @MainActor
    func stopMIDIDestinationObservation() {
        _midiDestinationCancellable = nil
        PVThinLibretroFrontend.setMIDIOutputEndpoints([])
        DLOG("ThinCore MIDI: stopped destination observation, cleared cache")
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
