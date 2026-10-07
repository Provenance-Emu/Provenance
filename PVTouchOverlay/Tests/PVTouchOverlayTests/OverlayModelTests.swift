import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Overlay model")
struct OverlayModelTests {
    @Test("Pad kind storage key is system.subtype.orientation")
    func padKindKey() {
        let kind = OverlayPadKind(system: .Genesis, subtype: "genesis-6btn")
        #expect(kind.storageKey(for: .landscape) == "com.provenance.genesis.genesis-6btn.landscape")
    }

    @Test("Standard pad kind uses the standard subtype")
    func standardKind() {
        #expect(OverlayPadKind.standard(.SNES).subtype == OverlayPadKind.standardSubtype)
    }

    @Test("Template round-trips through JSON")
    func templateCodable() throws {
        let a = OverlayInputID(system: .SNES, token: "a")
        let control = OverlayControl(id: "a", kind: .button(a), frame: CGRect(x: 0, y: 0, width: 56, height: 56),
                                     label: "A", shape: .circle, paletteSlot: .primary)
        let group = OverlayGroup(id: "face", controls: [control],
                                 placement: OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: 24, y: 40)))
        let template = OverlayTemplate(padKind: .standard(.SNES), orientation: .portrait, groups: [group], screenPolicy: .topBand)
        let data = try JSONEncoder().encode(template)
        let back = try JSONDecoder().decode(OverlayTemplate.self, from: data)
        #expect(back == template)
    }
}
