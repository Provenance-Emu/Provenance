import SwiftUI

/// A small pulsing "T" badge overlay shown on buttons that have turbo/autofire enabled.
struct DeltaSkinTurboBadge: View {
    /// The frame of the button this badge belongs to, in the skin's coordinate space.
    let buttonFrame: CGRect
    /// The mapping size of the skin (used to scale the badge appropriately).
    let mappingSize: CGSize

    @State private var isPulsing = false

    var body: some View {
        let badgeSize: CGFloat = max(14, min(buttonFrame.width, buttonFrame.height) * 0.3)

        ZStack {
            // Background circle with pulsing glow
            Circle()
                .fill(Color.orange)
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: .orange.opacity(isPulsing ? 0.8 : 0.3), radius: isPulsing ? 6 : 2)
                .scaleEffect(isPulsing ? 1.15 : 1.0)

            // "T" label
            Text("T")
                .font(.system(size: badgeSize * 0.6, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .position(
            x: buttonFrame.maxX - badgeSize * 0.4,
            y: buttonFrame.minY + badgeSize * 0.4
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
