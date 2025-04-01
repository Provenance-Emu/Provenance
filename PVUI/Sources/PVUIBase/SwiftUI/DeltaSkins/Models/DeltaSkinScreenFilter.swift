import CoreImage
import CoreGraphics
import UIKit
import PVLibrary

/// Custom filter for screen effects in Delta skins
public class DeltaSkinScreenFilter {
    public let filter: CIFilter
    public let center: CGPoint?
    public let radius: CGFloat
    
    /// Metadata for additional information (display name, identifier, etc.)
    public var metadata: [String: Any] = [:]

    public init?(filterInfo: DeltaSkin.FilterInfo) {
        // Handle different filter types
        switch filterInfo.name {
        case "CIGaussianBlur":
            guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
            self.filter = filter

            // Extract radius and center
            if case .number(let radius) = filterInfo.parameters["inputRadius"] {
                self.radius = CGFloat(radius)
            } else {
                self.radius = 2.0 // Default radius
            }

            if case .vector(let x, let y) = filterInfo.parameters["inputCenter"] {
                self.center = CGPoint(x: Double(x), y: Double(y))
            } else {
                self.center = nil
            }

        default:
            // Handle other filter types normally
            guard let filter = CIFilter(name: filterInfo.name) else { return nil }
            self.filter = filter
            self.radius = 0
            self.center = nil

            // Apply standard parameters
            filterInfo.parameters.forEach { key, value in
                switch value {
                case .number(let num):
                    filter.setValue(num as NSNumber, forKey: key)
                case .vector(let x, let y):
                    filter.setValue(CIVector(x: CGFloat(x), y: CGFloat(y)), forKey: key)
                case .color(let r, let g, let b):
                    filter.setValue(CIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b)), forKey: key)
                case .rectangle(let x, let y, let width, let height):
                    filter.setValue(CIVector(x: CGFloat(x), y: CGFloat(y), z: CGFloat(width), w: CGFloat(height)), forKey: key)
                }
            }
        }
    }

    /// Apply the filter to a specific region of the screen
    public func apply(to image: CIImage, in frame: CGRect) -> CIImage? {
        switch filter.name {
        case "CIGaussianBlur":
            // Create blur effect centered on game screen
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(radius as NSNumber, forKey: kCIInputRadiusKey)

            guard let blurredImage = filter.outputImage else { return nil }

            if let center = center {
                // Create a radial mask for varying blur intensity
                let maskGenerator = CIFilter(name: "CIRadialGradient")
                maskGenerator?.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
                maskGenerator?.setValue(radius as NSNumber, forKey: "inputRadius0")
                maskGenerator?.setValue(radius * 2 as NSNumber, forKey: "inputRadius1")
                maskGenerator?.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
                maskGenerator?.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 1), forKey: "inputColor1")

                guard let mask = maskGenerator?.outputImage else { return blurredImage }

                // Blend original and blurred image using the mask
                let blendFilter = CIFilter(name: "CIBlendWithMask")
                blendFilter?.setValue(image, forKey: kCIInputImageKey)
                blendFilter?.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
                blendFilter?.setValue(mask, forKey: kCIInputMaskImageKey)

                return blendFilter?.outputImage
            } else {
                return blurredImage
            }

        default:
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
        }
    }
}


