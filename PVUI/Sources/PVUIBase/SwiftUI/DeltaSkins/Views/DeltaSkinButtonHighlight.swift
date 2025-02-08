import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct DeltaSkinButtonHighlight: View {
    let frame: CGRect
    let mappingSize: CGSize
    let previewSize: CGSize
    let buttonId: String

    @State private var isAnimating = false

    private func createHighlightEffect(size: CGSize) -> some View {
        let radialGradient = CIImage(color: CIColor(color: UIColor.white))
            .cropped(to: CGRect(origin: .zero, size: size))
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 8
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputBrightnessKey: 0.3
            ])
            .applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: 5,
                kCIInputIntensityKey: 0.6
            ])

        return Image(uiImage: UIImage(ciImage: radialGradient))
            .resizable()
            .blendMode(.softLight)
            .opacity(isAnimating ? 0.4 : 0.7)
    }

    private func highlightShape(for buttonId: String, in frame: CGRect) -> some Shape {
        switch buttonId {
        case "up":
            return AnyShape(Rectangle().path(in: CGRect(
                x: frame.width * 0.3,
                y: 0,
                width: frame.width * 0.4,
                height: frame.height * 0.4
            )))
        case "down":
            return AnyShape(Rectangle().path(in: CGRect(
                x: frame.width * 0.3,
                y: frame.height * 0.6,
                width: frame.width * 0.4,
                height: frame.height * 0.4
            )))
        case "left":
            return AnyShape(Rectangle().path(in: CGRect(
                x: 0,
                y: frame.height * 0.3,
                width: frame.width * 0.4,
                height: frame.height * 0.4
            )))
        case "right":
            return AnyShape(Rectangle().path(in: CGRect(
                x: frame.width * 0.6,
                y: frame.height * 0.3,
                width: frame.width * 0.4,
                height: frame.height * 0.4
            )))
        default:
            return AnyShape(Circle())
        }
    }

    private func highlightFrame(in parentFrame: CGRect, for buttonId: String) -> CGRect {
        let width = parentFrame.width
        let height = parentFrame.height

        switch buttonId {
        case "up":
            return CGRect(
                x: parentFrame.minX + width * 0.3,
                y: parentFrame.minY,
                width: width * 0.4,
                height: height * 0.4
            )
        case "down":
            return CGRect(
                x: parentFrame.minX + width * 0.3,
                y: parentFrame.maxY - height * 0.4,
                width: width * 0.4,
                height: height * 0.4
            )
        case "left":
            return CGRect(
                x: parentFrame.minX,
                y: parentFrame.minY + height * 0.3,
                width: width * 0.4,
                height: height * 0.4
            )
        case "right":
            return CGRect(
                x: parentFrame.maxX - width * 0.4,
                y: parentFrame.minY + height * 0.3,
                width: width * 0.4,
                height: height * 0.4
            )
        default:
            return parentFrame
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / mappingSize.width,
                geometry.size.height / mappingSize.height
            )

            let scaledSkinWidth = mappingSize.width * scale
            let scaledSkinHeight = mappingSize.height * scale
            let xOffset = (geometry.size.width - scaledSkinWidth) / 2

            let hasScreenPosition = true
            let yOffset: CGFloat = hasScreenPosition ?
                ((geometry.size.height - scaledSkinHeight) / 2) :
                (geometry.size.height - scaledSkinHeight)

            let scaledFrame = CGRect(
                x: frame.minX * scale + xOffset,
                y: yOffset + (frame.minY * scale),
                width: frame.width * scale,
                height: frame.height * scale
            )

            let highlightFrame = highlightFrame(in: scaledFrame, for: buttonId)

            ZStack {
                // Base glow with shape mask
                createHighlightEffect(size: CGSize(width: highlightFrame.width * 1.2, height: highlightFrame.height * 1.2))
                    .mask {
                        highlightShape(for: buttonId, in: CGRect(origin: .zero, size: CGSize(width: highlightFrame.width * 1.2, height: highlightFrame.height * 1.2)))
                    }
                    .scaleEffect(isAnimating ? 0.95 : 1.0)

                // Inner highlight with shape mask
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: highlightFrame.width * 0.8, height: highlightFrame.height * 0.8)
                    .blur(radius: 5)
                    .blendMode(.plusLighter)
                    .mask {
                        highlightShape(for: buttonId, in: CGRect(origin: .zero, size: CGSize(width: highlightFrame.width * 0.8, height: highlightFrame.height * 0.8)))
                    }
                    .scaleEffect(isAnimating ? 0.9 : 1.0)
            }
            .position(x: highlightFrame.midX, y: highlightFrame.midY)
            .animation(.easeOut(duration: 0.2), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
        }
    }
}
