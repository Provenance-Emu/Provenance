//
//  MIDIDeviceManager.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  CoreMIDI-backed singleton that discovers MIDI devices, routes incoming
//  messages to the active `MIDIResponder` core, and publishes live TX/RX
//  activity for status indicator lights in the MIDI picker UI.
//
//  CoreMIDI is not available on watchOS; the entire implementation is
//  conditionally compiled with `#if canImport(CoreMIDI)`.
//
//  Threading model:
//  - `@Published` properties are always mutated on the main actor.
//  - CoreMIDI callbacks arrive on a private MIDI thread; all state changes
//    are dispatched to the main actor via `Task { @MainActor in … }`.
//

import Foundation

#if canImport(CoreMIDI)
import CoreMIDI
import Combine

// MARK: - MIDIEndpointInfo

/// Lightweight value describing a CoreMIDI source or destination endpoint.
public struct MIDIEndpointInfo: Identifiable, Hashable, Sendable {
    public let id: MIDIUniqueID
    public let name: String
    public let endpointRef: MIDIEndpointRef

    public static func == (lhs: MIDIEndpointInfo, rhs: MIDIEndpointInfo) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - MIDIDeviceManager

/// Singleton that manages the CoreMIDI client, routes incoming messages to the
/// active `MIDIResponder`, and publishes live device lists and activity state
/// for the MIDI device picker UI.
///
/// Availability: iOS 14+, tvOS 14+, macOS 11+, macCatalyst 14+.
/// On watchOS the class is absent — use `#if canImport(CoreMIDI)` guards when
/// referencing it from cross-platform code.
@available(iOS 14.0, tvOS 14.0, macOS 11.0, macCatalyst 14.0, *)
@MainActor
public final class MIDIDeviceManager: ObservableObject {

    // MARK: Singleton

    public static let shared = MIDIDeviceManager()

    // MARK: Published state

    /// Available MIDI input sources (devices that send MIDI *to* Provenance).
    @Published public private(set) var sources: [MIDIEndpointInfo] = []

    /// Available MIDI output destinations (devices that receive MIDI *from* Provenance).
    @Published public private(set) var destinations: [MIDIEndpointInfo] = []

    /// Currently selected MIDI input source (nil = none).
    @Published public var selectedSourceID: MIDIUniqueID?

    /// Currently selected MIDI output destination (nil = none).
    @Published public var selectedDestinationID: MIDIUniqueID?

    /// `true` while waiting for any incoming MIDI message to auto-select its source.
    @Published public private(set) var isAutoDetecting: Bool = false

    /// Pulses `true` briefly whenever MIDI data is received (drives RX indicator light).
    @Published public private(set) var rxActivity: Bool = false

    /// Pulses `true` briefly whenever MIDI data is sent (drives TX indicator light).
    @Published public private(set) var txActivity: Bool = false

    // MARK: Private state

    private var client: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    private weak var _responder: (any MIDIResponder)?
    private var activityResetTask: Task<Void, Never>?

    // MARK: Init

    private init() {
        setupMIDI()
        refreshEndpoints()
    }

    // MARK: Public API

    /// Attach the currently-active core so incoming MIDI messages are forwarded to it.
    /// Pass `nil` to detach (e.g. when stopping emulation).
    public func setResponder(_ responder: (any MIDIResponder)?) {
        _responder = responder
    }

    /// Rebuild source / destination lists from the current CoreMIDI setup.
    /// Also reconnects the input port to any newly-discovered sources.
    /// Called automatically on init and whenever the MIDI graph changes.
    public func refreshEndpoints() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { endpointInfo(MIDIGetSource($0)) }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { endpointInfo(MIDIGetDestination($0)) }

        // Connect input port to all sources (idempotent for already-connected sources)
        connectAllSources()

        // Clear stale selections
        if let id = selectedSourceID, !sources.contains(where: { $0.id == id }) {
            selectedSourceID = nil
        }
        if let id = selectedDestinationID, !destinations.contains(where: { $0.id == id }) {
            selectedDestinationID = nil
        }
    }

    /// Begin listening for the next incoming MIDI message and automatically
    /// select its source endpoint.  Cancels any in-progress auto-detect first.
    public func startAutoDetect() {
        isAutoDetecting = true
    }

    /// Cancel auto-detect mode without selecting a device.
    public func cancelAutoDetect() {
        isAutoDetecting = false
    }

