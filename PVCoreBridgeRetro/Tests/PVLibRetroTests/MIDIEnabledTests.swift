//
//  MIDIEnabledTests.swift
//  PVLibRetroTests
//
//  The pause-menu MIDI toggle drives `+[PVThinLibretroFrontend setMIDIEnabled:]`. While it is off
//  the libretro MIDI interface must report input/output as disabled and drop all traffic
//  (see `struct retro_midi_interface` in libretro.h: the *_enabled callbacks return the current state).
//
//  The MIDI state is process-global, so the suite is serialized and always restores "enabled".
//

import Testing
@testable import PVCoreBridgeRetro

@Suite(.serialized)
struct MIDIEnabledTests {

    private func readByte(_ midi: retro_midi_interface) -> UInt8? {
        var byte: UInt8 = 0
        return midi.read(&byte) ? byte : nil
    }

    @Test func disabledInterfaceReportsNoInputOrOutput() {
        guard let iface = pv_libretro_midi_interface() else { return } // no CoreMIDI (tvOS)
        let midi = iface.pointee
        PVThinLibretroFrontend.setMIDIEnabled(false)
        defer { PVThinLibretroFrontend.setMIDIEnabled(true) }

        #expect(!midi.input_enabled())
        #expect(!midi.output_enabled())
    }

    @Test func disabledInterfaceDropsWritesAndInjectedInput() {
        guard let iface = pv_libretro_midi_interface() else { return }
        let midi = iface.pointee
        PVThinLibretroFrontend.setMIDIEnabled(false)
        defer { PVThinLibretroFrontend.setMIDIEnabled(true) }

        #expect(!midi.write(0x90, 0))
        pv_libretro_midi_inject_byte(0x90)
        #expect(readByte(midi) == nil)
    }

    @Test func enabledInterfaceDeliversInjectedInput() {
        guard let iface = pv_libretro_midi_interface() else { return }
        let midi = iface.pointee
        PVThinLibretroFrontend.setMIDIEnabled(true)

        pv_libretro_midi_inject_byte(0x90)
        pv_libretro_midi_inject_byte(0x3C)
        #expect(readByte(midi) == 0x90)
        #expect(readByte(midi) == 0x3C)
        #expect(readByte(midi) == nil)
    }

    @Test func disablingDiscardsBufferedInput() {
        guard let iface = pv_libretro_midi_interface() else { return }
        let midi = iface.pointee
        PVThinLibretroFrontend.setMIDIEnabled(true)

        pv_libretro_midi_inject_byte(0x80)
        PVThinLibretroFrontend.setMIDIEnabled(false)
        PVThinLibretroFrontend.setMIDIEnabled(true)

        // Bytes queued before the user switched MIDI off must not reappear when it comes back on.
        #expect(readByte(midi) == nil)
    }
}
