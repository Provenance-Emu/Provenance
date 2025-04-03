import SwiftUI

/// View that shows button press effects similar to Delta
struct DeltaSkinButtonPressEffect: View {
    let isPressed: Bool
    let frame: CGRect
    let effect: ButtonPressEffect
    let color: Color = .white
    let opacity: Double = 0.8

    private let overlaySize: CGFloat = 40
    private let lineWidth: CGFloat = 4

    var body: some View {
        Group {
            switch effect {
            case .bubble:
                bubbleEffect
            case .ring:
                ringEffect
            case .glow:
                glowEffect
            }
        }
        .opacity(isPressed ? opacity : 0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }

    private var bubbleEffect: some View {
        ZStack {
            // Gradient bubble
            RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(opacity),
                    color.opacity(0.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: overlaySize - (lineWidth / 2)
            )

            // Ring outline
            Circle()
                .strokeBorder(color.opacity(opacity), lineWidth: lineWidth)
                .frame(width: overlaySize * 2, height: overlaySize * 2)
        }
    }

    private var ringEffect: some View {
        Circle()
            .strokeBorder(color.opacity(opacity), lineWidth: lineWidth)
            .frame(width: overlaySize * 2, height: overlaySize * 2)
    }

    private var glowEffect: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                color.opacity(0.0),
                color.opacity(opacity)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: overlaySize
        )
    }
}
