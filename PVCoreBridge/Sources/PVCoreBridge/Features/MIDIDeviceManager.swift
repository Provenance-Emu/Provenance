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

#if canImport(CoreMIDI) && !os(tvOS)
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
    /// Setting this disconnects all other sources and reconnects only the selected one
    /// (or all sources when set to nil, enabling auto-detect across every device).
    /// Changes are persisted to UserDefaults so the choice survives app restarts.
    @Published public var selectedSourceID: MIDIUniqueID? {
        didSet {
            if oldValue != selectedSourceID {
                reconnectSources()
                UserDefaults.standard.set(selectedSourceID.map { Int($0) }, forKey: Self.udKeySource)
            }
        }
    }

    /// Currently selected MIDI output destination (nil = none).
    /// Changes are persisted to UserDefaults so the choice survives app restarts.
    @Published public var selectedDestinationID: MIDIUniqueID? {
        didSet {
            if oldValue != selectedDestinationID {
                UserDefaults.standard.set(selectedDestinationID.map { Int($0) }, forKey: Self.udKeyDestination)
            }
        }
    }

    /// `true` while waiting for any incoming MIDI message to auto-select its source.
    @Published public private(set) var isAutoDetecting: Bool = false

    /// Pulses `true` briefly whenever MIDI data is received (drives RX indicator light).
    @Published public private(set) var rxActivity: Bool = false

    /// Pulses `true` briefly whenever MIDI data is sent (drives TX indicator light).
    @Published public private(set) var txActivity: Bool = false

    // MARK: - Parsed event value type

    /// Parsed MIDI 1.0 channel-voice event decoded from a single UMP word.
    /// Used to batch events from one `MIDIEventList` before hopping to the main actor.
    private enum ParsedMIDIEvent: Sendable {
        case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
        case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
        case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
        case programChange(channel: UInt8, program: UInt8)
        case pitchBend(channel: UInt8, value: Int16)
        case polyAftertouch(channel: UInt8, note: UInt8, pressure: UInt8)
        case channelAftertouch(channel: UInt8, pressure: UInt8)
    }

    // MARK: Private state

    private var client: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    private weak var _responder: (any MIDIResponder)?
    private var activityResetTask: Task<Void, Never>?

    // UserDefaults keys — mirrors the PVSettings `midiSourceUniqueID` / `midiDestinationUniqueID` keys
    // so `Defaults[.midiSourceUniqueID]` and MIDIDeviceManager both read/write the same value.
    private static let udKeySource = "midiSourceUniqueID"
    private static let udKeyDestination = "midiDestinationUniqueID"

    // MARK: Init

    private init() {
        setupMIDI()
        refreshEndpoints()
        restorePersistedSelection()
    }

    // MARK: Private helpers

    /// Restores the previously-persisted source/destination selection from UserDefaults.
    /// Called once during init, after `refreshEndpoints()` has populated `sources`/`destinations`.
    private func restorePersistedSelection() {
        if let raw = UserDefaults.standard.object(forKey: Self.udKeySource) as? Int {
            let id = MIDIUniqueID(raw)
            if sources.contains(where: { $0.id == id }) {
                selectedSourceID = id
            }
        }
        if let raw = UserDefaults.standard.object(forKey: Self.udKeyDestination) as? Int {
            let id = MIDIUniqueID(raw)
            if destinations.contains(where: { $0.id == id }) {
                selectedDestinationID = id
            }
        }
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

        // Build a MIDIPacketList in properly-aligned raw storage.
        // `[UInt8]` is only 1-byte aligned; MIDIPacketList may require 4-byte alignment
        // on some architectures, so we allocate using the type's native alignment.
        let listSize = MemoryLayout<MIDIPacketList>.size + data.count
        let rawPtr = UnsafeMutableRawPointer.allocate(
            byteCount: listSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { rawPtr.deallocate() }

        let listPtr = rawPtr.bindMemory(to: MIDIPacketList.self, capacity: 1)
        let packetPtr = MIDIPacketListInit(listPtr)

        var packetAdded = false
        data.withUnsafeBytes { dataBytes in
            guard let baseAddress = dataBytes.baseAddress else { return }
            let result = MIDIPacketListAdd(
                listPtr, listSize, packetPtr, 0,
                dataBytes.count,
                baseAddress.assumingMemoryBound(to: UInt8.self)
            )
            packetAdded = (result != nil)
        }
        guard packetAdded else { return }

        let sendStatus = MIDISend(outputPort, destInfo.endpointRef, listPtr)
        if sendStatus == noErr {
            pulseActivity(tx: true)
        }
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
    ///
    /// When `selectedSourceID` is set, only the matching source is connected;
    /// otherwise all available sources are connected (required for auto-detect).
    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }

            // If a source is already selected, connect only that source.
            if let selectedID = selectedSourceID {
                var uniqueID: MIDIUniqueID = 0
                guard MIDIObjectGetIntegerProperty(src, kMIDIPropertyUniqueID, &uniqueID) == noErr,
                      uniqueID == selectedID else { continue }
            }

            // Encode the endpoint ref as refCon for later identification
            let status = MIDIPortConnectSource(
                inputPort, src,
                UnsafeMutableRawPointer(bitPattern: UInt(src))
            )
            if status != noErr {
                // kMIDIObjectNotFound (-10817) is expected for already-connected sources;
                // log other errors for diagnostics.
                if status != kMIDIObjectNotFound {
                    assertionFailure("MIDIPortConnectSource failed for source \(src): \(status)")
                }
            }
        }
    }

    /// Disconnect all sources from the input port, then reconnect according to the
    /// current `selectedSourceID`.  Called whenever `selectedSourceID` changes so
    /// the port only receives events from the user's chosen device (or all devices
    /// when nil).
    private func reconnectSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            // Ignore errors: kMIDIObjectNotFound is expected for sources that were
            // never connected (e.g. filtered out on a prior selectedSourceID change).
            MIDIPortDisconnectSource(inputPort, src)
        }
        connectAllSources()
    }

    /// Walk an `MIDIEventList` (MIDI 1.0 UMP packets), decode all channel-voice
    /// events into a local array, then hop to the main actor **once** to dispatch
    /// them all.  This avoids spawning one `Task` per word under dense CC/note streams.
    ///
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

        // Decode all words on the CoreMIDI thread; collect into a value-type array.
        var events: [ParsedMIDIEvent] = []
        for _ in 0..<numPackets {
            let wordCount = Int(current.pointee.wordCount)
            withUnsafeBytes(of: current.pointee.words) { rawWords in
                let safeCount = min(wordCount, rawWords.count / 4)
                for i in 0..<safeCount {
                    let word = rawWords.load(fromByteOffset: i * 4, as: UInt32.self)
                    if let event = decodeMIDI1UMPWord(word) {
                        events.append(event)
                    }
                }
            }
            current = UnsafePointer(MIDIEventPacketNext(UnsafeMutablePointer(mutating: current)))
        }

        guard !events.isEmpty else { return }

        // Single main-actor hop for the entire event list.
        Task { @MainActor [weak self] in
            guard let self else { return }

            // Auto-detect: first message identifies its source
            if self.isAutoDetecting {
                if sourceUniqueID != 0 {
                    self.selectedSourceID = sourceUniqueID
                }
                self.isAutoDetecting = false
            } else if let selectedID = self.selectedSourceID,
                      sourceUniqueID != 0,
                      sourceUniqueID != selectedID {
                // Filter: discard events from sources other than the user's selection
                return
            }

            self.pulseActivity(rx: true)

            guard let responder = self._responder else { return }
            for event in events {
                self.dispatch(event, to: responder)
            }
        }
    }

    /// Decode a single 32-bit MIDI 1.0 UMP word into a `ParsedMIDIEvent`.
    ///
    /// Returns `nil` for UMP message types other than MIDI 1.0 Channel Voice (0x2),
    /// including Utility (0x0), System Common/Real-time (0x1), SysEx (0x3/0x5),
    /// and MIDI 2.0 Channel Voice (0x4).
    ///
    /// Marked `nonisolated` because it is called from the CoreMIDI callback thread.
    nonisolated private func decodeMIDI1UMPWord(_ word: UInt32) -> ParsedMIDIEvent? {
        let msgType = (word >> 28) & 0xF
        guard msgType == 0x2 else { return nil }

        let status  = UInt8((word >> 16) & 0xF0)
        let channel = UInt8((word >> 16) & 0x0F)
        let data1   = UInt8((word >> 8) & 0xFF)
        let data2   = UInt8(word & 0xFF)

        switch status {
        case 0x80: // Note Off
            return .noteOff(channel: channel, note: data1, velocity: data2)
        case 0x90: // Note On (velocity 0 = implicit Note Off)
            return data2 == 0
                ? .noteOff(channel: channel, note: data1, velocity: 0)
                : .noteOn(channel: channel, note: data1, velocity: data2)
        case 0xA0: // Polyphonic Aftertouch
            return .polyAftertouch(channel: channel, note: data1, pressure: data2)
        case 0xB0: // Control Change
            return .controlChange(channel: channel, controller: data1, value: data2)
        case 0xC0: // Program Change
            return .programChange(channel: channel, program: data1)
        case 0xD0: // Channel Aftertouch
            return .channelAftertouch(channel: channel, pressure: data1)
        case 0xE0: // Pitch Bend
            let lsb = Int16(data1)
            let msb = Int16(data2)
            return .pitchBend(channel: channel, value: ((msb << 7) | lsb) - 8192)
        default:
            return nil
        }
    }

    /// Dispatch a pre-decoded `ParsedMIDIEvent` to `responder`.
    /// Must be called on the main actor (same isolation as `MIDIDeviceManager`).
    private func dispatch(_ event: ParsedMIDIEvent, to responder: any MIDIResponder) {
        switch event {
        case .noteOn(let ch, let note, let vel):
            responder.midiNoteOn(channel: ch, note: note, velocity: vel)
        case .noteOff(let ch, let note, let vel):
            responder.midiNoteOff(channel: ch, note: note, velocity: vel)
        case .controlChange(let ch, let ctrl, let val):
            responder.midiControlChange?(channel: ch, controller: ctrl, value: val)
        case .programChange(let ch, let prog):
            responder.midiProgramChange?(channel: ch, program: prog)
        case .pitchBend(let ch, let val):
            responder.midiPitchBend?(channel: ch, value: val)
        case .polyAftertouch(let ch, let note, let pressure):
            responder.midiPolyAftertouch?(channel: ch, note: note, pressure: pressure)
        case .channelAftertouch(let ch, let pressure):
            responder.midiChannelAftertouch?(channel: ch, pressure: pressure)
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

#endif // canImport(CoreMIDI) && !os(tvOS)
