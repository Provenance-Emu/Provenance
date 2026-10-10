//
//  ThinVFSDiskImagePolicyTests.swift
//  PVLibRetroTests
//
//  Covers when the thin VFS memory-maps files. MAME opens CHD files with
//  HINT_NONE, so extension-based mapping must fire without FREQUENT_ACCESS.
//

import Testing
@testable import PVCoreBridgeRetro

@Suite("ThinVFSDiskImagePolicy")
struct ThinVFSDiskImagePolicyTests {

    private let read = ThinVFSDiskImagePolicy.accessRead
    private let write = ThinVFSDiskImagePolicy.accessWrite
    private let frequent = ThinVFSDiskImagePolicy.hintFrequentAccess

    @Test("Recognizes CHD and other disk-image extensions")
    func recognizesDiskImageExtensions() {
        #expect(ThinVFSDiskImagePolicy.isDiskImagePath("/roms/gtfore01/gtfore01.chd"))
        #expect(ThinVFSDiskImagePolicy.isDiskImagePath("/roms/game.ISO"))
        #expect(ThinVFSDiskImagePolicy.isDiskImagePath("disk.HDD"))
        #expect(!ThinVFSDiskImagePolicy.isDiskImagePath("/roms/gtfore01.zip"))
        #expect(!ThinVFSDiskImagePolicy.isDiskImagePath("/save/state.svs"))
    }

    @Test("Maps read-only CHD without FREQUENT_ACCESS (MAME libretro_vfs path)")
    func mapsCHDWithoutFrequentHint() {
        #expect(ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/var/mobile/gtfore01.chd",
            mode: read,
            hints: 0,
            fileSize: 400 * 1024 * 1024
        ))
    }

    @Test("Maps any read-only file when FREQUENT_ACCESS is set (RetroArch parity)")
    func mapsFrequentAccessHint() {
        #expect(ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/tmp/big.bin",
            mode: read,
            hints: frequent,
            fileSize: 1024
        ))
    }

    @Test("Does not map writable opens, empty files, or ordinary ROMs")
    func rejectsNonMappedCases() {
        #expect(!ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/roms/game.chd",
            mode: read | write,
            hints: 0,
            fileSize: 1024
        ))
        #expect(!ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/roms/game.chd",
            mode: read,
            hints: 0,
            fileSize: 0
        ))
        #expect(!ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/roms/pacman.zip",
            mode: read,
            hints: 0,
            fileSize: 1024
        ))
        #expect(!ThinVFSDiskImagePolicy.shouldMemoryMap(
            path: "/roms/game.chd",
            mode: 0,
            hints: frequent,
            fileSize: 1024
        ))
    }

    @Test("C entry point matches Swift policy")
    func cdeclEntryPointMatches() {
        let path = "/roms/blitz2k/blitz2k.chd"
        path.withCString { cPath in
            #expect(pvThinVFSShouldMemoryMap(cPath, mode: read, hints: 0, fileSize: 1024))
            #expect(!pvThinVFSShouldMemoryMap(cPath, mode: write, hints: 0, fileSize: 1024))
        }
        #expect(!pvThinVFSShouldMemoryMap(nil, mode: read, hints: frequent, fileSize: 1024))
    }
}
