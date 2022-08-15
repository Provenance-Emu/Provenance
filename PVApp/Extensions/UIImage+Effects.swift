//
//  UIImage+Effects.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public extension UIImage {
//    var pixelated: UIImage? {
//        return UIImage(cgImage: _pixelated())
//    }
    
    func pixelated(scale: Int = 12) {
        self.cgImage = _pixelated(scale: scale)
    }
    
//    mutating
    func pixelate(scale: Int = 12) {
        self.cgImage = _pixelated(scale: scale)
    }
    
    private func _pixelated(scale: Int = 12) -> CGImage? {
        guard let currentCGImage = self.cgImage else { return nil }
        let currentCIImage = CIImage(cgImage: currentCGImage)

        guard let filter = CIFilter(name: "CIPixellate")  else { return nil }
        filter.setValue(currentCIImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        guard let outputImage = filter.outputImage else { return }

        let context = CIContext()

        let cgimg = context.createCGImage(outputImage, from: outputImage.extent)
        return cgimg
    }
}
