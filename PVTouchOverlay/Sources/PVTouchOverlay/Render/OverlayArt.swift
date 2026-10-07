#if canImport(UIKit)
import SwiftUI
import PVSettings

public struct OverlayArtSpec: Equatable, Sendable {
    public var shape: OverlayShape
    public var color: OverlayColor
    public var labelColor: OverlayColor
    public var style: OverlayStyle
    public var pressed: Bool
    public var label: String?

    public init(shape: OverlayShape, color: OverlayColor, labelColor: OverlayColor,
                style: OverlayStyle, pressed: Bool, label: String?) {
        self.shape = shape
        self.color = color
        self.labelColor = labelColor
        self.style = style
        self.pressed = pressed
        self.label = label
    }
}

public extension Color {
    init(_ color: OverlayColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

public enum OverlayShapePath {
    private static let keyCorner: CGFloat = 6
    private static let surfaceCorner: CGFloat = 10
    private static let ringInsetFraction: CGFloat = 0.3
    private static let barTaperFraction: CGFloat = 0.12

    /// The plus silhouette as a single 12-vertex outline with rounded corners.
    private static func crossOutline(in rect: CGRect) -> Path {
        let arm = rect.width / 3
        let x1 = rect.minX + arm, x2 = rect.minX + arm * 2
        let y1 = rect.minY + arm, y2 = rect.minY + arm * 2
        let vertices = [
            CGPoint(x: x1, y: rect.minY), CGPoint(x: x2, y: rect.minY), CGPoint(x: x2, y: y1),
            CGPoint(x: rect.maxX, y: y1), CGPoint(x: rect.maxX, y: y2), CGPoint(x: x2, y: y2),
            CGPoint(x: x2, y: rect.maxY), CGPoint(x: x1, y: rect.maxY), CGPoint(x: x1, y: y2),
            CGPoint(x: rect.minX, y: y2), CGPoint(x: rect.minX, y: y1), CGPoint(x: x1, y: y1)
        ]
        var path = Path()
        let last = vertices[vertices.count - 1]
        path.move(to: CGPoint(x: (last.x + vertices[0].x) / 2, y: (last.y + vertices[0].y) / 2))
        for index in vertices.indices {
            let next = vertices[(index + 1) % vertices.count]
            path.addArc(tangent1End: vertices[index], tangent2End: next, radius: keyCorner)
        }
        path.closeSubpath()
        return path
    }

    public static func path(_ shape: OverlayShape, in rect: CGRect) -> Path {
        switch shape {
        case .circle, .knob:
            return Path(ellipseIn: rect)
        case .ring:
            var path = Path(ellipseIn: rect)
            path.addEllipse(in: rect.insetBy(dx: rect.width * ringInsetFraction, dy: rect.height * ringInsetFraction))
            return path
        case .pill:
            return Path(roundedRect: rect, cornerRadius: rect.height / 2)
        case .key:
            return Path(roundedRect: rect, cornerRadius: keyCorner)
        case .surface:
            return Path(roundedRect: rect, cornerRadius: surfaceCorner)
        case .bar:
            // Tapered trigger: narrower at the top.
            var path = Path()
            let taper = rect.width * barTaperFraction
            path.move(to: CGPoint(x: rect.minX + taper, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        case .kidney:
            // One closed bean outline: two semicircle caps joined by the top and bottom edges.
            let radius = rect.height / 2
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.midY), radius: radius,
                        startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.midY), radius: radius,
                        startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
            return path
        case .cross:
            return crossOutline(in: rect)
        }
    }
}

/// One control's art. Equatable so a press re-renders only this view.
public struct OverlayControlArt: View, Equatable {
    public let spec: OverlayArtSpec

    public init(spec: OverlayArtSpec) { self.spec = spec }

    /// Even-odd so a ring's inner ellipse is a true hole.
    private static let fillStyle = FillStyle(eoFill: true)

    private var showsLabel: Bool {
        spec.label != nil && spec.shape != .ring && spec.shape != .surface && spec.shape != .cross
    }

    public var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let path = OverlayShapePath.path(spec.shape, in: rect)
            let base = Color(spec.color)
            ZStack {
                switch spec.style {
                case .flat:
                    let fill = spec.pressed ? base.opacity(OverlayPressLook.flatPressedOpacity) : base
                    path.fill(fill, style: Self.fillStyle)
                    path.stroke(Color.white.opacity(OverlayPressLook.flatRimOpacity),
                                lineWidth: OverlayPressLook.rimWidth)
                case .glossy:
                    let top = base.opacity(spec.pressed ? OverlayPressLook.glossyPressedTop : 1)
                    let bottom = base.opacity(OverlayPressLook.glossyBottomOpacity)
                    path.fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom),
                              style: Self.fillStyle)
                    path.fill(LinearGradient(colors: [Color.white.opacity(OverlayPressLook.glossHighlightOpacity),
                                                      .clear],
                                             startPoint: .top, endPoint: .center),
                              style: Self.fillStyle)
                    path.stroke(Color.black.opacity(OverlayPressLook.glossyRimOpacity),
                                lineWidth: OverlayPressLook.rimWidth)
                case .outline:
                    path.fill(spec.pressed ? base.opacity(OverlayPressLook.outlinePressedOpacity) : Color.clear,
                              style: Self.fillStyle)
                    path.stroke(base, lineWidth: OverlayPressLook.outlineWidth)
                }
                if showsLabel, let label = spec.label {
                    Text(label)
                        .font(.system(size: min(geo.size.height * OverlayPressLook.labelHeightFraction, OverlayPressLook.maxLabelSize),
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(spec.labelColor))
                        .minimumScaleFactor(0.5)
                        .padding(OverlayPressLook.labelPadding)
                }
            }
            .scaleEffect(spec.pressed ? OverlayPressLook.scale : 1)
            .animation(.easeOut(duration: OverlayPressLook.duration), value: spec.pressed)
        }
    }
}
#endif
