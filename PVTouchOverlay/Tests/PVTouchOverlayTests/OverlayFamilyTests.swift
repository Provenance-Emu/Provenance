import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Pad families")
struct OverlayFamilyTests {
    static let canvases: [OverlayCanvas] = [
        OverlayLayoutEngineTests.phonePortrait, OverlayLayoutEngineTests.phoneLandscape,
        OverlayLayoutEngineTests.padLandscape,
        OverlayCanvas(size: CGSize(width: 375, height: 667), safeArea: .zero)     // no notch
    ]

    static let snes = SystemOverlayBinding(
        system: .SNES, families: [OverlayPadKind.standardSubtype: FourFaceFamily.self],
        defaultSubtype: OverlayPadKind.standardSubtype,
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .snes, hardwareSwitches: [])

    @Test("Every family resolves with all groups inside the canvas on every canvas",
          arguments: [TwoButtonFamily.id, FourFaceFamily.id, ThreeFaceFamily.id, SixFaceFamily.id,
                      N64Family.id, DigitalPadFamily.id, DualStickFamily.id])
    func groupsStayOnCanvas(familyID: String) throws {
        let family = try #require(OverlayFamilyRegistry.family(id: familyID))
        for canvas in Self.canvases {
            let template = family.template(binding: Self.snes, padKind: .standard(.SNES),
                                           orientation: canvas.orientation)
            let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                                     overrides: .empty, gameAspect: 4.0 / 3.0)
            for group in layout.groups {
                #expect(canvas.bounds.contains(group.frame), "\(familyID) \(group.id) off canvas on \(canvas.size)")
            }
            #expect(!layout.screenFrames.isEmpty)
            #expect(layout.screenFrames[0].width > 100)
        }
    }

    @Test("Face buttons never overlap each other", arguments: OverlayFamilyRegistry.all.map { $0.id })
    func noOverlap(familyID: String) throws {
        let family = try #require(OverlayFamilyRegistry.family(id: familyID))
        let template = family.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: Self.canvases[0],
                                                 overrides: .empty, gameAspect: 4.0 / 3.0)
        guard let face = layout.groups.first(where: { $0.id == "face" }) else { return }
        for (index, first) in face.controls.enumerated() {
            for second in face.controls.dropFirst(index + 1) {
                #expect(!first.frame.intersects(second.frame), "\(familyID) \(first.id) overlaps \(second.id)")
            }
        }
    }

    @Test("Four-face template binds SNES tokens")
    func tokens() {
        let template = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let ids = template.groups.flatMap(\.controls).compactMap { control -> String? in
            if case .button(let id) = control.kind { return id.token } else { return nil }
        }
        #expect(Set(ids).isSuperset(of: ["a", "b", "x", "y", "l", "r", "start", "select"]))
    }

    @Test("Portrait uses topBand and landscape uses centerColumn")
    func policies() {
        let portrait = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let landscape = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .landscape)
        #expect(portrait.screenPolicy == .topBand)
        #expect(landscape.screenPolicy == .centerColumn)
    }

    static let psx = SystemOverlayBinding(
        system: .PSX, families: ["psx-digital": DigitalPadFamily.self, "psx-dualshock": DualStickFamily.self],
        defaultSubtype: "psx-dualshock",
        tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1", .l2: "l2", .r2: "r2",
                 .l3: "l3", .r3: "r3", .start: "start", .select: "select"],
        labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L1", .r: "R1", .l2: "L2", .r2: "R2",
                 .start: "START", .select: "SELECT"],
        palette: .playStation, hardwareSwitches: [])

    @Test("Dual-stick adds two sticks below the pad; digital adds none")
    func sticks() {
        func stickCount(_ family: any OverlayFamily.Type) -> Int {
            let kind = OverlayPadKind(system: .PSX, subtype: "psx-dualshock")
            return family.template(binding: Self.psx, padKind: kind, orientation: .portrait)
                .groups.flatMap(\.controls).filter { if case .stick = $0.kind { return true } else { return false } }
                .count
        }
        #expect(stickCount(DualStickFamily.self) == 2)
        #expect(stickCount(DigitalPadFamily.self) == 0)
    }

    @Test("N64 has a left stick, a C cluster and a Z trigger")
    func n64() {
        let n64 = SystemOverlayBinding(
            system: .N64, families: [OverlayPadKind.standardSubtype: N64Family.self],
            defaultSubtype: OverlayPadKind.standardSubtype,
            tokens: [.a: "a", .b: "b", .z: "z", .l: "l", .r: "r", .start: "start",
                     .cUp: "cUp", .cDown: "cDown", .cLeft: "cLeft", .cRight: "cRight"],
            labels: [.a: "A", .b: "B", .z: "Z", .l: "L", .r: "R", .start: "START",
                     .cUp: "C▲", .cDown: "C▼", .cLeft: "C◀", .cRight: "C▶"],
            palette: .n64, hardwareSwitches: [])
        let template = N64Family.template(binding: n64, padKind: .standard(.N64), orientation: .portrait)
        let ids = Set(template.groups.flatMap(\.controls).map(\.id))
        #expect(ids.isSuperset(of: ["leftStick", "cUp", "cDown", "cLeft", "cRight", "z", "a", "b"]))
    }
}
