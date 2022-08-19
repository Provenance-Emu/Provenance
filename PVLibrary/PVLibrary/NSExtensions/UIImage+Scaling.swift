//
//  UIImage+Scaling.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit
import PVSupport

public extension UIImage {
    func scaledImage(withMaxResolution maxResolution: Int) -> UIImage? {
        guard let imgRef = self.cgImage else {
            ELOG("nil cgImage")
            return nil
        }
        
        let width = imgRef.width
        let height = imgRef.height
        
        var transform: CGAffineTransform = .identity
        var bounds: CGRect = .init(x: 0, y: 0, width: width, height: height)
        if width > maxResolution || height > maxResolution {
            let ratio = CGFloat(width / height)
            if ratio > 1 {
                bounds.size.width = CGFloat(maxResolution)
                bounds.size.height = bounds.size.width / ratio
            } else {
                bounds.size.height = CGFloat(maxResolution)
                bounds.size.width = bounds.size.height * ratio
            }
        }
        
        let widthF: CGFloat = CGFloat(width)
        let heightF: CGFloat = CGFloat(height)
        
        let scaleRatio: CGFloat = bounds.size.width / widthF
        let imageSize: CGSize = .init(width: width, height: height)
        var boundHeight: CGFloat = 0
        
        let orientation: UIImage.Orientation  = self.imageOrientation
        
        switch orientation {
        case .up:                                   // EXIF = 1
            transform = .identity
        case .upMirrored:                           // EXIF = 2
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0)
            transform = CGAffineTransformScale(transform, -1.0, 1.0)
        case .down:                                 // EXIF = 3
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height)
            transform = CGAffineTransformRotate(transform, Double.pi)
        case .downMirrored:                        // EXIF = 4
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height)
            transform = CGAffineTransformScale(transform, 1.0, -1.0)
        case .left:                                // EXIF = 6
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width)
            transform = CGAffineTransformRotate(transform, 3.0 * Double.pi / 2.0)
        case .leftMirrored:                        // EXIF = 5
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width)
            transform = CGAffineTransformScale(transform, -1.0, 1.0)
            transform = CGAffineTransformRotate(transform, 3.0 * Double.pi / 2.0)
        case .right:                                // EXIF = 8
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0)
            transform = CGAffineTransformRotate(transform, Double.pi / 2.0)
        case .rightMirrored:                        // EXIF = 7
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeScale(-1.0, 1.0)
            transform = CGAffineTransformRotate(transform, Double.pi / 2.0)
        @unknown default:
            NSException(name: .internalInconsistencyException, reason: "Invalid image orientation").raise()
        }
        
        UIGraphicsBeginImageContext(bounds.size)
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard let  context: CGContext = UIGraphicsGetCurrentContext() else {
            ELOG("UIGraphicsGetCurrentContext() == nil")
            return nil
        }
        
        if orientation == .right || orientation == .left {
            context.scaleBy(x: -scaleRatio, y: scaleRatio)
            context.translateBy(x: -heightF, y: 0)
        } else {
            context.scaleBy(x: scaleRatio, y: -scaleRatio)
            context.translateBy(x: 0, y: -heightF)
        }
        
        context.concatenate(transform)
        
        let rect = CGRectMake(0, 0, widthF, heightF)
        context.draw(imgRef, in: rect)

        guard let imageCopy = UIGraphicsGetImageFromCurrentImageContext() else {
            ELOG("UIGraphicsGetImageFromCurrentImageContext() == nil")
            return nil
        }
        
        return imageCopy
    }
}
