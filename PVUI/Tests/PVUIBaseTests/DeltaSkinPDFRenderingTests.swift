//
//  DeltaSkinPDFRenderingTests.swift
//  PVUIBaseTests
//
//  Regression tests for UIImage(pdfData:preserveTransparency:size:) — specifically
//  verifying that button overlay assets render with transparent backgrounds by default
//  (regression introduced in ec27c9814 and fixed by always passing preserveTransparency: true
//  when loading PDF-based skin assets).
//

#if canImport(UIKit)
import Foundation
import Testing
import UIKit
@testable import PVUIBase

// MARK: - Helpers

private func makePDFData(size: CGSize = CGSize(width: 100, height: 100)) -> Data {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
    return renderer.pdfData { ctx in
        ctx.beginPage()
        // Draw a partially transparent rect so the PDF has some real content
        UIColor(white: 0.5, alpha: 0.5).setFill()
        ctx.fill(CGRect(x: 10, y: 10, width: 80, height: 80))
    }
}

private func hasAlphaChannel(_ image: UIImage) -> Bool {
    guard let info = image.cgImage?.alphaInfo else { return false }
    switch info {
    case .none, .noneSkipFirst, .noneSkipLast:
        return false
    default:
        return true
    }
}

// MARK: - Tests

@Suite("UIImage PDF Rendering — Transparency")
struct DeltaSkinPDFRenderingTests {

    private let pdfData = makePDFData()

    @Test("preserveTransparency: true produces an image with an alpha channel")
    func preserveTransparencyTrueHasAlpha() throws {
        let image = try #require(UIImage(pdfData: pdfData, preserveTransparency: true))
        #expect(hasAlphaChannel(image), "Expected alpha channel when preserveTransparency is true")
    }

    @Test("preserveTransparency: false produces an opaque image (no alpha channel)")
    func preserveTransparencyFalseIsOpaque() throws {
        let image = try #require(UIImage(pdfData: pdfData, preserveTransparency: false))
        #expect(!hasAlphaChannel(image), "Expected no alpha channel when preserveTransparency is false")
    }

    @Test("Default parameter preserves transparency (regression: was false, now true)")
    func defaultPreservesTransparency() throws {
        let image = try #require(UIImage(pdfData: pdfData))
        #expect(hasAlphaChannel(image), "Default should preserve transparency to avoid black-square regression")
    }

    @Test("Invalid PDF data returns nil")
    func invalidPDFReturnsNil() {
        let garbage = Data("not a pdf".utf8)
        let image = UIImage(pdfData: garbage, preserveTransparency: true)
        #expect(image == nil)
    }

    @Test("Rendered image has non-zero size")
    func renderedImageHasSize() throws {
        let requestedSize = CGSize(width: 64, height: 64)
        let image = try #require(UIImage(pdfData: pdfData, preserveTransparency: true, size: requestedSize))
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("Transparent pixels are actually clear when preserveTransparency is true")
    func transparentPixelsAreClear() throws {
        // Create a PDF with a fully transparent background and opaque content only in center
        let solidSize = CGSize(width: 10, height: 10)
        let solidPDF = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: solidSize)).pdfData { ctx in
            ctx.beginPage()
            // Only fill the very center with opaque red; corners stay transparent
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 4, y: 4, width: 2, height: 2))
        }

        let image = try #require(UIImage(pdfData: solidPDF, preserveTransparency: true, size: solidSize))
        guard let cgImage = image.cgImage else {
            Issue.record("No cgImage")
            return
        }

        // Sample a corner pixel — should be transparent (alpha == 0)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(
            data: nil,
            width: Int(solidSize.width),
            height: Int(solidSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(solidSize.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            Issue.record("Could not create CGContext")
            return
        }
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: solidSize))

        guard let data = ctx.data else {
            Issue.record("No pixel data")
            return
        }
        // Corner pixel (0,0) — RGBA bytes
        let bytes = data.bindMemory(to: UInt8.self, capacity: Int(solidSize.width) * Int(solidSize.height) * 4)
        let alpha = bytes[3] // alpha channel of first pixel
        #expect(alpha == 0, "Corner pixel should be fully transparent, got alpha=\(alpha)")
    }
}
#endif
