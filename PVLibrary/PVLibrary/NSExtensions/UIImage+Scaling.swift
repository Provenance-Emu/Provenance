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
        guard let imgRef = self.cgImage() else {
            ELOG("nil cgImage")
            return nil
        }
        
        let width = imgRef.width
        let height = imgRef.height
        
        let transform: CGAffineTransform = .identity
        var bounds: CGRect = .init(x: 0, y: 0, width: width, height: height)
        if width > maxResolution || height > maxResolution {
            let ratio = width / height
            if ratio > 1 {
                bounds.size.width = maxResolution
                bounds.size.height = bounds.size.width / ratio
            } else {
                bounds.size.height = maxResolution
                bounds.size.width = bounds.size.height * ratio
            }
        }
        
        let scaleRatio = bounds.size.width / width
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
            transform = CGAffineTransformRotate(transform, M_PI)
        case .downMirrored:                        // EXIF = 4
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height)
            transform = CGAffineTransformScale(transform, 1.0, -1.0)
        case .left:                                // EXIF = 6
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width)
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0)
        case .leftMirrored:                        // EXIF = 5
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width)
            transform = CGAffineTransformScale(transform, -1.0, 1.0)
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0)
        case .right:                                // EXIF = 8
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0)
            transform = CGAffineTransformRotate(transform, M_PI / 2.0)
        case .rightMirrored:                        // EXIF = 7
            boundHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundHeight
            transform = CGAffineTransformMakeScale(-1.0, 1.0)
            transform = CGAffineTransformRotate(transform, M_PI / 2.0)
        @unknown default:
            NSException(name: .internalInconsistencyException, reason: "Invalid image orientation").raise()
        }
        
        UIGraphicsBeginImageContext(bounds.size)
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard var context: CGContext = UIGraphicsGetCurrentContext() else {
            ELOG("UIGraphicsGetCurrentContext() == nil")
            return nil
        }
        
        if orientation == .right || orientation == .left {
            context.scaleBy(x: -scaleRatio, y: scaleRatio)
            context.translateBy(x: -height, y: 0)
        } else {
            context.scaleBy(x: scaleRatio, y: -scaleRatio)
            context.translateBy(x: 0, y: -height)
        }
        
        context.concatenate(transform)
        
        CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef)
        guard let imageCopy = UIGraphicsGetImageFromCurrentImageContext() else {
            ELOG("UIGraphicsGetImageFromCurrentImageContext() == nil")
            return nil
        }
        
        return imageCopy
    }
}
