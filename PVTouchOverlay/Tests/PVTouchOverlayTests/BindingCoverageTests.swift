import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Binding coverage")
struct BindingCoverageTests {
    /// Systems with no overlay binding. A system added to `SystemIdentifier` must either get a binding or be
    /// listed here on purpose. After batch 3 every system with a shipping core is bound, so this is only the
    /// systems that are never launched with an overlay.
    static let unsupported: Set<SystemIdentifier> = [
        // A libretro launcher entry and the audio player: neither draws a game picture to put a pad under.
        .RetroArch, .Music,
        // The sentinel for a game whose system could not be identified.
        .Unknown
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
