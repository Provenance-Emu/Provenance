#if canImport(UIKit)
import CoreGraphics
import Foundation
import PVSettings
import SkinKit2Core
import SkinKit2Render
import SwiftUI

/// Bundled Format 2 art mounted on the live control frames. Provenance owns the layout and touch
/// dispatch, including overlapping hit areas, core-specific surfaces and the existing layout store.
struct OverlayFormat2Artwork {
    private let resolution: Skin2Resolution
    private let controls: [String: Skin2ResolvedNode]

    init(document: Skin2Document, layout: OverlayLayout, environment: Skin2Environment) {
        let resolver = Skin2Resolver(document: document, environment: environment)
        let authored = Dictionary(document.root.children.compactMap { node in node.id.map { ($0, node) } },
                                  uniquingKeysWith: { first, _ in first })
        var live = document
        // Frames, stroke widths and text sizes below are in physical points.
        live.reference = Skin2Reference(shortSide: 390, minScale: 1, maxScale: 1)
        live.root.children = layout.groups.flatMap { group in
            group.controls.compactMap { control in
                let id = "\(group.id).\(control.id)"
                guard !control.frame.isEmpty, let source = authored[id], source.type == .control,
                      source.kind != .touchSurface else { return nil }
                var node = resolver.effective(source)
                node.layout = Self.frame(control.frame)
                node.visible = nil
                node.opacity = nil // The host composites opacity once for the whole group.
                node.children = Self.children(of: node, resolver: resolver, control: control)
                return node.children.isEmpty ? nil : node
            }
        }
        let resolved = Skin2Resolver.resolve(live, in: environment)
        resolution = resolved
        controls = Dictionary(resolved.controls.compactMap { node in node.id.map { ($0, Self.liveFrames(node)) } },
                              uniquingKeysWith: { first, _ in first })
    }

    func control(_ id: String, in group: String) -> Skin2Resolution? {
        guard let node = controls["\(group).\(id)"] else { return nil }
        var art = resolution
        art.root = node
        return art
    }

    private static func liveFrames(_ resolved: Skin2ResolvedNode) -> Skin2ResolvedNode {
        // The host positions each Canvas at the live control origin. Keep the art in that
        // coordinate space so bake rounding does not move a rim or label away from its touch target.
        var resolved = resolved
        resolved.frame = resolved.exactFrame
        resolved.children = resolved.children.map(liveFrames)
        return resolved
    }

    private static func children(of node: Skin2Node, resolver: Skin2Resolver, control: ResolvedControl) -> [Skin2Node] {
        var art = node.children.compactMap { child -> Skin2Node? in
            guard child.type != .text else { return nil }
            var child = resolver.effective(child)
            guard resolver.isVisible(child) else { return nil }
            child.visible = nil
            if child.role != .knob {
                for index in child.strokes.indices {
                    child.strokes[index].width = .pt(resolver.document.theme == "outline" ? OverlayPressLook.outlineWidth : OverlayPressLook.rimWidth)
                }
                if control.control.shape == .cross {
                    fitCross(&child, size: control.frame.size)
                }
            }
            return child
        }
        if let label = control.control.label, let prototype = node.children.first(where: { $0.type == .text }) {
            art.append(contentsOf: labels(prototype, text: label, control: control))
        }
        return art
    }

    private static func labels(_ prototype: Skin2Node, text: String, control: ResolvedControl) -> [Skin2Node] {
        let size = control.frame.size
        let fontSize = min(size.height * OverlayPressLook.labelHeightFraction, OverlayPressLook.maxLabelSize)
        let padding = OverlayPressLook.labelPadding
        var label = prototype
        label.visible = nil
        label.font?.size = .pt(fontSize)
        label.text = text
        label.align = .center
        label.layout = Skin2Layout(inset: .init(uniform: .pt(padding)))
        // Match the bake's two leading-aligned lines when the Wolfenstein face label is too wide.
        guard control.control.shape == .circle, text == "OPEN", size.width - 2 * padding < fontSize * 2.8 else { return [label] }
        let lineHeight = fontSize * 1.2
        let lineWidth = fontSize * 1.9
        let x = (size.width - lineWidth) / 2
        label.align = .leading
        return ["OPE", "N"].enumerated().map { index, text in
            var line = label
            line.text = text
            line.layout = frame(CGRect(x: x, y: size.height / 2 + CGFloat(index - 1) * lineHeight, width: lineWidth, height: lineHeight))
            return line
        }
    }

    private static func frame(_ rect: CGRect) -> Skin2Layout {
        Skin2Layout(frame: [rect.minX, rect.minY, rect.width, rect.height].map { .pt($0) })
    }

