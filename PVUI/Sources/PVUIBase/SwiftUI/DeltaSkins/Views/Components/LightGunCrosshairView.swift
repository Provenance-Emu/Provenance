//
//  LightGunCrosshairView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A transparent SwiftUI overlay that renders a configurable crosshair
//  at the current light-gun cursor position.
//
//  Design notes:
//  - The overlay is sized to fill its parent.
//  - `position` is in normalised [0, 1] × [0, 1] space (game screen coordinates).
//  - Coordinate mapping assumes the overlay covers the same area as the game screen.
//  - `.allowsHitTesting(false)` must be set by the caller so the crosshair does
//    not absorb touch events.
//  - `PlusCrosshair` and `ReticleCrosshair` use `Canvas` for efficient rendering;
//    `DotCrosshair` uses standard SwiftUI `Circle()` views.
//

import SwiftUI
import PVCoreBridge
import PVSettings
import Defaults

// MARK: - Crosshair shapes

private struct DotCrosshair: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
        }
        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 0)
    }
}

private struct PlusCrosshair: View {
    let size: CGFloat = 28
    let lineWidth: CGFloat = 2
    let gap: CGFloat = 5

    var body: some View {
        Canvas { ctx, _ in
            let cx = size / 2
            let cy = size / 2

            var path = Path()
            // Horizontal left arm
            path.move(to: CGPoint(x: 0, y: cy))
            path.addLine(to: CGPoint(x: cx - gap, y: cy))
            // Horizontal right arm
            path.move(to: CGPoint(x: cx + gap, y: cy))
            path.addLine(to: CGPoint(x: size, y: cy))
            // Vertical top arm
            path.move(to: CGPoint(x: cx, y: 0))
            path.addLine(to: CGPoint(x: cx, y: cy - gap))
            // Vertical bottom arm
            path.move(to: CGPoint(x: cx, y: cy + gap))
            path.addLine(to: CGPoint(x: cx, y: size))

            ctx.stroke(path,
                       with: .color(.black),
                       style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .square))
            ctx.stroke(path,
                       with: .color(.white),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
        }
        .frame(width: size, height: size)
    }
}

private struct ReticleCrosshair: View {
    let size: CGFloat = 36
    let lineWidth: CGFloat = 1.5
    let gap: CGFloat = 8

    var body: some View {
        Canvas { ctx, _ in
            let cx = size / 2
            let cy = size / 2
            let r = size / 2 - 2

            // Outer circle
            let circle = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.stroke(circle, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth + 1.5))
            ctx.stroke(circle, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth))

            // Cross lines with gap
            var cross = Path()
            cross.move(to: CGPoint(x: 0, y: cy)); cross.addLine(to: CGPoint(x: cx - gap, y: cy))
            cross.move(to: CGPoint(x: cx + gap, y: cy)); cross.addLine(to: CGPoint(x: size, y: cy))
            cross.move(to: CGPoint(x: cx, y: 0)); cross.addLine(to: CGPoint(x: cx, y: cy - gap))
            cross.move(to: CGPoint(x: cx, y: cy + gap)); cross.addLine(to: CGPoint(x: cx, y: size))

            ctx.stroke(cross, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .square))
            ctx.stroke(cross, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main overlay

/// Transparent overlay view that renders a crosshair at the light-gun cursor position.
///
/// Place this in a `ZStack` above the game screen and set `.allowsHitTesting(false)`
/// so it does not intercept touch input.
///
/// Example:
/// ```swift
/// ZStack {
///     GameScreenView()
///     LightGunCrosshairView()
///         .allowsHitTesting(false)
/// }
/// ```
public struct LightGunCrosshairView: View {

    // MARK: - Settings

    @Default(.lightGunCrosshairStyle) private var style

    // MARK: - State

    /// Normalised cursor position, received via `Notification.Name.lightGunCursorDidMove`.
    @State private var cursorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Whether the gun is currently aimed off-screen.
    @State private var isOffscreen: Bool = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        if style == .off {
            Color.clear
        } else {
            GeometryReader { geo in
                let x = cursorPosition.x * geo.size.width
                let y = cursorPosition.y * geo.size.height

                ZStack {
                    if !isOffscreen {
                        crosshairView
                            .position(x: x, y: y)
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .lightGunCursorDidMove)
                    .receive(on: RunLoop.main)
            ) { note in
                let info = note.userInfo
                if let nx = info?[LightGunCursorNotification.positionXKey] as? NSNumber,
                   let ny = info?[LightGunCursorNotification.positionYKey] as? NSNumber {
                    cursorPosition = CGPoint(x: CGFloat(nx.doubleValue), y: CGFloat(ny.doubleValue))
                }
                isOffscreen = info?[LightGunCursorNotification.isOffscreenKey] as? Bool ?? false
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var crosshairView: some View {
        switch style {
        case .dot:
            DotCrosshair()
        case .crosshair:
            PlusCrosshair()
        case .reticle:
            ReticleCrosshair()
        case .off:
            EmptyView()
        }
    }
}
