#if OVERLAY_SNAPSHOT_HARNESS && os(iOS)
import CoreGraphics
import PVSystems
import SkinKit2Core
import XCTest
@testable import PVTouchOverlay

final class OverlayFormat2ResolverSnapshotTests: XCTestCase {
    func testSavedGameEditsResolveInFormat2() throws {
        guard !snapshotCandidates.isEmpty else { throw XCTSkip("This check needs generated skins") }
        let source = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
            .appendingPathComponent("com.provenance.nes/skin.json")
        let document = try Skin2Document.load(data: Data(contentsOf: source))
        let profile = try XCTUnwrap(Skin2TraitSet.all.first { $0.name == "iphone-edgeToEdge-portrait" })
        let insets = profile.safeArea
        let canvas = OverlayCanvas(size: CGSize(width: profile.size.width, height: profile.size.height),
                                   safeArea: OverlayInsets(top: insets.top, left: insets.left,
                                                          bottom: insets.bottom, right: insets.right))
        let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: .NES))
        let pad = OverlayPadKind(system: .NES, subtype: binding.defaultSubtype)
        let template = binding.template(padKind: pad, orientation: .portrait)
        let key = pad.storageKey(for: template.orientation)
        let face = GroupOverride(
            center: AnchoredCenter(h: .mid, x: 0, v: .mid, y: 100),
            scale: CGSize(width: 1.2, height: 0.8), opacity: 0.65,
            buttons: ["a": ControlOverride(offset: CGPoint(x: 10, y: 6), scale: 0.9)]
        )
        var file = OverlayLayoutFile.empty
        file.layouts[key] = ["face": .empty]
        file.games["example"] = [key: ["face": face]]
        let saved = try JSONEncoder().encode(file)
        let stored = try JSONDecoder().decode(OverlayLayoutFile.self, from: saved)
        let migration = OverlayFormat2Edits.project(template: template, canvas: canvas, layoutFile: stored,
                                                     gameMD5: "example", gameAspect: 4.0 / 3.0)
        XCTAssertNotNil(migration["face.a"])
        XCTAssertNotNil(migration["screen0"])
        let skinEdits = migration.mapValues { edit in
            Skin2Edit(offset: .init(x: edit.offset.x, y: edit.offset.y), opacity: edit.opacity.map { Double($0) },
                      hidden: edit.hidden, scaleX: edit.scale.width, scaleY: edit.scale.height)
        }
        let actual = Skin2Resolver.resolve(document, in: profile.environment, edits: skinEdits)
        let expected = OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                                    overrides: file.overrides(for: key, gameMD5: "example"),
                                                    gameAspect: 4.0 / 3.0)
        for group in expected.groups {
            for control in group.controls {
                let node = try XCTUnwrap(actual.node(id: "\(group.id).\(control.id)"))
                assertFrame(node.exactFrame, equals: control.frame)
                XCTAssertEqual(node.opacity, group.opacity, accuracy: 0.001)
            }
        }
        for (index, frame) in expected.screenFrames.enumerated() {
            let screen = try XCTUnwrap(actual.node(id: "screen\(index)"))
            assertFrame(screen.exactFrame, equals: frame)
        }
    }

    func testIndependentGroupEditsAcrossEveryPadAndProfile() throws {
        guard !snapshotCandidates.isEmpty else { throw XCTSkip("This check needs generated skins") }
        let root = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
        for system in SystemOverlayBindings.boundSystems {
            let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: system))
            let source = try Data(contentsOf: root.appendingPathComponent(system.rawValue + "/skin.json"))
            for subtype in binding.families.keys.sorted() {
                let pad = OverlayPadKind(system: system, subtype: subtype)
                let document = try Skin2Document.load(data: source, variant: subtype == binding.defaultSubtype ? nil : subtype)
                for profile in Skin2TraitSet.all {
                    try assertPadEdits(document, binding: binding, pad: pad, profile: profile)
                }
            }
        }
    }

    private func assertPadEdits(_ document: Skin2Document, binding: SystemOverlayBinding,
                                pad: OverlayPadKind, profile: Skin2TraitSet) throws {
        let insets = profile.safeArea
        let canvas = OverlayCanvas(size: CGSize(width: profile.size.width, height: profile.size.height),
                                   safeArea: OverlayInsets(top: insets.top, left: insets.left,
                                                          bottom: insets.bottom, right: insets.right))
        let orientation: OverlayOrientation = profile.orientation == .portrait ? .portrait : .landscape
        let template = binding.template(padKind: pad, orientation: orientation)
        let base = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0)
        let editable = try XCTUnwrap(base.groups.first { group in
            group.controls.contains { control in
                if case .button = control.control.kind { return true }
                return false
            }
        })
        let center = CGPoint(x: editable.frame.midX + 8, y: editable.frame.midY + 6)
        let override = GroupOverride(center: .make(center: center, in: canvas),
                                     scale: CGSize(width: 1.1, height: 0.85), opacity: 0.7, buttons: [:])
        let overrides = OverlayLayoutOverrides(groups: [editable.id: override])
        let projected = OverlayFormat2Edits.project(template: template, canvas: canvas, overrides: overrides, gameAspect: 4.0 / 3.0)
        let skinEdits = projected.mapValues { edit in
            Skin2Edit(offset: .init(x: edit.offset.x, y: edit.offset.y), opacity: edit.opacity.map { Double($0) },
                      hidden: edit.hidden, scaleX: edit.scale.width, scaleY: edit.scale.height)
        }
        let actual = Skin2Resolver.resolve(document, in: profile.environment, edits: skinEdits)
        let target = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: overrides, gameAspect: 4.0 / 3.0)
        let edited = try XCTUnwrap(target.groups.first { $0.id == editable.id })
        for control in edited.controls {
            let id = "\(edited.id).\(control.id)"
            let node = try XCTUnwrap(actual.node(id: id), "\(pad.system)/\(pad.subtype)/\(profile.name)/\(id)")
            assertFrame(node.exactFrame, equals: control.frame)
            XCTAssertEqual(node.opacity, edited.opacity, accuracy: 0.001)
        }
    }

    private func assertFrame(_ frame: Skin2Rect, equals rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(frame.x, rect.minX, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(frame.y, rect.minY, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(frame.width, rect.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(frame.height, rect.height, accuracy: 0.001, file: file, line: line)
    }
}
#endif
