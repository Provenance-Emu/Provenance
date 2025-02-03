//
//  UIImage+Scaling.swift
//  Provenance
//
//  Created by Joseph Mattiello on 01/11/2023.
//  Copyright (c) 2023 Joseph Mattiello. All rights reserved.
//

import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit

public extension UIImage {
    #if !os(watchOS)
    func scalePreservingAspectRatio(width: Int, height: Int) -> UIImage {
        let widthRatio = CGFloat(width) / size.width
        let heightRatio = CGFloat(height) / size.height

        let scaleFactor = min(widthRatio, heightRatio)

        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize,
            format: format
        )

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }

        return scaledImage
    }
    #endif

    func scaledImage(withMaxResolution maxResolution: Int) -> UIImage? {
        guard let imgRef = cgImage else { return nil }
        let width = imgRef.width
        let height = imgRef.height

        // Calculate the aspect ratio
        let aspectRatio = Double(width) / Double(height)

        // Determine new dimensions while maintaining aspect ratio
        var newWidth = width
        var newHeight = height

        if width > height {
            if width > maxResolution {
                newWidth = maxResolution
                newHeight = Int(Double(newWidth) / aspectRatio)
            }
        } else {
            if height > maxResolution {
                newHeight = maxResolution
                newWidth = Int(Double(newHeight) * aspectRatio)
            }
        }

        // Create a new bitmap context with the correct size
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(data: nil,
                                      width: newWidth,
                                      height: newHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }

        // Set the quality level
        context.interpolationQuality = .high

        // Draw the image to the context
        context.draw(imgRef, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        // Create a new image from the context
        guard let scaledImageRef = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: scaledImageRef)
    }
}
#else
import AppKit
public typealias UIImage = NSImage
#endif
