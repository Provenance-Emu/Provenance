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
          arguments: [TwoButtonFamily.id, FourFaceFamily.id, ThreeFaceFamily.id, SixFaceFamily.id])
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

    @Test("Face buttons never overlap each other")
    func noOverlap() throws {
        let template = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: Self.canvases[0],
                                                 overrides: .empty, gameAspect: 4.0 / 3.0)
        let face = try #require(layout.groups.first { $0.id == "face" })
        for (index, first) in face.controls.enumerated() {
            for second in face.controls.dropFirst(index + 1) {
                #expect(!first.frame.intersects(second.frame), "\(first.id) overlaps \(second.id)")
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
}
