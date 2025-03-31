import SwiftUI

/// Overlay view that shows button hit areas and coordinates
struct DeltaSkinDebugOverlay: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let size: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let mappingSize = skin.mappingSize(for: traits),
               let buttons = skin.buttons(for: traits) {
                let scale = min(
                    size.width / mappingSize.width,
                    size.height / mappingSize.height
                )
                let xOffset = (size.width - (mappingSize.width * scale)) / 2
                let yOffset = (size.height - (mappingSize.height * scale)) / 2
                let offset = CGPoint(x: xOffset, y: yOffset)

                ZStack {
                    ForEach(buttons, id: \.id) { button in
                        let hitFrame = button.frame.insetBy(dx: -20, dy: -20)
                        let scaledHitFrame = scaledFrame(
                            hitFrame,
                            mappingSize: mappingSize,
                            scale: scale,
                            offset: offset
                        )
                        let scaledButtonFrame = scaledFrame(
                            button.frame,
                            mappingSize: mappingSize,
                            scale: scale,
                            offset: offset
                        )

                        ZStack {
                            // Hit area
                            Rectangle()
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                                .background(.red.opacity(0.1))
                                .frame(
                                    width: scaledHitFrame.width,
                                    height: scaledHitFrame.height
                                )
                                .position(
                                    x: scaledHitFrame.midX,
                                    y: scaledHitFrame.midY
                                )

                            // Button frame
                            Rectangle()
                                .stroke(.blue.opacity(0.5), lineWidth: 1)
                                .frame(
                                    width: scaledButtonFrame.width,
                                    height: scaledButtonFrame.height
                                )
                                .position(
                                    x: scaledButtonFrame.midX,
                                    y: scaledButtonFrame.midY
                                )

                            // Button info
                            VStack(spacing: 2) {
                                Text(button.id.components(separatedBy: "-").last ?? "")
                                    .font(.system(size: 8))
                                Text("(\(Int(button.frame.midX)), \(Int(button.frame.midY)))")
                                    .font(.system(size: 6))
                            }
                            .foregroundColor(.white)
                            .padding(2)
                            .background(.black.opacity(0.5))
                            .position(
                                x: scaledButtonFrame.midX,
                                y: scaledButtonFrame.midY
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    internal func scaledFrame(
        _ frame: CGRect,
        mappingSize: CGSize,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGRect {
        CGRect(
            x: frame.minX * scale + offset.x,
            y: frame.minY * scale + offset.y,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }
}

#Preview {
    DeltaSkinDebugOverlay(
        skin: MockDeltaSkin(),
        traits: DeltaSkinTraits(
            device: .iphone,
            displayType: .standard,
            orientation: .portrait
        ),
        size: CGSize(width: 300, height: 500)
    )
    .background(Color.black)
}
