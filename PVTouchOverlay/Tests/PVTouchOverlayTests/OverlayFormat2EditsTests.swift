import CoreGraphics
import Testing
@testable import PVTouchOverlay

@Suite("OverlayFormat2Edits")
struct OverlayFormat2EditsTests {
    private let canvas = OverlayCanvas(size: CGSize(width: 834, height: 1194),
                                       safeArea: OverlayInsets(top: 24, left: 10, bottom: 20, right: 10))
    private let pad = OverlayPadKind.standard(.DS)

    private func template(orientation: OverlayOrientation = .landscape) -> OverlayTemplate {
        let face = OverlayGroup(id: "face", controls: [
            OverlayControl(id: "a", kind: .action(.menu), frame: CGRect(x: 0, y: 0, width: 40, height: 40),
                           shape: .circle, paletteSlot: .primary),
            OverlayControl(id: "b", kind: .action(.menu), frame: CGRect(x: 50, y: 0, width: 40, height: 40),
                           shape: .circle, paletteSlot: .secondary)
        ], placement: OverlayPlacement(anchor: .bottomLeading), opacity: 0.8)
        let keypad = OverlayGroup(id: "keypad", controls: face.controls,
                                  placement: OverlayPlacement(anchor: .center), toggledBy: .keypad)
        let stylus = OverlayGroup(id: "stylus", controls: [
            OverlayControl(id: "touch", kind: .touchSurface(.dsScreen), frame: CGRect(x: 0, y: 0, width: 50, height: 50),
                           shape: .surface, paletteSlot: .utility)
        ], placement: OverlayPlacement(anchor: .center))
        return OverlayTemplate(padKind: pad, orientation: orientation, groups: [face, keypad, stylus],
                               screenPolicy: .dualStacked)
    }

    @Test func projectsResolvedControlsAndScreens() throws {
        let template = template()
        let overrides = OverlayLayoutOverrides(groups: ["face": GroupOverride(
            center: AnchoredCenter(h: .min, x: 3, v: .mid, y: 0), scale: CGSize(width: 1.5, height: 0.75),
            opacity: 0.4, buttons: ["a": ControlOverride(offset: CGPoint(x: 18, y: -12), scale: 1.25)]
        )])
        let edits = OverlayFormat2Edits.project(template: template, canvas: canvas, overrides: overrides, gameAspect: 1)
        let base = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 1)
        let target = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: overrides, gameAspect: 1)
        let unit = OverlayLayoutEngine.referenceScale(for: canvas)
        #expect(unit > 1)
        #expect(Set(edits.keys) == ["face.a", "face.b", "screen0", "screen1", "stylus.touch"])
        let editedButton = try #require(edits["face.a"])
        #expect(abs(editedButton.scale.width - 1.875) < 0.0001)
        #expect(abs(editedButton.scale.height - 0.9375) < 0.0001)

        for (original, edited) in zip(base.groups, target.groups) {
            for (control, targetControl) in zip(original.controls, edited.controls) {
                let edit = try #require(edits["\(original.id).\(control.id)"])
                expectFrame(control.frame, applying: edit, unit: unit, equals: targetControl.frame)
                #expect(abs(original.opacity * (edit.opacity ?? 1) - edited.opacity) < 0.0001)
            }
        }
        for (index, frames) in zip(base.screenFrames, target.screenFrames).enumerated() {
            let edit = try #require(edits["screen\(index)"])
            expectFrame(frames.0, applying: edit, unit: unit, equals: frames.1)
            #expect(edit.opacity == nil)
        }
    }

    @Test func usesTemplateOrientationAndPerGameReplacement() {
        let template = template()
        #expect(template.orientation != canvas.orientation)
        let key = pad.storageKey(for: template.orientation)
        let portraitKey = pad.storageKey(for: canvas.orientation)
        var file = OverlayLayoutFile.empty
        file.layouts[key] = ["face": GroupOverride(center: nil, scale: nil, opacity: 0.5, buttons: [:])]
        file.layouts[portraitKey] = ["face": GroupOverride(center: nil, scale: nil, opacity: 0.2, buttons: [:])]
        file.games["game"] = [key: ["keypad": GroupOverride(center: nil, scale: nil, opacity: 0.25, buttons: [:])]]
        file.games["reset"] = [key: [:]]

        let shared = OverlayFormat2Edits.project(template: template, canvas: canvas, layoutFile: file,
                                                 gameMD5: "other", gameAspect: 1)
        #expect(Set(shared.keys) == ["face.a", "face.b"])
        #expect(shared["face.a"]?.opacity == 0.5)
        let hidden = OverlayFormat2Edits.project(template: template, canvas: canvas, layoutFile: file,
                                                 gameMD5: "game", gameAspect: 1)
        #expect(hidden.isEmpty)
        let shown = OverlayFormat2Edits.project(template: template, canvas: canvas, layoutFile: file,
                                                gameMD5: "game", gameAspect: 1, shownToggles: [.keypad])
        #expect(Set(shown.keys) == ["keypad.a", "keypad.b"])
        #expect(shown["keypad.a"]?.opacity == 0.25)
        let reset = OverlayFormat2Edits.project(template: template, canvas: canvas, layoutFile: file,
                                                gameMD5: "reset", gameAspect: 1)
        #expect(reset.isEmpty)
    }

    @Test func hidesCollapsedScreen() throws {
        let template = template()
        let overrides = OverlayLayoutOverrides(groups: ["face": GroupOverride(
            center: AnchoredCenter(h: .mid, x: 0, v: .min, y: 0), scale: nil, opacity: nil, buttons: [:]
        )])
        let edits = OverlayFormat2Edits.project(template: template, canvas: canvas, overrides: overrides, gameAspect: 1)
        #expect(try #require(edits["screen0"]).hidden)
        #expect(try #require(edits["screen1"]).hidden)
    }

    private func expectFrame(_ frame: CGRect, applying edit: OverlayFormat2Edits.Edit,
                             unit: CGFloat, equals target: CGRect) {
        #expect(abs(frame.midX + edit.offset.x * unit - target.midX) < 0.0001)
        #expect(abs(frame.midY + edit.offset.y * unit - target.midY) < 0.0001)
        #expect(abs(frame.width * edit.scale.width - target.width) < 0.0001)
        #expect(abs(frame.height * edit.scale.height - target.height) < 0.0001)
    }
}
