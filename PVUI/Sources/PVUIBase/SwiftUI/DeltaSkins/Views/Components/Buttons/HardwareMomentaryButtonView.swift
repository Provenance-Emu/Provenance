import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PVCoreBridge

// MARK: - Hardware Momentary Button View

/// Renders a physical-looking momentary push-button for hardware controls that
/// generate a single press+release edge (not a latched toggle).
///
/// Examples:
/// - Sega Master System PAUSE — sends an NMI to the Z80
/// - Arcade SERVICE button — enters test/dip-switch menu
///
/// - The button shows a pressed state while the finger is down, then fires the
///   `onPress` / `onRelease` callbacks so the emulator core sees the full edge.
/// - Works on both iOS and tvOS (no `DragGesture` dependency).
struct HardwareMomentaryButtonView: View {
    let descriptor: HardwareMomentaryDescriptor
    let onPress: (_ buttonId: String) -> Void
    let onRelease: (_ buttonId: String) -> Void

    @State private var isPressed: Bool = false

    private let accentColor = Color(red: 0.0, green: 0.8, blue: 0.9)
    private let pressedColor = Color(red: 0.99, green: 0.11, blue: 0.55)

    var body: some View {
        VStack(spacing: 4) {
            buttonBody
                .frame(width: 44, height: 28)
                #if os(tvOS)
                // On tvOS there is no touch — use a tap to send a momentary press+release.
                .onTapGesture { firePress() }
                #else
                // On iOS use DragGesture(minimumDistance:0) to capture down + up separately.
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed {
                                isPressed = true
                                onPress(descriptor.buttonId)
                                #if os(iOS)
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                #endif
                            }
                        }
                        .onEnded { _ in
                            if isPressed {
                                isPressed = false
                                onRelease(descriptor.buttonId)
                            }
                        }
                )
                #endif

            Text(descriptor.title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func firePress() {
        isPressed = true
        onPress(descriptor.buttonId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            onRelease(descriptor.buttonId)
        }
    }

    private var buttonBody: some View {
        ZStack {
            // Button background
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isPressed ? pressedColor : accentColor, lineWidth: 1.5)
                        .blur(radius: isPressed ? 3 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )

            // Icon / label
            Text(descriptor.label)
                .font(.system(size: 14))
                .foregroundColor(isPressed ? pressedColor : accentColor)
                .shadow(color: isPressed ? pressedColor : accentColor, radius: isPressed ? 4 : 1)
                .scaleEffect(isPressed ? 0.88 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: isPressed)
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.easeInOut(duration: 0.08), value: isPressed)
    }
}

// MARK: - Hardware Momentary Button Row

/// Lays out a horizontal row of momentary hardware buttons with consistent spacing.
struct HardwareMomentaryRowView: View {
    let buttons: [HardwareMomentaryDescriptor]
    let onPress: (_ buttonId: String) -> Void
    let onRelease: (_ buttonId: String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(buttons) { descriptor in
                HardwareMomentaryButtonView(
                    descriptor: descriptor,
                    onPress: onPress,
                    onRelease: onRelease
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Momentary Buttons") {
    VStack(spacing: 20) {
        HardwareMomentaryRowView(
            buttons: [
                HardwareMomentaryDescriptor(
                    id: "sms_pause",
                    title: "PAUSE",
                    label: "⏸",
                    buttonId: "start"
                )
            ],
            onPress: { id in print("Press: \(id)") },
            onRelease: { id in print("Release: \(id)") }
        )
        HardwareMomentaryRowView(
            buttons: [
                HardwareMomentaryDescriptor(
                    id: "arcade_service",
                    title: "SERVICE",
                    label: "⚙",
                    buttonId: "service"
                )
            ],
            onPress: { id in print("Press: \(id)") },
            onRelease: { id in print("Release: \(id)") }
        )
    }
    .padding()
    .background(Color(red: 0.05, green: 0.0, blue: 0.15))
}
#endif
