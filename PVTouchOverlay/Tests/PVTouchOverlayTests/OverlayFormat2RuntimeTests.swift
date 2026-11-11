#if OVERLAY_RUNTIME_ART && os(iOS)
import CoreGraphics
import PVSettings
import PVSystems
import SkinKit2Core
import XCTest
@testable import PVTouchOverlay

final class OverlayFormat2RuntimeTests: XCTestCase {
    @MainActor
    func testSavedPerGameLayoutDrivesArtOnLiveCanvas() throws {
        let canvas = OverlayCanvas(size: CGSize(width: 480, height: 900),
                                   safeArea: .init(top: 56, left: 4, bottom: 33, right: 9))
        let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: .NES))
        let pad = OverlayPadKind(system: .NES, subtype: binding.defaultSubtype)
        let template = binding.template(padKind: pad, orientation: canvas.orientation)
        let key = pad.storageKey(for: canvas.orientation)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let override = GroupOverride(center: .make(center: CGPoint(x: 285, y: 710), in: canvas),
                                     scale: CGSize(width: 1.25, height: 0.85), opacity: 0.6,
                                     buttons: ["a": ControlOverride(offset: CGPoint(x: 20, y: -12), scale: 0.9)])
        let store = OverlayLayoutStore(fileURL: url)
        store.set(.init(groups: ["face": override]), for: key, gameMD5: "example")
        let before = try Data(contentsOf: url)
        let saved = OverlayLayoutStore(fileURL: url)
        let environment = Skin2Environment(size: .init(width: canvas.size.width, height: canvas.size.height),
                                           safeArea: .init(top: 56, left: 4, bottom: 33, right: 9))
        let directory = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
        for style in OverlayStyle.allCases {
            let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                                    overrides: saved.overrides(for: key, gameMD5: "example"), gameAspect: 16.0 / 9.0)
            let document = try XCTUnwrap(OverlayFormat2Sources.document(in: directory, pad: layout.padKind, binding: binding, style: style))
            let art = OverlayFormat2Artwork(document: document, layout: layout, environment: environment)
            let face = try XCTUnwrap(layout.groups.first { $0.id == "face" })
            let button = try XCTUnwrap(face.controls.first { $0.id == "a" })
            let control = try XCTUnwrap(art.control(button.id, in: face.id))
            for (artValue, touchValue) in zip(control.root.exactFrame.array,
                                              [button.frame.minX, button.frame.minY, button.frame.width, button.frame.height]) {
                XCTAssertEqual(artValue, touchValue, accuracy: 0.001)
            }
            XCTAssertEqual(face.opacity, 0.6, accuracy: 0.001)
            XCTAssertEqual(control.root.opacity, 1, "The host applies the saved opacity to the entire group")
            let screen = try XCTUnwrap(layout.screenFrames.first)
            XCTAssertEqual(screen.width / screen.height, 16.0 / 9.0, accuracy: 0.001)

            let pressed = OverlayFormat2ControlView.presentation(control, pressed: true, knobOffset: .zero)
            let fill = try XCTUnwrap(pressed.root.children.first { $0.node.type == .shape }?.node.fills.first)
            switch style {
            case .flat: XCTAssertEqual(fill.opacity, OverlayPressLook.flatPressedOpacity)
            case .outline: XCTAssertEqual(fill.opacity, OverlayPressLook.outlinePressedOpacity)
            case .glossy: XCTAssertEqual(fill.stops.first?.opacity, OverlayPressLook.glossyPressedTop)
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    @MainActor
    func testKeypadArtworkFollowsHostVisibility() throws {
        let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: .Atari5200))
        let pad = OverlayPadKind(system: .Atari5200, subtype: binding.defaultSubtype)
        let canvas = OverlayCanvas(size: CGSize(width: 480, height: 900), safeArea: .zero)
        let environment = Skin2Environment(size: .init(width: canvas.size.width, height: canvas.size.height))
        let directory = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
        let document = try XCTUnwrap(OverlayFormat2Sources.document(in: directory, pad: pad, binding: binding, style: .flat))
        let template = binding.template(padKind: pad, orientation: canvas.orientation)
        let hidden = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0)
        let shown = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0,
                                                shownToggles: [.keypad])
        let keypad = try XCTUnwrap(shown.groups.first { $0.group.toggledBy == .keypad })
        let hiddenArt = OverlayFormat2Artwork(document: document, layout: hidden, environment: environment)
        let shownArt = OverlayFormat2Artwork(document: document, layout: shown, environment: environment)
        XCTAssertFalse(keypad.controls.isEmpty)
        for key in keypad.controls {
            XCTAssertNil(hiddenArt.control(key.id, in: keypad.id))
            XCTAssertNotNil(shownArt.control(key.id, in: keypad.id))
        }
    }

    @MainActor
    func testThumbstickKnobUsesHostDisplacement() throws {
        let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: .N64))
        let pad = OverlayPadKind(system: .N64, subtype: binding.defaultSubtype)
        let canvas = OverlayCanvas(size: CGSize(width: 900, height: 480), safeArea: .zero)
        let template = binding.template(padKind: pad, orientation: canvas.orientation)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0)
        let directory = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
        let document = try XCTUnwrap(OverlayFormat2Sources.document(in: directory, pad: pad, binding: binding, style: .flat))
        let environment = Skin2Environment(size: .init(width: canvas.size.width, height: canvas.size.height))
        let artwork = OverlayFormat2Artwork(document: document, layout: layout, environment: environment)
        let stick = try XCTUnwrap(artwork.control("leftStick", in: "leftStick"))
        let before = try XCTUnwrap(stick.root.children.first { $0.node.role == .knob })
        let offset = CGSize(width: 8, height: -12)
        let moved = OverlayFormat2ControlView.presentation(stick, pressed: false, knobOffset: offset)
        let after = try XCTUnwrap(moved.root.children.first { $0.node.role == .knob })
        XCTAssertEqual(after.frame.x, before.frame.x + offset.width)
        XCTAssertEqual(after.frame.y, before.frame.y + offset.height)
        XCTAssertEqual(moved.root.frame, stick.root.frame)
    }
}
#endif
