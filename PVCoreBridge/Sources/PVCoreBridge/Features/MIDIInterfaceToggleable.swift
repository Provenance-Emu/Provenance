//
//  MIDIInterfaceToggleable.swift
//  PVCoreBridge
//
//  Lets the pause menu offer a MIDI on/off switch only for libretro cores that actually use MIDI.
//

import Foundation

/// A libretro-hosted core that can switch its MIDI I/O on and off from the pause menu.
///
/// The switch itself is the persisted `Defaults[.retroArchMIDIEnabled]` preference; the core applies it
/// to the `retro_midi_interface` it hands out (`input_enabled` / `output_enabled` / `read` / `write`).
/// UI should show the switch only when ``requestsMIDIInterface`` is `true`, since for any other core
/// the preference would change nothing.
public protocol MIDIInterfaceToggleable: AnyObject {
    /// `true` once the running core has asked the frontend for the libretro MIDI interface
    /// (`RETRO_ENVIRONMENT_GET_MIDI_INTERFACE`).
    var requestsMIDIInterface: Bool { get }
}
