#if canImport(UIKit)
import UIKit
import Foundation

// MARK: - UIImage SVG convenience initialiser

public extension UIImage {
    /// Render a subset of SVG into a UIImage.
    ///
    /// The renderer supports a limited subset of SVG elements and attributes
    /// sufficient for DeltaSkin controller artwork:
    /// - Elements: `<svg>`, `<g>`, `<rect>`, `<circle>`, `<ellipse>`, `<polygon>`, `<text>`
    /// - Attributes: fill, stroke, stroke-width, opacity, rx, ry, r, cx, cy,
    ///               x, y, width, height, points, transform (translate only),
    ///               font-size, font-family, text-anchor, dominant-baseline
    ///
    /// Returns `nil` when parsing fails or the SVG declares no viewBox / size.
    convenience init?(svgData: Data, size renderSize: CGSize? = nil) {
        guard let renderer = SVGRenderer(data: svgData) else { return nil }
        let targetSize = renderSize ?? renderer.intrinsicSize
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        guard let rendered = renderer.render(size: targetSize),
              let cgImage = rendered.cgImage else { return nil }
        self.init(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }
}

// MARK: - SVGRenderer

/// Lightweight SVG parser and renderer for DeltaSkin controller artwork.
///
/// Supports a subset of SVG sufficient for controller overlays. Gracefully
/// returns `nil` on any parse or render failure so callers can fall back to
/// other asset formats.
final class SVGRenderer: NSObject, XMLParserDelegate {

    // MARK: - Types

    private struct DrawCommand {
        enum Kind {
            case rect(CGRect, rx: CGFloat, ry: CGFloat)
            case circle(cx: CGFloat, cy: CGFloat, r: CGFloat)
            case ellipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)
            case polygon(points: [CGPoint])
            case text(String, x: CGFloat, y: CGFloat, anchor: TextAnchor, baseline: DominantBaseline)
        }
        let kind: Kind
        let fill: UIColor?
        let stroke: UIColor?
        let strokeWidth: CGFloat
        let opacity: CGFloat
        let transform: CGAffineTransform
        let fontSize: CGFloat
        let fontFamily: String
    }

    private enum TextAnchor { case start, middle, end }
    private enum DominantBaseline { case auto, middle, central }

    // MARK: - State

    private(set) var intrinsicSize: CGSize = .zero
    private var commands: [DrawCommand] = []
    private var groupTransformStack: [CGAffineTransform] = [.identity]
    private var textContent: String = ""
    private var pendingTextCmd: DrawCommand?

    // MARK: - Init

