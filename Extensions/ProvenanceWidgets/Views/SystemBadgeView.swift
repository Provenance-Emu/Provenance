//
//  SystemBadgeView.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI

/// Visual treatment for the system abbreviation pill (matches host accent vs. RetroWave widget chrome).
enum SystemBadgeChrome {
    /// Standard accent-colored capsule (system accent color).
    case accentPill
    /// Neon gradient capsule aligned with `RetroWaveWidgetPalette` widgets.
    case retroWaveNeon
}

/// Small pill-shaped badge showing the abbreviated system name.
struct SystemBadgeView: View {
    let systemShortName: String
    /// Chrome style; defaults to the app accent pill for backward compatibility.
    var chrome: SystemBadgeChrome = .accentPill

    var body: some View {
        Text(systemShortName.isEmpty ? "???" : systemShortName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch chrome {
        case .accentPill:
            Capsule().fill(Color.accentColor.opacity(0.85))
        case .retroWaveNeon:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            RetroWaveWidgetPalette.neonPink.opacity(0.92),
                            RetroWaveWidgetPalette.neonPurple.opacity(0.88)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(RetroWaveWidgetPalette.neonCyan.opacity(0.35), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - RetroWave widget styling

/// Shared color tokens for RetroWave-inspired widget chrome (dark base + neon accents).
enum RetroWaveWidgetPalette {
    /// Deep near-black background with a subtle violet bias.
    static let retroBlack = Color(red: 0.04, green: 0.01, blue: 0.08)
    /// Hot magenta / pink accent.
    static let neonPink = Color(red: 1.0, green: 0.16, blue: 0.42)
    /// Electric purple accent.
    static let neonPurple = Color(red: 0.64, green: 0.12, blue: 0.95)
    /// Saturated blue accent.
    static let neonBlue = Color(red: 0.18, green: 0.55, blue: 1.0)
    /// Bright cyan accent.
    static let neonCyan = Color(red: 0.0, green: 0.92, blue: 0.96)
    /// Neon yellow highlight.
    static let neonYellow = Color(red: 1.0, green: 0.95, blue: 0.2)
    /// Neon green highlight.
    static let neonGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
}

/// Precomposed gradients for widget backgrounds and trims.
enum RetroWaveWidgetGradients {
    /// Primary horizontal neon sweep (pink → purple → blue → cyan).
    static let mainNeon = LinearGradient(
        colors: [
            RetroWaveWidgetPalette.neonPink,
            RetroWaveWidgetPalette.neonPurple,
            RetroWaveWidgetPalette.neonBlue,
            RetroWaveWidgetPalette.neonCyan
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// Distinguishes inset grid cells from full-width section bands.
enum RetroWaveWidgetSurfaceKind {
    /// Compact cell surface (e.g. game artwork cells, quick actions).
    case gridCell
    /// Horizontal band for grouped content or list headers.
    case section
}

/// Filled rounded rectangle with a subtle neon edge suitable for widget cards.
struct RetroWaveWidgetCardBackground: View {
    /// Corner radius matching the widget’s content shape.
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RetroWaveWidgetPalette.retroBlack.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                RetroWaveWidgetPalette.neonPink.opacity(0.55),
                                RetroWaveWidgetPalette.neonCyan.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// Secondary surface for grid cells and section strips inside a card.
struct RetroWaveWidgetSurfaceBackground: View {
    var kind: RetroWaveWidgetSurfaceKind
    /// Corner radius; section kind uses a slightly tighter radius for band-like strips.
    var cornerRadius: CGFloat = 12

    private var effectiveRadius: CGFloat {
        switch kind {
        case .gridCell:
            return cornerRadius
        case .section:
            return max(8, cornerRadius * 0.65)
        }
    }

    private var fillOpacity: Double {
        switch kind {
        case .gridCell:
            return 0.55
        case .section:
            return 0.4
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
            .fill(RetroWaveWidgetPalette.retroBlack.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                    .strokeBorder(RetroWaveWidgetPalette.neonPurple.opacity(0.35), lineWidth: 0.5)
            )
    }
}

/// Fonts and foreground colors for consistent widget typography tiers.
enum RetroWaveWidgetTypography {
    /// Primary widget / group title.
    static func titleFont() -> Font {
        .system(.headline, design: .rounded).weight(.heavy)
    }

    /// Section labels and emphasized captions.
    static func labelFont() -> Font {
        .system(.caption, design: .rounded).weight(.semibold)
    }

    /// Large numeric or hero values (stats, counters).
    static func valueFont() -> Font {
        .system(.title3, design: .rounded).weight(.bold)
    }

    /// De-emphasized metadata (dates, subtitles, footnotes).
    static func metaFont() -> Font {
        .system(.caption2, design: .rounded).weight(.medium)
    }

    /// Default foreground for `titleFont()`.
    static let titleForeground = Color.white
    /// Default foreground for `labelFont()` (cyan-tinted for RetroWave chrome).
    static let labelForeground = RetroWaveWidgetPalette.neonCyan.opacity(0.95)
    /// Default foreground for `valueFont()`.
    static let valueForeground = Color.white
    /// Default foreground for `metaFont()`.
    static let metaForeground = Color.white.opacity(0.55)
}

/// Dark fill and neon stroke aligned to the widget’s `ContainerRelativeShape` so the border matches system widget edges (avoids inset rounded-rect card mismatch).
private struct RetroWaveWidgetContainerChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ContainerRelativeShape()
                    .fill(RetroWaveWidgetPalette.retroBlack.opacity(0.92))
            }
            .overlay {
                ContainerRelativeShape()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                RetroWaveWidgetPalette.neonPink.opacity(0.55),
                                RetroWaveWidgetPalette.neonCyan.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

private struct RetroWaveWidgetCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(RetroWaveWidgetCardBackground(cornerRadius: cornerRadius))
    }
}

private struct RetroWaveWidgetGridCellSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(RetroWaveWidgetSurfaceBackground(kind: .gridCell, cornerRadius: cornerRadius))
    }
}

private struct RetroWaveWidgetSectionSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(RetroWaveWidgetSurfaceBackground(kind: .section, cornerRadius: cornerRadius))
    }
}

private struct RetroWaveWidgetTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RetroWaveWidgetTypography.titleFont())
            .foregroundStyle(RetroWaveWidgetTypography.titleForeground)
    }
}

private struct RetroWaveWidgetLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RetroWaveWidgetTypography.labelFont())
            .foregroundStyle(RetroWaveWidgetTypography.labelForeground)
    }
}

private struct RetroWaveWidgetValueStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RetroWaveWidgetTypography.valueFont())
            .foregroundStyle(RetroWaveWidgetTypography.valueForeground)
    }
}

private struct RetroWaveWidgetMetaStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RetroWaveWidgetTypography.metaFont())
            .foregroundStyle(RetroWaveWidgetTypography.metaForeground)
    }
}

extension View {
    /// Edge-aligned RetroWave fill + stroke using `ContainerRelativeShape` (use instead of an inset `retroWaveWidgetCardBackground` when the border should match the widget silhouette).
    func retroWaveWidgetContainerChrome() -> some View {
        modifier(RetroWaveWidgetContainerChromeModifier())
    }

    /// Applies the standard RetroWave card background (dark fill + neon gradient border).
    func retroWaveWidgetCardBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(RetroWaveWidgetCardModifier(cornerRadius: cornerRadius))
    }

    /// Inset grid cell surface for grids and compact cells.
    func retroWaveWidgetGridCellSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(RetroWaveWidgetGridCellSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Full-width or banded section surface.
    func retroWaveWidgetSectionSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(RetroWaveWidgetSectionSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Title-tier typography (headline, rounded, heavy).
    func retroWaveWidgetTitleStyle() -> some View {
        modifier(RetroWaveWidgetTitleStyle())
    }

    /// Label-tier typography (caption, rounded, semibold, cyan accent).
    func retroWaveWidgetLabelStyle() -> some View {
        modifier(RetroWaveWidgetLabelStyle())
    }

    /// Value-tier typography (title3, rounded, bold).
    func retroWaveWidgetValueStyle() -> some View {
        modifier(RetroWaveWidgetValueStyle())
    }

    /// Meta-tier typography (caption2, rounded, muted white).
    func retroWaveWidgetMetaStyle() -> some View {
        modifier(RetroWaveWidgetMetaStyle())
    }
}
#endif
