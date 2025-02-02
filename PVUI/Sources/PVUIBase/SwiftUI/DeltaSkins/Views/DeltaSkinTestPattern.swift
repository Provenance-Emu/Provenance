import SwiftUI

/// Visual effects for test pattern display
public enum TestPatternEffect: String, CaseIterable {
    case lcd
    case scanlines
    case subpixel
    case pixelated
}

extension SwiftUI.Color {
    static let magenta: Color = .init(red: 1, green: 0, blue: 1)
}

/// Test patterns for skin development and testing
public enum DeltaSkinTestPattern: Int, CaseIterable {
    case smpte
    case ntsc75
    case ebu

    /// The name of this pattern
    public var name: String {
        switch self {
        case .smpte:
            return "SMPTE"
        case .ntsc75:
            return "NTSC 75%"
        case .ebu:
            return "EBU"
        }
    }

    /// The colors that make up this pattern
    public var colors: [Color] {
        switch self {
        case .smpte:
            return [
                .white, .yellow, .cyan, .green,
                .magenta, .red, .blue, .black
            ]

        case .ntsc75:
            return [
                Color(red: 0.75, green: 0.75, blue: 0.75),
                Color(red: 0.75, green: 0.75, blue: 0),
                Color(red: 0, green: 0.75, blue: 0.75),
                Color(red: 0, green: 0.75, blue: 0),
                Color(red: 0.75, green: 0, blue: 0.75),
                Color(red: 0.75, green: 0, blue: 0),
                Color(red: 0, green: 0, blue: 0.75),
                .black
            ]

        case .ebu:
            return [
                .white,
                Color(red: 1, green: 1, blue: 0),    // Yellow
                Color(red: 0, green: 1, blue: 1),    // Cyan
                Color(red: 0, green: 1, blue: 0),    // Green
                Color(red: 1, green: 0, blue: 1),    // Magenta
                Color(red: 1, green: 0, blue: 0),    // Red
                Color(red: 0, green: 0, blue: 1),    // Blue
                .black,
                Color(red: 0.75, green: 0.75, blue: 0.75), // Grey
                .black,
                Color(red: 1, green: 1, blue: 0),    // Yellow
                .black,
                Color(red: 0, green: 0, blue: 1),    // Blue
                .black
            ]
        }
    }
}

/// SMPTE color bars test pattern
public struct DeltaSkinTestPatternView: View {
    let frame: CGRect
    let filters: Set<TestPatternEffect>

    /// SMPTE/NTSC standard colors
    private let colors: [Color] = [
        Color(red: 0.753, green: 0.753, blue: 0.753), // 75% Gray
        Color(red: 0.753, green: 0.753, blue: 0.000), // Yellow
        Color(red: 0.000, green: 0.753, blue: 0.753), // Cyan
        Color(red: 0.000, green: 0.753, blue: 0.000), // Green
        Color(red: 0.753, green: 0.000, blue: 0.753), // Magenta
        Color(red: 0.753, green: 0.000, blue: 0.000), // Red
        Color(red: 0.000, green: 0.000, blue: 0.753)  // Blue
    ]

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(colors.indices, id: \.self) { index in
                    Rectangle()
                        .fill(colors[index])
                        .frame(width: geometry.size.width / CGFloat(colors.count))
                }
            }
            .overlay {
                VStack(spacing: 0) {
                    // Top pluge bars
                    Rectangle()
                        .fill(.black)
                        .frame(height: geometry.size.height * 0.075)

                    // Bottom pluge and reference bars
                    Rectangle()
                        .fill(.black)
                        .frame(height: geometry.size.height * 0.15)
                        .overlay {
                            HStack(spacing: 0) {
                                Color.white.opacity(0.1)  // -4% black
                                Color.black               // 0% black
                                Color.white.opacity(0.2)  // +4% black
                                Color.white               // 100% white
                                Color.black               // 0% black
                            }
                        }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .if(filters.contains(.pixelated)) {
                $0.drawingGroup()  // Use Metal rendering
                    .scaleEffect(1.0, anchor: .center)  // Force pixel-perfect rendering
            }
            .overlay {
                if filters.contains(.scanlines) {
                    ScanlinesEffect()
                }
                if filters.contains(.lcd) {
                    LCDEffect()
                }
                if filters.contains(.subpixel) {
                    SubpixelEffect()
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .position(x: frame.midX, y: frame.midY)
    }
}

// Helper effects
struct ScanlinesEffect: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                stride(from: 0, to: geometry.size.height, by: 2).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(.black.opacity(0.3), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct LCDEffect: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                stride(from: 0, to: geometry.size.width, by: 3).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
            }
            .stroke(.black.opacity(0.1), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct SubpixelEffect: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.width), id: \.self) { x in
                    VStack(spacing: 0) {
                        Color.red.opacity(0.2)
                        Color.green.opacity(0.2)
                        Color.blue.opacity(0.2)
                    }
                    .frame(width: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Helper for conditional modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