    init?(data: Data) {
        // Reject DOCTYPE/ENTITY declarations to prevent entity-expansion attacks
        // before handing the data to XMLParser.
        if let head = String(data: data.prefix(512), encoding: .utf8),
           head.contains("<!DOCTYPE") || head.contains("<!ENTITY") {
            return nil
        }
        super.init()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return nil }
    }

    // MARK: - Rendering

    func render(size: CGSize) -> UIImage? {
        let scale = UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let scaleX: CGFloat = intrinsicSize.width > 0 ? size.width / intrinsicSize.width : 1
        let scaleY: CGFloat = intrinsicSize.height > 0 ? size.height / intrinsicSize.height : 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            cgCtx.scaleBy(x: scaleX, y: scaleY)
            for cmd in commands {
                draw(cmd, in: cgCtx)
            }
        }
    }

    // MARK: - Draw helpers

    private func draw(_ cmd: DrawCommand, in ctx: CGContext) {
        ctx.saveGState()
        ctx.concatenate(cmd.transform)
        ctx.setAlpha(cmd.opacity)

        let fill = cmd.fill
        let stroke = cmd.stroke
        let strokeWidth = cmd.strokeWidth

        switch cmd.kind {
        case .rect(let rect, let rx, let ry):
            let path = roundedRectPath(rect: rect, rx: rx, ry: ry)
            applyFillStroke(path: path, fill: fill, stroke: stroke, strokeWidth: strokeWidth, ctx: ctx)

        case .circle(let cx, let cy, let r):
            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let path = UIBezierPath(ovalIn: rect).cgPath
            applyFillStroke(path: path, fill: fill, stroke: stroke, strokeWidth: strokeWidth, ctx: ctx)

        case .ellipse(let cx, let cy, let rx, let ry):
            let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            let path = UIBezierPath(ovalIn: rect).cgPath
            applyFillStroke(path: path, fill: fill, stroke: stroke, strokeWidth: strokeWidth, ctx: ctx)

        case .polygon(let pts):
            guard pts.count > 1 else { break }
            let path = CGMutablePath()
            path.move(to: pts[0])
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            path.closeSubpath()
            applyFillStroke(path: path, fill: fill, stroke: stroke, strokeWidth: strokeWidth, ctx: ctx)

        case .text(let string, let x, let y, let anchor, let baseline):
            let attrs = textAttributes(cmd: cmd)
            let nsString = string as NSString
            let size = nsString.size(withAttributes: attrs)
            var drawX = x
            var drawY = y
            switch anchor {
            case .middle: drawX -= size.width / 2
            case .end: drawX -= size.width
            case .start: break
            }
            switch baseline {
            case .middle, .central: drawY -= size.height / 2
            case .auto: drawY -= size.height * 0.8  // approximate descender offset
            }
            nsString.draw(at: CGPoint(x: drawX, y: drawY), withAttributes: attrs)
        }

        ctx.restoreGState()
    }

    private func applyFillStroke(path: CGPath, fill: UIColor?, stroke: UIColor?, strokeWidth: CGFloat, ctx: CGContext) {
        if let fill = fill {
            ctx.addPath(path)
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
        }
        if let stroke = stroke, strokeWidth > 0 {
            ctx.addPath(path)
            ctx.setStrokeColor(stroke.cgColor)
            ctx.setLineWidth(strokeWidth)
            ctx.strokePath()
        }
    }

    private func roundedRectPath(rect: CGRect, rx: CGFloat, ry: CGFloat) -> CGPath {
        let effectiveRx = rx > 0 ? min(rx, rect.width / 2) : (ry > 0 ? min(ry, rect.width / 2) : 0)
        let effectiveRy = ry > 0 ? min(ry, rect.height / 2) : effectiveRx
        if effectiveRx <= 0 || effectiveRy <= 0 {
            return CGPath(rect: rect, transform: nil)
        }
        return UIBezierPath(roundedRect: rect, cornerRadius: (effectiveRx + effectiveRy) / 2).cgPath
    }

    private func textAttributes(cmd: DrawCommand) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]
        let fontSize = cmd.fontSize > 0 ? cmd.fontSize : 14
        let families = cmd.fontFamily.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var font: UIFont?
        for family in families {
            let clean = family.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if let f = UIFont(name: clean, size: fontSize) {
                font = f
                break
            }
        }
        attrs[.font] = font ?? UIFont.systemFont(ofSize: fontSize)
        if let fill = cmd.fill {
            attrs[.foregroundColor] = fill
        }
        return attrs
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attrs: [String: String]) {
        let name = elementName.lowercased()
        switch name {
        case "svg":
            parseSVGSize(attrs: attrs)

        case "g":
            let transform = parseTransform(attrs["transform"])
            let current = groupTransformStack.last ?? .identity
            groupTransformStack.append(current.concatenating(transform))

        case "rect":
            let x = cgFloat(attrs["x"]) ?? 0
            let y = cgFloat(attrs["y"]) ?? 0
            let w = cgFloat(attrs["width"]) ?? 0
            let h = cgFloat(attrs["height"]) ?? 0
            let rx = cgFloat(attrs["rx"]) ?? 0
            let ry = cgFloat(attrs["ry"]) ?? 0
            let cmd = makeCommand(
                kind: .rect(CGRect(x: x, y: y, width: w, height: h), rx: rx, ry: ry),
                attrs: attrs
            )
            commands.append(cmd)

        case "circle":
            let cx = cgFloat(attrs["cx"]) ?? 0
            let cy = cgFloat(attrs["cy"]) ?? 0
            let r = cgFloat(attrs["r"]) ?? 0
            let cmd = makeCommand(kind: .circle(cx: cx, cy: cy, r: r), attrs: attrs)
            commands.append(cmd)

        case "ellipse":
            let cx = cgFloat(attrs["cx"]) ?? 0
            let cy = cgFloat(attrs["cy"]) ?? 0
            let rx = cgFloat(attrs["rx"]) ?? 0
            let ry = cgFloat(attrs["ry"]) ?? 0
            let cmd = makeCommand(kind: .ellipse(cx: cx, cy: cy, rx: rx, ry: ry), attrs: attrs)
            commands.append(cmd)

        case "polygon":
            let pts = parsePoints(attrs["points"] ?? "")
            let cmd = makeCommand(kind: .polygon(points: pts), attrs: attrs)
            commands.append(cmd)

        case "text":
            let x = cgFloat(attrs["x"]) ?? 0
            let y = cgFloat(attrs["y"]) ?? 0
            let anchor = parseTextAnchor(attrs["text-anchor"])
            let baseline = parseDominantBaseline(attrs["dominant-baseline"])
            pendingTextCmd = makeCommand(
                kind: .text("", x: x, y: y, anchor: anchor, baseline: baseline),
                attrs: attrs
            )
            textContent = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if pendingTextCmd != nil {
            textContent += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        switch name {
        case "g":
            if groupTransformStack.count > 1 { groupTransformStack.removeLast() }

        case "text":
            if let proto = pendingTextCmd {
                if case .text(_, let x, let y, let anchor, let baseline) = proto.kind {
                    let finalCmd = DrawCommand(
                        kind: .text(textContent, x: x, y: y, anchor: anchor, baseline: baseline),
                        fill: proto.fill,
                        stroke: proto.stroke,
                        strokeWidth: proto.strokeWidth,
                        opacity: proto.opacity,
                        transform: proto.transform,
                        fontSize: proto.fontSize,
                        fontFamily: proto.fontFamily
                    )
                    commands.append(finalCmd)
                }
            }
            pendingTextCmd = nil
            textContent = ""

        default:
            break
        }
    }

    // MARK: - SVG size parsing

    private func parseSVGSize(attrs: [String: String]) {
        if let vb = attrs["viewBox"] {
            let parts = vb.components(separatedBy: .whitespaces)
                .flatMap { $0.components(separatedBy: ",") }
                .compactMap(Double.init)
            if parts.count >= 4 {
                intrinsicSize = CGSize(width: CGFloat(parts[2]), height: CGFloat(parts[3]))
            }
        }
        if let w = cgFloat(attrs["width"]), let h = cgFloat(attrs["height"]) {
            if intrinsicSize == .zero {
                intrinsicSize = CGSize(width: w, height: h)
            }
        }
    }

    // MARK: - DrawCommand factory

    private func makeCommand(kind: DrawCommand.Kind, attrs: [String: String]) -> DrawCommand {
        let transform = groupTransformStack.last ?? .identity
        let elementTransform = parseTransform(attrs["transform"])
        let combined = transform.concatenating(elementTransform)

        let fill: UIColor?
        let fillStr = attrs["fill"] ?? "black"
        if fillStr == "none" || fillStr == "transparent" {
            fill = nil
        } else {
            fill = parseColor(fillStr)
        }

        let stroke: UIColor?
        if let strokeStr = attrs["stroke"], strokeStr != "none", strokeStr != "transparent" {
            stroke = parseColor(strokeStr)
        } else {
            stroke = nil
        }

        let strokeWidth = cgFloat(attrs["stroke-width"]) ?? 1
        let opacity = cgFloat(attrs["opacity"]) ?? 1
        let fontSize = cgFloat(attrs["font-size"]) ?? 14
        let fontFamily = attrs["font-family"] ?? "Helvetica Neue, sans-serif"

        return DrawCommand(
            kind: kind,
            fill: fill,
            stroke: stroke,
            strokeWidth: strokeWidth,
            opacity: opacity,
            transform: combined,
            fontSize: fontSize,
            fontFamily: fontFamily
        )
    }

    // MARK: - Attribute parsers

    private func cgFloat(_ value: String?) -> CGFloat? {
        guard let v = value else { return nil }
        return Double(v.trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
    }

    private func parsePoints(_ pointsStr: String) -> [CGPoint] {
        let numbers = pointsStr
            .components(separatedBy: CharacterSet(charactersIn: " ,\t\n\r"))
            .compactMap { Double($0) }
        var pts: [CGPoint] = []
        var idx = 0
        while idx + 1 < numbers.count {
            pts.append(CGPoint(x: numbers[idx], y: numbers[idx + 1]))
            idx += 2
        }
        return pts
    }

    private func parseTransform(_ value: String?) -> CGAffineTransform {
        guard let value = value else { return .identity }
        if value.hasPrefix("translate(") {
            let inner = value.dropFirst(10).dropLast()
            let parts = inner.components(separatedBy: CharacterSet(charactersIn: " ,"))
                .compactMap { Double($0) }
            let tx = parts.count > 0 ? CGFloat(parts[0]) : 0
            let ty = parts.count > 1 ? CGFloat(parts[1]) : 0
            return CGAffineTransform(translationX: tx, y: ty)
        }
        return .identity
    }

    private func parseTextAnchor(_ value: String?) -> TextAnchor {
        switch value {
        case "middle": return .middle
        case "end": return .end
        default: return .start
        }
    }

    private func parseDominantBaseline(_ value: String?) -> DominantBaseline {
        switch value {
        case "middle", "central": return .middle
        default: return .auto
        }
    }

    // MARK: - Color parsing

    private func parseColor(_ value: String) -> UIColor? {
        let v = value.trimmingCharacters(in: .whitespaces).lowercased()
        if v == "none" || v == "transparent" { return nil }
        if v.hasPrefix("#") { return parseHexColor(v) }
        if v.hasPrefix("rgba(") { return parseRGBAColor(v) }
        if v.hasPrefix("rgb(") { return parseRGBColor(v) }
        return namedColor(v)
    }

    private func parseHexColor(_ hex: String) -> UIColor? {
        let raw = String(hex.dropFirst())
        let expanded: String
        switch raw.count {
        case 3:
            expanded = raw.flatMap { c in [c, c] }.map(String.init).joined()
        case 6, 8:
            expanded = raw
        default:
            return nil
        }
        var value: UInt64 = 0
        guard Scanner(string: expanded).scanHexInt64(&value) else { return nil }
        if expanded.count == 8 {
            let r = CGFloat((value >> 24) & 0xFF) / 255
            let g = CGFloat((value >> 16) & 0xFF) / 255
            let b = CGFloat((value >> 8) & 0xFF) / 255
            let a = CGFloat(value & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: a)
        } else {
            let r = CGFloat((value >> 16) & 0xFF) / 255
            let g = CGFloat((value >> 8) & 0xFF) / 255
            let b = CGFloat(value & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        }
    }

    private func parseRGBAColor(_ value: String) -> UIColor? {
        let inner = value.dropFirst(5).dropLast()
        let parts = inner.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 4 else { return nil }
        return UIColor(
            red: CGFloat(parts[0]) / 255,
            green: CGFloat(parts[1]) / 255,
            blue: CGFloat(parts[2]) / 255,
            alpha: CGFloat(parts[3])
        )
    }

    private func parseRGBColor(_ value: String) -> UIColor? {
        let inner = value.dropFirst(4).dropLast()
        let parts = inner.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3 else { return nil }
        return UIColor(
            red: CGFloat(parts[0]) / 255,
            green: CGFloat(parts[1]) / 255,
            blue: CGFloat(parts[2]) / 255,
            alpha: 1
        )
    }

    private func namedColor(_ name: String) -> UIColor? {
        switch name {
        case "black":   return .black
        case "white":   return .white
        case "red":     return .red
        case "green":   return UIColor(red: 0, green: 0.502, blue: 0, alpha: 1)
        case "blue":    return .blue
        case "yellow":  return .yellow
        case "gray", "grey": return .gray
        case "orange":  return .orange
        case "purple":  return .purple
        case "cyan":    return .cyan
        case "magenta": return .magenta
        case "lime":    return UIColor(red: 0, green: 1, blue: 0, alpha: 1)
        case "navy":    return UIColor(red: 0, green: 0, blue: 0.502, alpha: 1)
        case "teal":    return UIColor(red: 0, green: 0.502, blue: 0.502, alpha: 1)
        case "silver":  return UIColor(red: 0.753, green: 0.753, blue: 0.753, alpha: 1)
        case "transparent", "none": return nil
        default:        return nil
        }
    }
}
#endif
