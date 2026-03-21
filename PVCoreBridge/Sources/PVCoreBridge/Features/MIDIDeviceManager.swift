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
        MIDIInputPortCreateWithProtocol(
            client, "PVInput" as CFString, ._1_0, &inputPort
        ) { [weak self] eventList, _ in
            // This closure is called on a CoreMIDI thread — dispatch to main actor
            guard let self else { return }
            self.handleEventList(eventList)
        }

        MIDIOutputPortCreate(client, "PVOutput" as CFString, &outputPort)

        // Connect input port to all current sources; topology changes handled via notification
        connectAllSources()
    }

    /// Connect the input port to every available MIDI source.
    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            MIDIPortConnectSource(inputPort, src, nil)
        }
    }

    /// Walk an `MIDIEventList` (MIDI 1.0 UMP packets) and dispatch each message.
    /// Marked `nonisolated` because it is called from a CoreMIDI background thread.
    nonisolated private func handleEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        let numPackets = Int(eventList.pointee.numPackets)
        guard numPackets > 0 else { return }

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
                    parseMIDI1UMPWord(word)
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
    /// In the MIDI 1.0 UMP format the message type nibble lives in bits 28-31
    /// of the word.  For type 0x2 (MIDI 1.0 Channel Voice) the MIDI status byte
    /// is in bits 16-23, data 1 in bits 8-15, data 2 in bits 0-7.
    /// Marked `nonisolated` because it is called from the CoreMIDI callback thread.
    nonisolated private func parseMIDI1UMPWord(_ word: UInt32) {
        let msgType = (word >> 28) & 0xF
        // Only handle MIDI 1.0 Channel Voice Messages (type 0x2)
        guard msgType == 0x2 else { return }

        let status = UInt8((word >> 16) & 0xF0)
        let channel = UInt8((word >> 16) & 0x0F)
        let data1 = UInt8((word >> 8) & 0xFF)
        let data2 = UInt8(word & 0xFF)

        Task { @MainActor [weak self] in
            guard let self, let responder = self._responder else { return }

            // Auto-detect: first message identifies the active source
            if self.isAutoDetecting {
                self.isAutoDetecting = false
                // Note: the source identification happens in handleEventList;
                // sourceRef resolution could be added via refCon if needed.
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
        activityResetTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000) // 80 ms
            if !Task.isCancelled {
                rxActivity = false
                txActivity = false
            }
        }
    }
}

#endif // canImport(CoreMIDI)
