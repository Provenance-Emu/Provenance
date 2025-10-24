import SwiftUI

/// Handles transparent button overlays for Delta skins
struct DeltaSkinButtonOverlay: View {
    let button: DeltaSkinButton
    let skinImage: UIImage
    let isTranslucent: Bool

    /// Extract the button region from the source image
    private func extractButtonRegion() -> UIImage? {
        let scale = skinImage.scale
        let buttonRect = CGRect(
            x: button.frame.origin.x * skinImage.size.width * scale,
            y: button.frame.origin.y * skinImage.size.height * scale,
            width: button.frame.size.width * skinImage.size.width * scale,
            height: button.frame.size.height * skinImage.size.height * scale
        )

        // Create graphics context for the button region
        UIGraphicsBeginImageContextWithOptions(buttonRect.size, false, scale)
        defer { UIGraphicsEndImageContext() }

        // Draw the specific region from the source image
        skinImage.draw(at: CGPoint(
            x: -buttonRect.origin.x,
            y: -buttonRect.origin.y
        ))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    var body: some View {
        if let buttonImage = extractButtonRegion() {
            Image(uiImage: buttonImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(isTranslucent ? 0.8 : 1.0) // Adjust opacity if translucent
                .allowsHitTesting(false) // Let touches pass through to hit testing layer
        }
    }
}

/// Container view for handling button overlays
struct DeltaSkinButtonOverlayContainer: View {
    let buttonGroup: DeltaSkinButtonGroup
    let skinImage: UIImage

    var body: some View {
        ZStack {
            // Draw game screen if translucent
            if buttonGroup.translucent == true {
                Color.clear // This will let the game screen show through
            }

            // Draw button overlays
            ForEach(buttonGroup.buttons) { button in
                DeltaSkinButtonOverlay(
                    button: button,
                    skinImage: skinImage,
                    isTranslucent: buttonGroup.translucent ?? false
                )
                .position(
                    x: button.frame.midX,
                    y: button.frame.midY
                )
            }
        }
    }
}
