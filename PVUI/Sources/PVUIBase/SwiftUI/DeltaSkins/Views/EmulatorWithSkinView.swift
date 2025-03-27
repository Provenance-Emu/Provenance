import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVSystems

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore

    var body: some View {
        // Just show the default controller skin
        defaultControllerSkin()
    }

    /// Default controller skin as a fallback
    private func defaultControllerSkin() -> some View {
        VStack(spacing: 20) {
            // D-Pad
            dPadView()

            // Action buttons
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    circleButton(label: "Y", color: .yellow)
                    circleButton(label: "X", color: .blue)
                }

                VStack(spacing: 10) {
                    circleButton(label: "B", color: .red)
                    circleButton(label: "A", color: .green)
                }
            }

            // Start/Select buttons
            HStack(spacing: 20) {
                pillButton(label: "SELECT", color: .black)
                pillButton(label: "START", color: .black)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(20)
    }

    /// D-Pad view
    private func dPadView() -> some View {
        VStack(spacing: 0) {
            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)

                Button(action: {}) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }

            Button(action: {}) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }

    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
    }

    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
    }
}
