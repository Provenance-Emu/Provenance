import SwiftUI

/// Visual indicator shown on buttons that are in "sticky" (toggle-held) mode.
/// Displays an orange highlight and a small lock icon badge at the top-right corner.
struct DeltaSkinStickyIndicator: View {
    let frame: CGRect
    let mappingSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / mappingSize.width,
                geometry.size.height / mappingSize.height
            )

            let scaledSkinWidth = mappingSize.width * scale
            let scaledSkinHeight = mappingSize.height * scale
            let xOffset = (geometry.size.width - scaledSkinWidth) / 2
            let yOffset = (geometry.size.height - scaledSkinHeight) / 2

            let scaledFrame = CGRect(
                x: frame.minX * scale + xOffset,
                y: yOffset + (frame.minY * scale),
                width: frame.width * scale,
                height: frame.height * scale
            )

            ZStack {
                // Orange glow background to indicate sticky state
                RoundedRectangle(cornerRadius: scaledFrame.width * 0.15)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: scaledFrame.width, height: scaledFrame.height)
                    .position(x: scaledFrame.midX, y: scaledFrame.midY)

                // Orange border highlight
                RoundedRectangle(cornerRadius: scaledFrame.width * 0.15)
                    .strokeBorder(Color.orange.opacity(0.6), lineWidth: 2)
                    .frame(width: scaledFrame.width, height: scaledFrame.height)
                    .position(x: scaledFrame.midX, y: scaledFrame.midY)

                // Lock icon badge at top-right corner
                let badgeSize: CGFloat = max(min(scaledFrame.width, scaledFrame.height) * 0.35, 16)
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.85))
                        .frame(width: badgeSize, height: badgeSize)

                    Image(systemName: "lock.fill")
                        .font(.system(size: badgeSize * 0.5, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(
                    x: scaledFrame.maxX - badgeSize * 0.3,
                    y: scaledFrame.minY + badgeSize * 0.3
                )
            }
        }
    }
}