    /// Send raw MIDI 1.0 bytes to the currently selected output destination.
    ///
    /// - Parameter data: Raw MIDI bytes, e.g. `Data([0x90, 60, 100])` = Note On C4.
    public func send(_ data: Data) {
        guard !data.isEmpty,
              let destInfo = destinations.first(where: { $0.id == selectedDestinationID })
        else { return }

        // Build a MIDIPacketList on the stack via the MIDIPacketList API
        let listSize = MemoryLayout<MIDIPacketList>.size + data.count
        var rawStorage = [UInt8](repeating: 0, count: listSize)
        rawStorage.withUnsafeMutableBytes { rawPtr in
            let listPtr = rawPtr.bindMemory(to: MIDIPacketList.self).baseAddress!
            var packetPtr = MIDIPacketListInit(listPtr)
            data.withUnsafeBytes { dataBytes in
                _ = MIDIPacketListAdd(listPtr, listSize, packetPtr, 0,
                                      dataBytes.count,
                                      dataBytes.bindMemory(to: UInt8.self).baseAddress!)
            }
            MIDISend(outputPort, destInfo.endpointRef, listPtr)
        }
        pulseActivity(tx: true)
    }

    // MARK: Private — CoreMIDI setup

    private func setupMIDI() {
        // Create the client with a notification block for topology changes
        let status = MIDIClientCreateWithBlock("Provenance" as CFString, &client) { [weak self] notification in
            guard let self else { return }
            let msgID = notification.pointee.messageID
            guard msgID == .msgSetupChanged || msgID == .msgObjectAdded || msgID == .msgObjectRemoved else { return }
            Task { @MainActor [weak self] in
                self?.refreshEndpoints()
            }
        }
        guard status == noErr else { return }

        // Input port using the MIDI 1.0 protocol (iOS 14 / macOS 11 API)
        let inputStatus = MIDIInputPortCreateWithProtocol(
            client, "PVInput" as CFString, ._1_0, &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            // This closure is called on a CoreMIDI thread — dispatch to main actor
            guard let self else { return }
            // Decode the source endpoint ref passed as refCon by connectAllSources()
            let sourceRef: MIDIEndpointRef = srcConnRefCon.map {
                MIDIEndpointRef(UInt(bitPattern: $0))
            } ?? 0
            self.handleEventList(eventList, sourceRef: sourceRef)
        }
        guard inputStatus == noErr else {
            assertionFailure("MIDIInputPortCreateWithProtocol failed: \(inputStatus)")
            return
        }

        let outputStatus = MIDIOutputPortCreate(client, "PVOutput" as CFString, &outputPort)
        if outputStatus != noErr {
            assertionFailure("MIDIOutputPortCreate failed: \(outputStatus)")
        }

        // Connect input port to all current sources; topology changes handled via notification
        connectAllSources()
    }

