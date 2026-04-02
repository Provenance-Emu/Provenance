///
/// MouseCursorOverlayView.swift
/// PVUI
///
/// A lightweight SwiftUI view that renders a visible mouse cursor over the emulator
/// Metal/GL surface. Position is driven by the normalised (0–1) coordinate that
/// the libretro mouse pipeline already tracks.
///
/// Usage
/// -----
/// Embed via a `UIHostingController` over the emulator view:
///
///     let cursor = MouseCursorOverlayView()
///     let host   = UIHostingController(rootView: cursor)
///     host.view.isUserInteractionEnabled = false   // pass-through touches
///     view.addSubview(host.view)
///
/// Then, whenever the core updates its mouse position, post:
///
///     NotificationCenter.default.post(
///         name: .PVMousePositionDidChange,
///         object: nil,
///         userInfo: [PVMousePositionKey: NSValue(cgPoint: normalizedPoint)]
///     )
///
/// The view subscribes to that notification and moves the cursor arrow accordingly.
///

#if canImport(UIKit)
import SwiftUI
import Combine
import PVCoreBridge

// Notification constants `PVMousePositionDidChange`, `PVMouseButtonDidPress`, and
// `PVMousePositionKey` are defined in PVCoreBridge/GCMouseMouseResponderDriver.swift
// as the canonical cross-module integration point. No redefinition needed here.

// MARK: - Cursor overlay

/// A pass-through SwiftUI view that draws an arrow cursor at the current
/// normalised mouse position within its parent bounds.
public struct MouseCursorOverlayView: View {
    // MARK: State
    /// Normalised position (0–1) updated via `PVMousePositionDidChange` notification.
    @State private var normalizedPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// True while a click animation is in progress.
    @State private var isClicking: Bool = false
    /// True once the cursor should be hidden (after idle timeout).
    /// Starts hidden so new users aren't confused by a static cursor on launch.
    @State private var isHidden: Bool = true

    // MARK: Configuration
    private let cursorSize: CGFloat = 24
    private let idleTimeout: TimeInterval = 2.0

    // MARK: Private state
    @State private var hideTask: Task<Void, Never>? = nil

    public init() {}

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            if !isHidden {
                CursorArrowShape()
                    .fill(Color.white)
                    .overlay(
                        CursorArrowShape()
                            .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
                    )
                    .frame(width: cursorSize, height: cursorSize)
                    .scaleEffect(isClicking ? 1.4 : 1.0)
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isClicking)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                    .position(
                        x: normalizedPosition.x * geo.size.width,
                        y: normalizedPosition.y * geo.size.height
                    )
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
        .onReceive(
            NotificationCenter.default.publisher(for: .PVMousePositionDidChange)
        ) { notification in
            guard let value = notification.userInfo?[PVMousePositionKey] as? NSValue else { return }
            let pt = value.cgPointValue
            withAnimation(.linear(duration: 0.016)) {
                normalizedPosition = pt
                isHidden = false
            }
            scheduleHide()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .PVMouseButtonDidPress)
        ) { _ in
            isHidden = false
            isClicking = true
            scheduleHide()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                isClicking = false
            }
        }
    }

    // MARK: - Helpers

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(idleTimeout * 1_000_000_000))
                withAnimation(.easeOut(duration: 0.3)) { isHidden = true }
            } catch {}
        }
    }
}

// MARK: - Cursor arrow shape

/// A simple arrow-pointer shape reminiscent of the classic macOS cursor.
private struct CursorArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // Arrow drawn from tip (top-left) clockwise
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))                      // tip
        path.addLine(to: CGPoint(x: 0, y: h * 0.85))            // left edge down
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.62))     // inner notch
        path.addLine(to: CGPoint(x: w * 0.48, y: h))            // tail bottom
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.94))     // tail right
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.55))     // inner notch right
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.55))     // right edge
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct MouseCursorOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            MouseCursorOverlayView()
        }
        .frame(width: 320, height: 240)
    }
}
#endif
#endif // canImport(UIKit)
