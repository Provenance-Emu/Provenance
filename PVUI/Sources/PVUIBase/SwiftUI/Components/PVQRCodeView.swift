//
//  PVQRCodeView.swift
//  PVUIBase
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A cross-platform SwiftUI QR code view backed by Core Image's
//  `CIQRCodeGenerator`. Works on iOS, tvOS, and macOS (Catalyst/AppKit).
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// A pixel-perfect QR code view backed by `CIQRCodeGenerator`.
///
/// Scales to fill the available square while staying sharp
/// (`.interpolation(.none)` is applied automatically).
///
/// ```swift
/// // Basic usage
/// PVQRCodeView("provenance://netplay/join?host=...")
///     .frame(width: 160, height: 160)
///
/// // With a Provenance accent overlay and label
/// PVQRCodeView("https://provenance-emu.com", label: "provenance-emu.com")
///     .frame(width: 200, height: 200)
/// ```
public struct PVQRCodeView: View {

    // MARK: - Public types

    /// Reed-Solomon error-correction level.
    ///
    /// Higher levels recover from more damage but produce denser codes.
    /// Use `.quarter` or `.high` if you plan to add a logo overlay.
    public enum CorrectionLevel: String {
        case low     = "L"  // ~7 %  recovery
        case medium  = "M"  // ~15 % recovery
        case quarter = "Q"  // ~25 % recovery
        case high    = "H"  // ~30 % recovery
    }

    // MARK: - Properties

    public let content: String
    private let correctionLevel: CorrectionLevel
    /// Optional short label rendered below the QR code.
    private let label: String?

    // Shared context — Metal-backed when available, otherwise software.
    private static let ciContext = CIContext()

    // MARK: - Init

    public init(
        _ content: String,
        correctionLevel: CorrectionLevel = .medium,
        label: String? = nil
    ) {
        self.content = content
        self.correctionLevel = correctionLevel
        self.label = label
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                Group {
                    if side > 0, let cgImage = makeQRImage(side: side) {
                        nativeImage(from: cgImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        // Placeholder while geometry resolves
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)

            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Private helpers

    private func makeQRImage(side: CGFloat) -> CGImage? {
        guard !content.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = correctionLevel.rawValue
        guard let raw = filter.outputImage else { return nil }
        // Scale up from the tiny native pixel grid to the display size
        let scale = side / raw.extent.size.width
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return Self.ciContext.createCGImage(scaled, from: scaled.extent)
    }

    /// Wraps a `CGImage` in a SwiftUI `Image` using the platform-native image type.
    @ViewBuilder
    private func nativeImage(from cgImage: CGImage) -> Image {
#if canImport(UIKit)
        // UIKit is available on both iOS and tvOS
        Image(uiImage: UIImage(cgImage: cgImage))
#elseif canImport(AppKit)
        Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
#else
        // Fallback — should never be reached given current platform targets
        Image(systemName: "qrcode")
#endif
    }
}

// MARK: - Previews

#if DEBUG
#Preview("URL") {
    PVQRCodeView(
        "provenance://netplay/join?host=192.168.1.42&port=55435&game=Street+Fighter+II",
        label: "Scan to join"
    )
    .frame(width: 200, height: 220)
    .padding()
}

#Preview("Short text") {
    PVQRCodeView("Hello, Provenance!")
        .frame(width: 120, height: 120)
}
#endif
