// TrackballLayout.swift
// PVUI
//
// Companion controller overlay for systems that use a trackball controller.
// Used for Atari 2600 Centipede, Missile Command, and other trackball games.
//
// A large circular trackpad simulates trackball rotation. Velocity is computed
// from drag speed and sent as axis values to the CompanionInputRouter.
//
// Input routing:
//   Trackball movement → CompanionAxisID.leftX / .leftY (velocity-based)
//   Fire button        → CompanionButton.south
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI
import PVPrimitives

// MARK: - TrackballLayout

/// System-specific companion overlay for trackball-based Atari 2600 games.
///
/// Layout (landscape):
/// ```
///       [ Large Trackball Circle ]
///
///           [   FIRE   ]
/// ```
public struct TrackballLayout: CompanionLayout {

    // MARK: - CompanionLayout

    /// Atari 2600 is the primary target (Centipede, Missile Command).
    public let systemID: String = SystemIdentifier.Atari2600.rawValue
    public var displayName: String { "Trackball" }
    public let inputRouter: CompanionInputRouter

    // MARK: - State

    @State private var previousLocation: CGPoint? = nil
    @State private var isDragging = false
    @State private var velocity: CGSize = .zero

    // MARK: - Init

    public init(router: CompanionInputRouter) {
        self.inputRouter = router
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // ── Trackball ─────────────────────────────────────────
                trackballView

                // ── Fire button ──────────────────────────────────────
                CompanionControllerButton(button: .south, router: inputRouter) {
                    Capsule()
                        .fill(Color.red.opacity(0.30))
                        .overlay(
                            Capsule().stroke(Color.red.opacity(0.7), lineWidth: 2)
                        )
                        .frame(width: 140, height: 52)
                        .overlay(
                            Text("FIRE")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        )
                }

                Spacer()
            }
        }
    }

    // MARK: - Trackball

    private var trackballView: some View {
        GeometryReader { geo in
            ZStack {
                // Outer ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isDragging ? 0.18 : 0.10),
                                Color.white.opacity(0.04),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width / 2
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

                // Inner highlight dot
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: geo.size.width * 0.12, height: geo.size.height * 0.12)
                    .offset(x: -geo.size.width * 0.18, y: -geo.size.height * 0.18)

                // Label
                Text("TRACKBALL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .offset(y: geo.size.height * 0.35)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        if let prev = previousLocation {
                            let dx = value.location.x - prev.x
                            let dy = value.location.y - prev.y
                            // Scale to -1…1 with a sensitivity factor
                            let scale: CGFloat = 0.03
                            let nx = Float((dx * scale).clamped(to: -1...1))
                            let ny = Float((dy * scale).clamped(to: -1...1))
                            inputRouter.send(.axisChanged(.leftX, nx))
                            inputRouter.send(.axisChanged(.leftY, ny))
                        }
                        previousLocation = value.location
                    }
                    .onEnded { _ in
                        isDragging       = false
                        previousLocation = nil
                        inputRouter.send(.axisChanged(.leftX, 0))
                        inputRouter.send(.axisChanged(.leftY, 0))
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 260, maxHeight: 260)
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TrackballLayout(router: CompanionInputRouter())
}
#endif

#endif // !os(tvOS)