    /// Connect the input port to MIDI sources.
    ///
    /// Each source is connected with its `MIDIEndpointRef` encoded as the
    /// `connRefCon` so the input callback can identify which device sent each
    /// event (used for auto-detect and per-source filtering).
    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            // Encode the endpoint ref as refCon for later identification
            MIDIPortConnectSource(inputPort, src, UnsafeMutableRawPointer(bitPattern: UInt(src)))
        }
    }

    /// Walk an `MIDIEventList` (MIDI 1.0 UMP packets) and dispatch each message.
    /// Marked `nonisolated` because it is called from a CoreMIDI background thread.
    ///
    /// - Parameters:
    ///   - eventList: Pointer to the incoming event list.
    ///   - sourceRef: The `MIDIEndpointRef` of the source that produced the list,
    ///     decoded from the `srcConnRefCon` registered in `connectAllSources()`.
    nonisolated private func handleEventList(
        _ eventList: UnsafePointer<MIDIEventList>,
        sourceRef: MIDIEndpointRef
    ) {
        let numPackets = Int(eventList.pointee.numPackets)
        guard numPackets > 0 else { return }

        // Look up the unique ID of the sending source (CoreMIDI property reads are thread-safe)
        var sourceUniqueID: MIDIUniqueID = 0
        if sourceRef != 0 {
            MIDIObjectGetIntegerProperty(sourceRef, kMIDIPropertyUniqueID, &sourceUniqueID)
        }

        // `MIDIEventList.packet` is the first element of a variable-length C array
        // embedded directly in the struct.  We obtain a pointer into the original
        // MIDIEventList buffer (not a copy) so MIDIEventPacketNext advances correctly.
        // MIDIEventList layout: protocol (UInt32) + numPackets (UInt32) = 8 bytes before first packet.
        let listRaw = UnsafeRawPointer(eventList)
        let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet) ?? 8
        var current = (listRaw + packetOffset).assumingMemoryBound(to: MIDIEventPacket.self)

        for _ in 0..<numPackets {
            let wordCount = Int(current.pointee.wordCount)
            // Access the words tuple as contiguous UInt32 storage
            withUnsafeBytes(of: current.pointee.words) { rawWords in
                let safeCount = min(wordCount, rawWords.count / 4)
                for i in 0..<safeCount {
                    let word = rawWords.load(fromByteOffset: i * 4, as: UInt32.self)
                    parseMIDI1UMPWord(word, sourceUniqueID: sourceUniqueID)
                }
            }
            current = MIDIEventPacketNext(current)
        }

        Task { @MainActor [weak self] in
            self?.pulseActivity(rx: true)
        }
    }

    /// Parse a single 32-bit MIDI 1.0 UMP word and dispatch to the responder.
    ///
    /// **Supported UMP message types:**
    /// - `0x2` — MIDI 1.0 Channel Voice (Note On/Off, CC, Program Change,
    ///   Aftertouch, Pitch Bend). Decoded and dispatched to `MIDIResponder`.
    ///
    /// **Not yet dispatched** (silently dropped):
    /// - `0x0` — Utility messages (clock, jitter reduction)
    /// - `0x1` — System Common / Real-time (MIDI Clock 0xF8, Start, Stop, Continue)
    /// - `0x3` — SysEx (64-bit)
    /// - `0x4` — MIDI 2.0 Channel Voice
    /// - `0x5` — Data messages (SysEx 128-bit)
    ///
    /// Marked `nonisolated` because it is called from the CoreMIDI callback thread.
    nonisolated private func parseMIDI1UMPWord(_ word: UInt32, sourceUniqueID: MIDIUniqueID) {
        let msgType = (word >> 28) & 0xF
        // Only handle MIDI 1.0 Channel Voice Messages (type 0x2)
        guard msgType == 0x2 else { return }

        let status = UInt8((word >> 16) & 0xF0)
        let channel = UInt8((word >> 16) & 0x0F)
        let data1 = UInt8((word >> 8) & 0xFF)
        let data2 = UInt8(word & 0xFF)

        Task { @MainActor [weak self] in
            guard let self, let responder = self._responder else { return }

            // Auto-detect: first message identifies and selects its source
            if self.isAutoDetecting {
                if sourceUniqueID != 0 {
                    self.selectedSourceID = sourceUniqueID
                }
                self.isAutoDetecting = false
                // Fall through and forward this first event to the responder
            } else if let selectedID = self.selectedSourceID,
                      sourceUniqueID != 0,
                      sourceUniqueID != selectedID {
                // Filter: discard events from sources other than the user's selection
                return
            }

            switch status {
            case 0x80: // Note Off
                responder.midiNoteOff(channel: channel, note: data1, velocity: data2)
            case 0x90: // Note On (velocity 0 = implicit Note Off)
                if data2 == 0 {
                    responder.midiNoteOff(channel: channel, note: data1, velocity: 0)
                } else {
                    responder.midiNoteOn(channel: channel, note: data1, velocity: data2)
                }
            case 0xA0: // Polyphonic Aftertouch
                responder.midiPolyAftertouch?(channel: channel, note: data1, pressure: data2)
            case 0xB0: // Control Change
                responder.midiControlChange?(channel: channel, controller: data1, value: data2)
            case 0xC0: // Program Change
                responder.midiProgramChange?(channel: channel, program: data1)
            case 0xD0: // Channel Aftertouch
                responder.midiChannelAftertouch?(channel: channel, pressure: data1)
            case 0xE0: // Pitch Bend
                let lsb = Int16(data1)
                let msb = Int16(data2)
                let bendValue = ((msb << 7) | lsb) - 8192
                responder.midiPitchBend?(channel: channel, value: bendValue)
            default:
                break
            }
        }
    }

    // MARK: Private — Helpers

    private func endpointInfo(_ ref: MIDIEndpointRef) -> MIDIEndpointInfo? {
        guard ref != 0 else { return nil }
        var uniqueID: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &uniqueID)
        var cfName: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &cfName)
        let name = cfName?.takeRetainedValue() as String? ?? "Unknown Device"
        return MIDIEndpointInfo(id: uniqueID, name: name, endpointRef: ref)
    }

    private func pulseActivity(rx: Bool = false, tx: Bool = false) {
        if rx { rxActivity = true }
        if tx { txActivity = true }
        activityResetTask?.cancel()
        activityResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000) // 80 ms
            guard !Task.isCancelled, let self else { return }
            self.rxActivity = false
            self.txActivity = false
        }
    }
}

#endif // canImport(CoreMIDI)
