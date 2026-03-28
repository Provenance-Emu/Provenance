/// Generates scannable QR code images from cheat code data.
///
/// QR codes are encoded as a compact `provenance-cheat://` URL so that
/// they can be scanned by Provenance on another device, or by any QR
/// reader to copy the code manually.
///
/// URL format:
/// ```
/// provenance-cheat://v1?name=<encoded>&code=<encoded>&format=<encoded>&system=<encoded>&game=<encoded>
/// ```
///
/// - Note: Requires `CoreImage` which is available on iOS 17+, macOS 14+.

#if canImport(CoreImage) && canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import PVLibrary

// MARK: - Generator

/// Generates a QR code `UIImage` from a `SharedCheatEntry`.
public enum CheatQRCodeGenerator {

    /// Shared `CIContext` — creating one per call is expensive; reuse across renders.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Renders a square QR code image for `entry` at the specified output size.
    ///
    /// - Parameters:
    ///   - entry: The cheat to encode.
    ///   - size: Output image size in points (default 300 × 300).
    /// - Returns: A grayscale `UIImage`, or `nil` if CoreImage cannot generate the QR.
    public static func qrCode(for entry: SharedCheatEntry, size: CGFloat = 300) -> UIImage? {
        qrCode(for: entry.qrURLString, size: size)
    }

    /// Renders a QR code from any string payload.
    ///
    /// - Parameters:
    ///   - string: Payload to encode.
    ///   - size: Output image size in points.
    /// - Returns: A grayscale `UIImage`, or `nil` if the payload exceeds QR capacity.
    public static func qrCode(for string: String, size: CGFloat = 300) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"  // ~15% error correction — good balance for display

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up from the tiny native CIImage (typically ~33×33 px) to requested size.
        let scaleX = size / ciImage.extent.width
        let scaleY = size / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#endif // canImport(CoreImage) && canImport(UIKit)
