//
//  UIImage+Effects.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/9/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit
import CoreGraphics
import AVFoundation
import AVFoundation.AVGeometry

extension UIImage {
    var pixelated: UIImage? {
        guard let currentCGImage: CGImage = self.cgImage else { return nil }
        let currentCIImage = CIImage(cgImage: currentCGImage)

        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(currentCIImage, forKey: kCIInputImageKey)
        filter.setValue(12, forKey: kCIInputScaleKey)
        guard let outputImage = filter.outputImage else { return nil}

        let context = CIContext()

        guard let cgimg = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        let processedImage = UIImage(cgImage: cgimg)
        return processedImage
    }
    
    class func image(withPDFData data: Data, targetSize: CGSize) -> UIImage?
    {
        guard targetSize.width > 0 && targetSize.height > 0 else { return nil }
        
        guard
            let dataProvider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(dataProvider),
            let page = document.page(at: 1)
            else { return nil }
        
        let pageFrame = page.getBoxRect(.cropBox)
        
        var destinationFrame = AVMakeRect(aspectRatio: pageFrame.size, insideRect: CGRect(origin: CGPoint.zero, size: targetSize))
        destinationFrame.origin = CGPoint.zero
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let imageRenderer = UIGraphicsImageRenderer(bounds: destinationFrame, format: format)
        
        let image = imageRenderer.image { (imageRendererContext) in
            
            let context = imageRendererContext.cgContext
            
            // Save state
            context.saveGState()
            
            // Flip coordinate system to match Quartz system
            let transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: -1.0).translatedBy(x: 0.0, y: -targetSize.height)
            context.concatenate(transform)
            
            // Calculate rendering frames
            destinationFrame = destinationFrame.applying(transform)
            
            let aspectScale = min(destinationFrame.width / pageFrame.width, destinationFrame.height / pageFrame.height)
            
            // Ensure aspect ratio is preserved
            var drawingFrame = pageFrame.applying(CGAffineTransform(scaleX: aspectScale, y: aspectScale))
            drawingFrame.origin.x = destinationFrame.midX - (drawingFrame.width / 2.0)
            drawingFrame.origin.y = destinationFrame.midY - (drawingFrame.height / 2.0)
            
            // Scale the context
            context.translateBy(x: destinationFrame.minX, y: destinationFrame.minY)
            context.scaleBy(x: aspectScale, y: aspectScale)
            
            // Render the PDF
            context.drawPDFPage(page)
            
            // Restore state
            context.restoreGState()
        }
        
        return image
    }
}
