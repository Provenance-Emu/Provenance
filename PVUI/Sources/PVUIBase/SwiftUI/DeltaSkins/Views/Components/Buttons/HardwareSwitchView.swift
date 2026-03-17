import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hardware Switch View

/// Renders a physical-looking toggle switch for Atari-style difficulty / TV-type switches.
///
/// - Tapping the switch toggles its state and fires the appropriate button ID
///   through the provided `onToggle` callback.
/// - Designed to work on both iOS and tvOS (no DragGesture dependency).
struct HardwareSwitchView: View {
    let descriptor: HardwareSwitchDescriptor
    let onToggle: (_ buttonId: String, _ isOn: Bool) -> Void

    @State private var isOn: Bool

    /// Accent colour matching the retrowave skin palette
    private let accentColor = Color(red: 0.0, green: 0.8, blue: 0.9)
    private let activeColor = Color(red: 0.99, green: 0.11, blue: 0.55)

    init(
        descriptor: HardwareSwitchDescriptor,
        onToggle: @escaping (_ buttonId: String, _ isOn: Bool) -> Void
    ) {
        self.descriptor = descriptor
        self.onToggle = onToggle
        self._isOn = State(initialValue: descriptor.defaultState)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Switch body
            switchBody
                .frame(width: 52, height: 28)
                .onTapGesture { toggle() }

            // Title label
            Text(descriptor.title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var switchBody: some View {
        ZStack {
            // Track background
            Capsule()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(isOn ? activeColor : accentColor, lineWidth: 1.5)
                        .blur(radius: isOn ? 3 : 1)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )

            // Position labels
            HStack {
                Text(descriptor.positions.off.label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(isOn ? Color.white.opacity(0.3) : accentColor)
                    .frame(maxWidth: .infinity)

                Text(descriptor.positions.on.label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(isOn ? activeColor : Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)

            // Thumb / slider knob
            HStack {
                if isOn { Spacer() }

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                isOn ? activeColor.opacity(0.9) : accentColor.opacity(0.9),
                                isOn ? activeColor.opacity(0.6) : accentColor.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 22, height: 20)
                    .shadow(color: isOn ? activeColor : accentColor, radius: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                    )
                    // Grip lines
                    .overlay(
                        VStack(spacing: 3) {
                            ForEach(0..<3) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 10, height: 0.5)
                            }
                        }
                    )

                if !isOn { Spacer() }
            }
            .padding(.horizontal, 3)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
        }
    }

    private func toggle() {
        isOn.toggle()
        let position = isOn ? descriptor.positions.on : descriptor.positions.off
        onToggle(position.buttonId, isOn)
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

// MARK: - Hardware Switch Row

/// Lays out a horizontal row of hardware switches with consistent spacing.
struct HardwareSwitchRowView: View {
    let switches: [HardwareSwitchDescriptor]
    let onToggle: (_ buttonId: String, _ isOn: Bool) -> Void

    init(
        switches: [HardwareSwitchDescriptor],
        onToggle: @escaping (_ buttonId: String, _ isOn: Bool) -> Void
    ) {
        self.switches = switches
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(switches) { descriptor in
                HardwareSwitchView(descriptor: descriptor, onToggle: onToggle)
            }
        }
        .padding(.horizontal, 12)
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
#Preview("Hardware Switches") {
    VStack(spacing: 20) {
        HardwareSwitchRowView(
            switches: atari2600Switches(),
            onToggle: { id, on in print("Toggle: \(id) -> \(on)") }
        )
        HardwareSwitchRowView(
            switches: atari7800Switches(),
            onToggle: { id, on in print("Toggle: \(id) -> \(on)") }
        )
    }
    .padding()
    .background(Color(red: 0.05, green: 0.0, blue: 0.15))
}
#endif
