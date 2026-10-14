import Foundation
import Testing
import PVSystems
@testable import PVTouchOverlay

@Suite("Overlay multi-button touch")
struct OverlayMultiButtonTouchTests {
    static let groupScales: [CGFloat] = [0.5, 1, 2]
    /// Reported finger radii: none (floored), a typical thumb, and huge (capped).
    static let touchRadii: [CGFloat] = [0, 22, 1000]
    static let arcadeSystems: [SystemIdentifier] = [.MAME, .NeoGeo]

    static func arcadeLayout(_ system: SystemIdentifier, scale: CGFloat,
                             canvas: OverlayCanvas = OverlayLayoutEngineTests.phoneLandscape) throws -> OverlayLayout {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        let template = binding.template(padKind: .standard(system), orientation: canvas.orientation)
        let overrides = OverlayLayoutOverrides(groups: [
            ArcadeStickFamily.faceGroupID: GroupOverride(center: nil, scale: CGSize(width: scale, height: scale),
                                                         opacity: nil, buttons: [:])
        ])
        return OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: overrides, gameAspect: 4 / 3)
    }

    static func face(_ layout: OverlayLayout) throws -> [ResolvedControl] {
        try #require(layout.groups.first { $0.id == ArcadeStickFamily.faceGroupID }).controls
    }

    static func center(_ control: ResolvedControl) -> CGPoint { CGPoint(x: control.frame.midX, y: control.frame.midY) }

    static func hits(at point: CGPoint, radius: CGFloat, in controls: [ResolvedControl]) -> Set<OverlayHit> {
        var tracker = OverlayTouchTracker<Int>(controls: controls, multiButton: true)
        tracker.began(0, at: point, radius: radius)
        return tracker.hits()
    }

    @Test("A press on a button's centre presses only that button, at every size and finger radius")
    func centrePressIsAlone() throws {
        for system in Self.arcadeSystems {
            for scale in Self.groupScales {
                let controls = try Self.face(try Self.arcadeLayout(system, scale: scale))
                for control in controls {
                    for radius in Self.touchRadii {
                        let hits = Self.hits(at: Self.center(control), radius: radius, in: controls)
                        #expect(hits == [.control(id: control.id)],
                                "\(system) scale \(scale) radius \(radius): \(control.id) pressed \(hits)")
                    }
                }
            }
        }
    }

    @Test("A finger between two neighbouring buttons presses both, at every size and finger radius")
    func betweenPressesBoth() throws {
        for system in Self.arcadeSystems {
            for scale in Self.groupScales {
                let controls = try Self.face(try Self.arcadeLayout(system, scale: scale))
                // Same-row neighbours: equal midY, adjacent in x.
                let rows = Dictionary(grouping: controls) { $0.frame.midY }
                for row in rows.values {
                    let sorted = row.sorted { $0.frame.midX < $1.frame.midX }
                    for (left, right) in zip(sorted, sorted.dropFirst()) {
                        let between = CGPoint(x: (left.frame.midX + right.frame.midX) / 2, y: left.frame.midY)
                        for radius in Self.touchRadii {
                            let hits = Self.hits(at: between, radius: radius, in: controls)
                            #expect(hits == [.control(id: left.id), .control(id: right.id)],
                                    "\(system) scale \(scale) radius \(radius): \(left.id)|\(right.id) gave \(hits)")
                        }
                    }
                }
            }
        }
    }

    /// With the smallest contact (the clamp floor, so the same at every size). A real finger as wide as
    /// a shrunken button does cover its neighbour, and pressing both is then what multi-button touch is for.
    @Test("A press a fifth of the way towards a neighbour stays on its own button")
    func nearCentreStaysAlone() throws {
        for scale in Self.groupScales {
            let controls = try Self.face(try Self.arcadeLayout(.MAME, scale: scale))
            let byID = Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0) })
            let first = try #require(byID["a"]), second = try #require(byID["b"])
            let point = CGPoint(x: first.frame.midX + (second.frame.midX - first.frame.midX) * 0.2, y: first.frame.midY)
            #expect(Self.hits(at: point, radius: 0, in: controls) == [.control(id: "a")], "scale \(scale)")
        }
    }

    @Test("The contact radius is clamped to the button's size")
    func contactClamp() {
        #expect(OverlayMultiButtonTouch.contactRadius(0, buttonRadius: 34) == 20)
        #expect(OverlayMultiButtonTouch.contactRadius(1000, buttonRadius: 34) == 50)
        #expect(OverlayMultiButtonTouch.contactRadius(30, buttonRadius: 34) == 30)
    }

    @Test("Core distance is the centre distance for a circle and the centre-line distance for a pill")
    func coreDistance() {
        let circle = CGRect(x: 0, y: 0, width: 40, height: 40)
        #expect(OverlayMultiButtonTouch.coreDistance(from: CGPoint(x: 50, y: 20), to: circle) == 30)
        let pill = CGRect(x: 0, y: 0, width: 70, height: 30)
        #expect(OverlayMultiButtonTouch.coreDistance(from: CGPoint(x: 35, y: 45), to: pill) == 30)
        #expect(OverlayMultiButtonTouch.coreDistance(from: CGPoint(x: 20, y: 15), to: pill) == 0)
    }

    @Test("Only an arcade panel's face buttons use multi-button touch, and only with the setting on")
    func scope() {
        #expect(OverlayMultiButtonTouch.applies(toGroup: ArcadeStickFamily.faceGroupID,
                                                familyID: ArcadeStickFamily.id, arcadeEnabled: true))
        #expect(!OverlayMultiButtonTouch.applies(toGroup: ArcadeStickFamily.faceGroupID,
                                                 familyID: ArcadeStickFamily.id, arcadeEnabled: false))
        #expect(!OverlayMultiButtonTouch.applies(toGroup: "system", familyID: ArcadeStickFamily.id, arcadeEnabled: true))
        #expect(!OverlayMultiButtonTouch.applies(toGroup: "face", familyID: FourFaceFamily.id, arcadeEnabled: true))
    }

    /// Mirrors iFly's `ControllerScaleHitTestTests`: a resized group keeps touch hit-testing aligned with
    /// what is drawn. Provenance resolves frames in canvas points instead of transforming a view, so the
    /// check is on the resolved frames.
    @Test("A scaled group draws at the scaled size and a touch at its visual edge hits it")
    func scaledGroupHitTest() throws {
        let unit = OverlayLayoutEngine.referenceScale(for: OverlayLayoutEngineTests.phoneLandscape)
        let designed = try #require(
            SystemOverlayBindings.binding(for: .MAME)?.template(padKind: .standard(.MAME), orientation: .landscape)
                .groups.first { $0.id == ArcadeStickFamily.faceGroupID }?.controls.first { $0.id == "a" })
        let controls = try Self.face(try Self.arcadeLayout(.MAME, scale: 2))
        let button = try #require(controls.first { $0.id == "a" })

        // 1. On screen it occupies the scaled footprint.
        #expect(abs(button.frame.width - designed.frame.width * unit * 2) < 0.5)

        // 2. A touch just inside the visual right edge presses it, in both modes.
        let edge = CGPoint(x: button.frame.maxX - 1, y: button.frame.midY)
        for multiButton in [false, true] {
            var tracker = OverlayTouchTracker<Int>(controls: controls, multiButton: multiButton)
            tracker.began(0, at: edge, radius: 0)
            #expect(tracker.hits().contains(.control(id: "a")), "multi: \(multiButton)")
        }

        // 3. The multi-button reach scales with the button: twice the size, twice the reach.
        let small = try #require(try Self.face(try Self.arcadeLayout(.MAME, scale: 1)).first { $0.id == "a" })
        let bigRadius = OverlayMultiButtonTouch.radius(of: button.frame)
        let smallRadius = OverlayMultiButtonTouch.radius(of: small.frame)
        let reachBig = bigRadius + OverlayMultiButtonTouch.contactRadius(0, buttonRadius: bigRadius)
        let reachSmall = smallRadius + OverlayMultiButtonTouch.contactRadius(0, buttonRadius: smallRadius)
        #expect(abs(reachBig - reachSmall * 2) < 0.5)
    }
}
