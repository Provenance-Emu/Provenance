import Foundation
import CoreGraphics

/// Projects legacy saved edits onto the control and screen IDs emitted by the format 2 exporter.
public enum OverlayFormat2Edits {
    public struct Edit: Equatable, Sendable {
        /// Center displacement in reference points.
        public let offset: CGPoint
        /// Independent size ratios applied about the node's center.
        public let scale: CGSize
        /// Multiplier for the exported node opacity, or nil when unchanged.
        public let opacity: CGFloat?
        /// A collapsed legacy frame has no art or touch area.
        public let hidden: Bool
    }

    /// Uses the same orientation key and per-game fallback as the original layout store.
    public static func project(template: OverlayTemplate, canvas: OverlayCanvas, layoutFile: OverlayLayoutFile,
                               gameMD5: String?, gameAspect: CGFloat, shownToggles: Set<OverlayAction> = []) -> [String: Edit] {
        guard layoutFile.version == OverlayLayoutFile.currentVersion else { return [:] }
        let key = template.padKind.storageKey(for: template.orientation)
        return project(template: template, canvas: canvas, overrides: layoutFile.overrides(for: key, gameMD5: gameMD5),
                       gameAspect: gameAspect, shownToggles: shownToggles)
    }

    /// Compares unedited and edited legacy geometry for the same canvas, aspect and visibility.
    /// The exported nodes must use that unedited geometry as their baseline.
    public static func project(template: OverlayTemplate, canvas: OverlayCanvas, overrides: OverlayLayoutOverrides,
                               gameAspect: CGFloat, shownToggles: Set<OverlayAction> = []) -> [String: Edit] {
        guard !overrides.groups.isEmpty else { return [:] }
        let base = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty,
                                               gameAspect: gameAspect, shownToggles: shownToggles)
        let target = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: overrides,
                                                 gameAspect: gameAspect, shownToggles: shownToggles)
        let unit = OverlayLayoutEngine.referenceScale(for: canvas)
        var edits: [String: Edit] = [:]
        // The resolver preserves template order and membership for a fixed set of toggles.
        for (baseGroup, targetGroup) in zip(base.groups, target.groups) {
            let opacity = baseGroup.opacity != targetGroup.opacity ? targetGroup.opacity / baseGroup.opacity : nil
            for (baseControl, targetControl) in zip(baseGroup.controls, targetGroup.controls) {
                edits["\(baseGroup.id).\(baseControl.id)"] = edit(from: baseControl.frame, to: targetControl.frame,
                                                                  unit: unit, opacity: opacity)
            }
        }
        for (index, frames) in zip(base.screenFrames, target.screenFrames).enumerated() {
            edits["screen\(index)"] = edit(from: frames.0, to: frames.1, unit: unit, opacity: nil)
        }
        return edits
    }

    private static func edit(from base: CGRect, to target: CGRect, unit: CGFloat, opacity: CGFloat?) -> Edit? {
        guard base != target || opacity != nil else { return nil }
        // SkinKit treats zero scales as identity. Hide a frame when the legacy planner collapses it.
        if target.isEmpty {
            return Edit(offset: .zero, scale: CGSize(width: 1, height: 1), opacity: opacity, hidden: true)
        }
        // An empty baseline that becomes visible needs a replacement frame.
        guard !base.isEmpty else { return nil }
        let offset = CGPoint(x: (target.midX - base.midX) / unit, y: (target.midY - base.midY) / unit)
        let scale = CGSize(width: target.width / base.width, height: target.height / base.height)
        return Edit(offset: offset, scale: scale, opacity: opacity, hidden: false)
    }
}
