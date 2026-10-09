import Foundation
@testable import PVTouchOverlay

/// Shared resolve-and-check helpers for the family and binding tests.
enum OverlayTestSupport {
    static let canvases = OverlayFamilyTests.canvases

    static func resolve(_ template: OverlayTemplate, on canvas: OverlayCanvas,
                        shownToggles: Set<OverlayAction> = []) -> OverlayLayout {
        OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty,
                                    gameAspect: 4.0 / 3.0, shownToggles: shownToggles)
    }

    /// Every pair of solid controls from the layout that overlap, as "group/control" names.
    static func overlaps(in layout: OverlayLayout) -> [String] {
        let solid = layout.groups.flatMap { group in
            group.controls.filter { !OverlayScreenPlanner.isTouchSurface($0.control.kind) }
                .map { (group: group.id, control: $0) }
        }
        var found: [String] = []
        for (index, first) in solid.enumerated() {
            for second in solid.dropFirst(index + 1) where first.control.frame.intersects(second.control.frame) {
                found.append("\(first.group)/\(first.control.id) x \(second.group)/\(second.control.id)")
            }
        }
        return found
    }

    /// Group ids whose frame leaves the canvas.
    static func offCanvas(_ layout: OverlayLayout, canvas: OverlayCanvas) -> [String] {
        layout.groups.filter { !canvas.bounds.contains($0.frame) }.map(\.id)
    }

    static func controlIDs(_ template: OverlayTemplate) -> Set<String> {
        Set(template.groups.flatMap(\.controls).map(\.id))
    }
}
