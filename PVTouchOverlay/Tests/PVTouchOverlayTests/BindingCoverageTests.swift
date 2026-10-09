import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Binding coverage")
struct BindingCoverageTests {
    /// Systems with no overlay binding yet. A system added to `SystemIdentifier` must either get a binding or
    /// be listed here on purpose, so this list shrinks as the console-style overlay batches land.
    static let unsupported: Set<SystemIdentifier> = [
        .AppleII, .Atari8bit, .AtariST, .C64, .CDi, .DOOM, .DOS, .Dreamcast, .EP128, .FDS, .GameGear, .Lynx,
        .Macintosh, .MasterSystem, .MegaDuck, .MSX, .MSX2, .NGP, .NGPC, .Odyssey2, .PalmOS, .PC98, .PCE, .PCECD,
        .PCFX, .PokemonMini, .PS2, .PS3, .PSP, .Quake, .Quake2, .Saturn, .SG1000, .SGFX, .Supervision, .TIC80,
        .Vectrex, .VirtualBoy, .Wolf3D, .WonderSwan, .WonderSwanColor, .ZXSpectrum, ._3DO,
        // Never launched with an overlay.
        .RetroArch, .Music, .Unknown
    ]

    @Test("Every system has a binding or is on the unsupported list, never both")
    func everySystemAccountedFor() {
        for system in SystemIdentifier.allCases {
            let bound = SystemOverlayBindings.binding(for: system) != nil
            let listed = Self.unsupported.contains(system)
            #expect(bound != listed, "\(system) is \(bound ? "bound and listed unsupported" : "neither bound nor listed")")
        }
    }

    @Test("boundSystems is exactly the set of systems with a binding")
    func boundSystemsMatchTable() {
        let withBinding = SystemIdentifier.allCases.filter { SystemOverlayBindings.binding(for: $0) != nil }
        #expect(Set(withBinding) == Set(SystemOverlayBindings.boundSystems))
        #expect(withBinding.count == SystemOverlayBindings.boundSystems.count)
    }
}
