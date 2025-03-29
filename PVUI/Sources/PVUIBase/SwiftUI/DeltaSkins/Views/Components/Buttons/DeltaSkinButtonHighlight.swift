import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct DeltaSkinButtonHighlight: View {
    let frame: CGRect
    let mappingSize: CGSize
    let previewSize: CGSize
    let buttonId: String

    @State private var isAnimating = false

    @ViewBuilder
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
        // Check if this is a D-pad direction
        switch buttonId {
        case "up":
            return AnyShape(
                Path { path in
                    // Create a triangular shape pointing up
                    let centerX = frame.width / 2
                    let width = frame.width * 0.5
                    let height = frame.height * 0.45
                    
                    path.move(to: CGPoint(x: centerX, y: frame.height * 0.05))
                    path.addLine(to: CGPoint(x: centerX - width/2, y: height))
                    path.addLine(to: CGPoint(x: centerX + width/2, y: height))
                    path.closeSubpath()
                }
            )
        case "down":
            return AnyShape(
                Path { path in
                    // Create a triangular shape pointing down
                    let centerX = frame.width / 2
                    let width = frame.width * 0.5
                    let startY = frame.height * 0.55
                    
                    path.move(to: CGPoint(x: centerX, y: frame.height * 0.95))
                    path.addLine(to: CGPoint(x: centerX - width/2, y: startY))
                    path.addLine(to: CGPoint(x: centerX + width/2, y: startY))
                    path.closeSubpath()
                }
            )
        case "left":
            return AnyShape(
                Path { path in
                    // Create a triangular shape pointing left
                    let centerY = frame.height / 2
                    let width = frame.width * 0.45
                    let height = frame.height * 0.5
                    
                    path.move(to: CGPoint(x: frame.width * 0.05, y: centerY))
                    path.addLine(to: CGPoint(x: width, y: centerY - height/2))
                    path.addLine(to: CGPoint(x: width, y: centerY + height/2))
                    path.closeSubpath()
                }
            )
        case "right":
            return AnyShape(
                Path { path in
                    // Create a triangular shape pointing right
                    let centerY = frame.height / 2
                    let startX = frame.width * 0.55
                    let height = frame.height * 0.5
                    
                    path.move(to: CGPoint(x: frame.width * 0.95, y: centerY))
                    path.addLine(to: CGPoint(x: startX, y: centerY - height/2))
                    path.addLine(to: CGPoint(x: startX, y: centerY + height/2))
                    path.closeSubpath()
                }
            )
        default:
            // For non-directional buttons, use a circle or the appropriate shape
            if buttonId.contains("dpad") {
                // If it's the main D-pad button but no direction specified, show a small center circle
                return AnyShape(Circle().path(in: CGRect(
                    x: frame.width * 0.35,
                    y: frame.height * 0.35,
                    width: frame.width * 0.3,
                    height: frame.height * 0.3
                )))
            } else {
                // For regular buttons, use a circle that matches the button shape
                return AnyShape(Circle())
            }
        }
    }

    private func highlightFrame(in parentFrame: CGRect, for buttonId: String) -> CGRect {
        let width = parentFrame.width
        let height = parentFrame.height

        switch buttonId {
        case "up":
            return CGRect(
                x: parentFrame.minX,
                y: parentFrame.minY,
                width: width,
                height: height * 0.5
            )
        case "down":
            return CGRect(
                x: parentFrame.minX,
                y: parentFrame.minY + height * 0.5,
                width: width,
                height: height * 0.5
            )
        case "left":
            return CGRect(
                x: parentFrame.minX,
                y: parentFrame.minY,
                width: width * 0.5,
                height: height
            )
        case "right":
            return CGRect(
                x: parentFrame.minX + width * 0.5,
                y: parentFrame.minY,
                width: width * 0.5,
                height: height
            )
        default:
            // For the main D-pad button with no direction, use a smaller centered frame
            if buttonId.contains("dpad") {
                return CGRect(
                    x: parentFrame.minX + width * 0.25,
                    y: parentFrame.minY + height * 0.25,
                    width: width * 0.5,
                    height: height * 0.5
                )
            }
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
