//
//  MIDIResponder.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Protocol for emulator cores that support MIDI peripheral input/output.
//
//  Classic systems with MIDI capabilities:
//  - Atari ST  — built-in MIDI In/Out (first consumer computer with MIDI standard ports)
//  - Sharp X68000 — external MIDI interface
//  - MSX/MSX2   — Music Module, MIDI Pak
//  - Amiga      — MIDI via serial port adapters
//  - DOS        — General MIDI, Roland MT-32, Sound Blaster MIDI Out
//  - PC-88/98   — MIDI board expansion
//  - Commodore 64 — MIDI cartridges (Sequential Circuits, etc.)
//
//  The `MIDIResponder` protocol sits alongside `KeyboardResponder` and
//  `MouseResponder` in the Controls.swift family, following identical patterns.
//
//  ## Core adoption:
//
//  ```swift
//  extension PVMyCore: MIDIResponder {
//      var gamesSupportsMIDI: Bool { true }
//      var requiresMIDI: Bool { false }
//
//      func midiNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
//          // Forward to emulated MIDI hardware
//      }
//      func midiNoteOff(channel: UInt8, note: UInt8, velocity: UInt8) { ... }
//      func midiControlChange(channel: UInt8, controller: UInt8, value: UInt8) { ... }
//      func midiProgramChange(channel: UInt8, program: UInt8) { ... }
//  }
//  ```
//

import Foundation

// MARK: - MIDIResponder

/// Protocol adopted by emulator core bridges that support MIDI peripheral
/// input (notes, control changes, clocks) and/or output (synthesiser data).
///
/// All methods are called on the core's run-loop thread.  Implementations
/// must **not** block; queue any heavy work and process it inside the core's
/// audio callback.
///
/// Implement the `@objc optional` methods only for the messages your core
/// actually handles — unfulfilled optional messages are silently discarded.
@objc public protocol MIDIResponder: AnyObject {

    // MARK: Capabilities

    /// Whether the loaded game/system supports MIDI peripherals.
    /// The UI uses this to show or hide the MIDI device picker.
    @objc var gamesSupportsMIDI: Bool { get }

    /// Whether the game/system *requires* a MIDI device to function correctly
    /// (e.g. a MIDI-only music application running on the emulated system).
    /// When `true`, the UI may prompt the user to connect a MIDI device
    /// before or immediately after launching the game.
    @objc var requiresMIDI: Bool { get }

    // MARK: Required — Note messages

    /// MIDI Note On received from an external device or the internal sequencer.
    /// - Parameters:
    ///   - channel: MIDI channel 0–15 (subtract 1 from display channel numbers).
    ///   - note: MIDI note number 0–127 (60 = middle C).
    ///   - velocity: Key velocity 0–127 (0 is equivalent to Note Off).
    @objc func midiNoteOn(channel: UInt8, note: UInt8, velocity: UInt8)

    /// MIDI Note Off received.
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - note: MIDI note number 0–127.
    ///   - velocity: Release velocity 0–127 (often ignored).
    @objc func midiNoteOff(channel: UInt8, note: UInt8, velocity: UInt8)

    // MARK: Optional — Control & Program

    /// Continuous controller / expression message.
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - controller: CC number 0–127 (e.g. 1 = mod wheel, 7 = volume, 64 = sustain pedal).
    ///   - value: Controller value 0–127.
    @objc optional func midiControlChange(channel: UInt8, controller: UInt8, value: UInt8)

    /// Program (patch/instrument) change.
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - program: Program number 0–127.
    @objc optional func midiProgramChange(channel: UInt8, program: UInt8)

    /// Pitch bend message.
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - value: 14-bit signed pitch bend value (-8192 … +8191; 0 = centre).
    @objc optional func midiPitchBend(channel: UInt8, value: Int16)

    /// Polyphonic aftertouch (key pressure).
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - note: Note number the pressure applies to.
    ///   - pressure: Pressure value 0–127.
    @objc optional func midiPolyAftertouch(channel: UInt8, note: UInt8, pressure: UInt8)

    /// Channel aftertouch (mono pressure — applies to all sounding notes on channel).
    /// - Parameters:
    ///   - channel: MIDI channel 0–15.
    ///   - pressure: Pressure value 0–127.
    @objc optional func midiChannelAftertouch(channel: UInt8, pressure: UInt8)

    // MARK: Optional — System messages

    /// MIDI System Exclusive received.  The `data` slice is the raw SysEx payload
    /// including the leading 0xF0 and trailing 0xF7 bytes.
    @objc optional func midiSystemExclusive(_ data: Data)

    /// MIDI Clock tick (0xF8) — called 24 times per quarter note when the
    /// external device is the clock master.
    @objc optional func midiClock()

    /// MIDI Start (0xFA) — external sequencer started playback.
    @objc optional func midiStart()

    /// MIDI Stop (0xFC) — external sequencer stopped.
    @objc optional func midiStop()

    /// MIDI Continue (0xFB) — external sequencer resumed playback.
    @objc optional func midiContinue()

    // MARK: Optional — Output

    /// Called by the core when it wants to *send* MIDI data to an external
    /// device (e.g. driving a Roland MT-32 from DOS software).
    /// The host (MIDIDeviceManager) registers a handler via
    /// `MIDIOutputHandler` and routes the raw bytes to the selected
    /// MIDI output endpoint.
    ///
    /// Cores that only consume MIDI input do not need to implement this.
    @objc optional func midiOutput(_ data: Data)
}

// MARK: - MIDIOutputHandler

/// Closure type for MIDI output data flowing *from* the emulated system
/// *to* an external device (e.g. MT-32, synthesiser).
public typealias MIDIOutputHandler = @Sendable (Data) -> Void
