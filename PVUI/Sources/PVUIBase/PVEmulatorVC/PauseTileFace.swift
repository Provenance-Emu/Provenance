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

/// Tile face: a light glyph over its label, on a tinted translucent cell with a hairline rim.
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
        return PauseTileMetrics.tileHeight
        #else
        if dynamicTypeSize.isAccessibilitySize {
            return max(PauseTileMetrics.accessibilityTileHeight, labelSize * 3.6 + 33)
        }
        return horizontalSizeClass == .regular ? PauseTileMetrics.regularTileHeight : PauseTileMetrics.tileHeight
        #endif
    }

    private var iconSize: CGFloat {
        #if os(tvOS)
        return PauseTileMetrics.iconSize
        #else
        return horizontalSizeClass == .regular ? PauseTileMetrics.regularIconSize : PauseTileMetrics.iconSize
        #endif
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RetroPauseChrome.menuCellCornerRadius())
    }

    var body: some View {
        VStack(spacing: PauseTileMetrics.iconLabelGap) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(isFocused ? 0.6 : 0.3), radius: isFocused ? 5 : 2)
                .frame(height: iconSize + PauseTileMetrics.iconSlotPadding)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(PauseTileMetrics.labelMinimumScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            shape.fill(accent.opacity(isFocused ? RetroPauseChrome.menuCellFillOpacityFocused
                                                 : RetroPauseChrome.menuCellFillOpacityUnfocused))
        }
        .overlay {
            shape.strokeBorder(
                accent.opacity(isFocused ? RetroPauseChrome.menuCellStrokeOpacityFocused
                                         : RetroPauseChrome.menuCellStrokeOpacityUnfocused),
                lineWidth: isFocused ? RetroPauseChrome.menuCellStrokeWidthFocused
                                     : RetroPauseChrome.menuCellStrokeWidthUnfocused)
        }
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
        .contentShape(shape)
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
