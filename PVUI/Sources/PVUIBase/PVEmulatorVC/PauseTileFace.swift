import SwiftUI

/// Geometry shared with controller navigation so every visible column is reachable.
enum PauseTileLayout {
    static let spacing: CGFloat = 6
    static let contentInset: CGFloat = 12
    static let minimumWidth: CGFloat = 74

    static func columns(panelWidth: CGFloat, accessibility: Bool = false) -> Int {
        let minimum = accessibility ? minimumWidth * 1.8 : minimumWidth
        let available = max(0, panelWidth - contentInset * 2)
        return max(1, min(8, Int((available + spacing) / (minimum + spacing))))
    }
}

/// Luminous tile face with crisp labels layered above the lower edge of the glyph.
struct PauseTileFace: View {
    let label: String
    let icon: String
    let badge: String?
    let accent: Color
    let isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .caption) private var labelSize = PauseTileMetrics.labelSize

    private var height: CGFloat {
        #if os(tvOS)
        return 112
        #else
        return dynamicTypeSize.isAccessibilitySize ? max(112, labelSize * 3.6 + 33) : (horizontalSizeClass == .regular ? 72 : 68)
        #endif
    }

    private var iconSize: CGFloat {
        #if os(tvOS)
        return PauseTileMetrics.iconSize
        #else
        return horizontalSizeClass == .regular ? 32 : PauseTileMetrics.iconSize
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.35), radius: 2)
                .padding(.top, 9)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(PauseTileMetrics.labelMinimumScale)
                .shadow(color: .black.opacity(0.85), radius: 0.35, y: 0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    LinearGradient(colors: [.clear, .black.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
                }
                .padding(.horizontal, 4)
                .padding(.top, 27)
                .padding(.bottom, 6)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [accent.opacity(isFocused ? 0.24 : 0.14), Color.black.opacity(0.8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(LinearGradient(colors: [accent.opacity(isFocused ? 0.9 : 0.55), Color.retroPurple.opacity(0.3)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isFocused ? 1.5 : 1)
        }
        .shadow(color: accent.opacity(isFocused ? 0.27 : 0.07), radius: isFocused ? 4.5 : 2.5)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: PauseTileMetrics.badgeSize, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(accent, in: Capsule())
                    .padding(.leading, PauseTileMetrics.badgeLeadingInset)
                    .offset(y: -4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Pause tiles · native labels") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 10) {
        PauseTileFace(label: "Browse Saves", icon: "square.grid.2x2", badge: nil, accent: .retroPurple, isFocused: true)
        PauseTileFace(label: "Internal Resolution", icon: "display", badge: "1920×1080 (4×)", accent: .retroBlue, isFocused: false)
        PauseTileFace(label: "Bilinear Texture Filtering", icon: "line.3.horizontal.decrease", badge: "Off", accent: .retroCyan, isFocused: false)
        PauseTileFace(label: "Quit (No Save)", icon: "rectangle.portrait.and.arrow.right", badge: nil, accent: .retroPink, isFocused: false)
    }
    .padding(16)
    .frame(width: 370)
    .background(Color.retroBlack)
}
#endif
