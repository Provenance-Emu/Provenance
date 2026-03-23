// CompanionControllerAxis.swift
// PVUI
//
// Reusable virtual joystick / D-pad component for companion layouts.
// Tracks a drag gesture and maps it to X/Y axis values in [-1, 1],
// forwarding them through CompanionInputRouter.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVCoreBridge

// MARK: - CompanionControllerAxis

/// A circular virtual joystick thumb that reports continuous axis values.
///
/// ```swift
/// CompanionControllerAxis(axisX: .leftX, axisY: .leftY, router: inputRouter)
///     .frame(width: 120, height: 120)
/// ```
public struct CompanionControllerAxis: View {

    // MARK: - Configuration

    private let axisX: CompanionAxisID
    private let axisY: CompanionAxisID
    private let router: CompanionInputRouter
    /// Maximum thumb travel radius in points.
    private let maxRadius: CGFloat
    /// Tint of the thumb indicator.
    private let thumbColor: Color
    /// Tint of the base circle.
    private let baseColor: Color

    // MARK: - State

    @State private var thumbOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    // MARK: - Init

    public init(
        axisX: CompanionAxisID,
        axisY: CompanionAxisID,
        router: CompanionInputRouter,
        maxRadius: CGFloat = 40,
        thumbColor: Color = .white,
        baseColor: Color = Color.white.opacity(0.15)
    ) {
        self.axisX      = axisX
        self.axisY      = axisY
        self.router     = router
        self.maxRadius  = maxRadius
        self.thumbColor = thumbColor
        self.baseColor  = baseColor
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base plate
                Circle()
                    .fill(baseColor)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                // Thumb knob
                Circle()
                    .fill(thumbColor.opacity(0.9))
                    .frame(width: geo.size.width * 0.38, height: geo.size.height * 0.38)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .offset(thumbOffset)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let delta  = CGSize(
                            width:  value.location.x - center.x,
                            height: value.location.y - center.y
                        )
                        let distance = sqrt(delta.width * delta.width + delta.height * delta.height)
                        let clamped  = min(distance, maxRadius)
                        let angle    = atan2(delta.height, delta.width)
                        thumbOffset  = CGSize(
                            width:  cos(angle) * clamped,
                            height: sin(angle) * clamped
                        )
                        // Normalise to -1 … 1
                        let nx = Float(thumbOffset.width  / maxRadius)
                        let ny = Float(thumbOffset.height / maxRadius)
                        router.send(.axisChanged(axisX, nx))
                        router.send(.axisChanged(axisY, ny))
                    }
                    .onEnded { _ in
                        isDragging  = false
                        thumbOffset = .zero
                        router.send(.axisChanged(axisX, 0))
                        router.send(.axisChanged(axisY, 0))
                    }
            )
            .animation(isDragging ? nil : .spring(response: 0.2, dampingFraction: 0.6), value: thumbOffset)
        }
    }
}

// MARK: - CompanionControllerDpad

/// A cross-shaped D-pad that emits discrete button events.
/// Each quadrant maps to a directional button in the CompanionInputRouter.
public struct CompanionControllerDpad: View {

    private let router: CompanionInputRouter
    @State private var activeDirection: Set<CompanionButton> = []

    public init(router: CompanionInputRouter) {
        self.router = router
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background cross shape using overlapping rectangles
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: geo.size.width, height: geo.size.height / 3)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: geo.size.width / 3, height: geo.size.height)

                // Directional indicators
                VStack(spacing: 0) {
                    dpadArrow(button: .dpadUp, symbol: "chevron.up")
                    Spacer()
                    dpadArrow(button: .dpadDown, symbol: "chevron.down")
                }
                HStack(spacing: 0) {
                    dpadArrow(button: .dpadLeft, symbol: "chevron.left")
                    Spacer()
                    dpadArrow(button: .dpadRight, symbol: "chevron.right")
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        updateDirections(
                            from: CGPoint(x: value.location.x - center.x,
                                          y: value.location.y - center.y),
                            threshold: geo.size.width * 0.15
                        )
                    }
                    .onEnded { _ in
                        releaseAll()
                    }
            )
        }
    }

    // MARK: - Private helpers

    @ViewBuilder
    private func dpadArrow(button: CompanionButton, symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(activeDirection.contains(button) ? .white : Color.white.opacity(0.5))
            .padding(8)
    }

    private func updateDirections(from offset: CGPoint, threshold: CGFloat) {
        var next: Set<CompanionButton> = []
        if offset.y < -threshold { next.insert(.dpadUp)    }
        if offset.y >  threshold { next.insert(.dpadDown)  }
        if offset.x < -threshold { next.insert(.dpadLeft)  }
        if offset.x >  threshold { next.insert(.dpadRight) }

        let pressed  = next.subtracting(activeDirection)
        let released = activeDirection.subtracting(next)
        pressed.forEach  { router.send(.buttonDown($0)) }
        released.forEach { router.send(.buttonUp($0))   }
        activeDirection = next
    }

    private func releaseAll() {
        activeDirection.forEach { router.send(.buttonUp($0)) }
        activeDirection = []
    }
}
#endif
