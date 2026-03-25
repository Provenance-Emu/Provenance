//
//  AirPlayRoutePickerView.swift
//  PVUI
//
//  SwiftUI wrappers for AVRoutePickerView so AirPlay can be surfaced
//  in the tile pause menu and the classic RetroMenuView.
//
//  Only compiled on iOS / macCatalyst — tvOS and macOS do not need
//  an in-app AirPlay button (Control Center handles it there).
//
//  Part of #2684 — Add AirPlay button to pause menu / RetroMenuView
//

#if os(iOS) || targetEnvironment(macCatalyst)
import AVKit
import SwiftUI
import UIKit
import PVLogging

// MARK: - AirPlayPickerTrigger

/// Invisible UIViewRepresentable that programmatically triggers the system
/// AirPlay route picker sheet when `show` transitions to `true`.
///
/// Embed this with a zero-size frame inside the pause menu overlay so it
/// is part of the view hierarchy (required for the picker to attach to
/// the correct window), then set `show = true` from your tile/button action.
struct AirPlayPickerTrigger: UIViewRepresentable {
    @Binding var show: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        // Completely invisible — this is a trigger-only helper.
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.tintColor = .clear
        view.prioritizesVideoDevices = true
        return view
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Only fire on the false → true transition; SwiftUI may call updateUIView
        // more than once per state change, and we must not open the sheet twice.
        guard show, !context.coordinator.didTrigger else {
            if !show { context.coordinator.didTrigger = false }
            return
        }
        context.coordinator.didTrigger = true
        // Find the internal UIButton recursively to be robust across iOS
        // view-hierarchy changes, then fire it to show the system sheet.
        if let button = firstButton(in: uiView) {
            button.sendActions(for: .touchUpInside)
        } else {
            // Fallback: nothing matched — log so failures are visible in debug builds.
            DLOG("[AirPlayPickerTrigger] Could not locate AVRoutePickerView's internal button; picker sheet will not appear.")
        }
        // Reset so subsequent taps work.
        DispatchQueue.main.async { self.show = false }
    }

    final class Coordinator {
        /// Tracks whether we have already fired the picker for the current `show == true` epoch.
        var didTrigger = false
    }

    /// Recursively searches `view` and its descendants for the first `UIButton`.
    private func firstButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton { return button }
        for subview in view.subviews {
            if let button = firstButton(in: subview) { return button }
        }
        return nil
    }
}

// MARK: - AirPlayMenuButton

/// A self-contained AirPlay button styled to match the retro-menu aesthetic.
/// It embeds an `AVRoutePickerView` directly so the system picker appears
/// when tapped — no trigger binding required.
///
/// Usage in RetroMenuView:
/// ```swift
/// AirPlayMenuButton()
/// ```
struct AirPlayMenuButton: View {
    /// Tint applied to the AVRoutePickerView icon (default: white).
    var tintColor: Color = .white
    /// Active (connected) tint color.
    var activeTintColor: Color = .retroCyan

    var body: some View {
        _AVRoutePickerRepresentable(
            tintColor: UIColor(tintColor),
            activeTintColor: UIColor(activeTintColor)
        )
    }
}

// MARK: - Internal UIViewRepresentable

/// Raw UIViewRepresentable wrapper — use `AirPlayMenuButton` instead.
private struct _AVRoutePickerRepresentable: UIViewRepresentable {
    var tintColor: UIColor
    var activeTintColor: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tintColor
        view.activeTintColor = activeTintColor
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}

#endif // os(iOS) || targetEnvironment(macCatalyst)
