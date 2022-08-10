//
//  UIImage+Effects.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/9/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit

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
}