    private static func fitCross(_ node: inout Skin2Node, size: CGSize) {
        // The reference cross path's corners would stretch when a saved edit changes its aspect.
        guard node.shape?.kind == .path else { return }
        let rect = CGRect(origin: .zero, size: size)
        let path = OverlayShapePath.path(.cross, in: rect).cgPath
        var commands = [String]()
        path.applyWithBlock { element in
            let points = element.pointee.points
            func point(_ index: Int) -> String { "\(points[index].x) \(points[index].y)" }
            switch element.pointee.type {
            case .moveToPoint: commands.append("M \(point(0))")
            case .addLineToPoint: commands.append("L \(point(0))")
            case .addQuadCurveToPoint: commands.append("Q \(point(0)) \(point(1))")
            case .addCurveToPoint: commands.append("C \(point(0)) \(point(1)) \(point(2))")
            case .closeSubpath: commands.append("Z")
            @unknown default: break
            }
        }
        node.shape?.d = commands.joined(separator: " ")
        let bounds = rect.union(path.boundingBoxOfPath)
        node.shape?.box = [bounds.minX, bounds.minY, bounds.width, bounds.height]
        if bounds != rect { node.layout = frame(bounds) }
    }
}

@MainActor
enum OverlayFormat2Sources {
    private final class Box {
        let document: Skin2Document
        init(_ document: Skin2Document) { self.document = document }
    }

    private static let documents: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 12
        return cache
    }()

    static func document(in directory: URL, pad: OverlayPadKind, binding: SystemOverlayBinding, style: OverlayStyle) -> Skin2Document? {
        let url = directory.appendingPathComponent(pad.system.rawValue).appendingPathExtension("json")
        let theme = style == .flat ? nil : style.rawValue
        let variant = pad.subtype == binding.defaultSubtype ? nil : pad.subtype
        let key = "\(url.path)|\(variant ?? "")|\(theme ?? "")" as NSString
        if let cached = documents.object(forKey: key) { return cached.document }
        guard let data = try? Data(contentsOf: url),
              let document = try? Skin2Document.load(data: data, theme: theme, variant: variant),
              SkinKit2Render.supports(document.requires) else { return nil }
        documents.setObject(Box(document), forKey: key)
        return document
    }
}

/// A control draws only its own art and observes its own pressed/knob state. The pad's UIKit
/// touch layers and the screen viewport never take input or geometry from this canvas.
struct OverlayFormat2ControlView: View {
    let art: Skin2Resolution
    let frame: CGRect
    let pressed: Bool
    let knob: OverlayKnobState?

    var body: some View {
        let art = Self.presentation(art, pressed: pressed, knobOffset: knob?.offset ?? .zero)
        let bounds = art.root.children.reduce(frame) { bounds, child in
            let childFrame = child.frame
            return bounds.union(CGRect(x: childFrame.x, y: childFrame.y, width: childFrame.width, height: childFrame.height))
        }
        .insetBy(dx: -2, dy: -2)
        Canvas { context, _ in
            context.withCGContext { cg in
                cg.translateBy(x: -bounds.minX, y: -bounds.minY)
                Skin2Renderer.draw(art, in: cg)
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .offset(x: bounds.minX - frame.minX, y: bounds.minY - frame.minY)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .scaleEffect(pressed ? OverlayPressLook.scale : 1)
        .animation(.easeOut(duration: OverlayPressLook.duration), value: pressed)
    }

    private static let solid = try? JSONDecoder().decode(Skin2Paint.self, from: Data(##"{"type":"solid","color":"#000000"}"##.utf8))

    static func presentation(_ art: Skin2Resolution, pressed: Bool, knobOffset: CGSize) -> Skin2Resolution {
        guard pressed || knobOffset != .zero else { return art }
        var art = art
        for index in art.root.children.indices {
            var child = art.root.children[index]
            if child.node.role == .knob {
                child.frame.x += knobOffset.width
                child.frame.y += knobOffset.height
            } else if pressed, child.node.type == .shape {
                switch art.theme {
                case "glossy":
                    if !child.node.fills.isEmpty, !child.node.fills[0].stops.isEmpty {
                        child.node.fills[0].stops[0].opacity = OverlayPressLook.glossyPressedTop
                    }
                case "outline":
                    if var fill = solid, let rim = child.node.strokes.first {
                        fill.color = rim.color
                        fill.opacity = OverlayPressLook.outlinePressedOpacity
                        child.node.fills = [fill]
                    }
                default:
                    if !child.node.fills.isEmpty {
                        child.node.fills[0].opacity = OverlayPressLook.flatPressedOpacity
                    }
                }
            }
            art.root.children[index] = child
        }
        return art
    }
}
#endif
