//
//  func.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

#if canImport(UIKit)
import UIKit
#endif

public
extension UIImage {
    class func image(withSize size: CGSize, color: UIColor, text: NSAttributedString) -> UIImage? {
        // UIGraphicsImageRenderer handles allocation failures gracefully (the older
        // UIGraphicsBeginImageContextWithOptions path would assert when the bitmap
        // context couldn't be allocated — particularly in tight-memory snapshot
        // contexts and on Catalyst).
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else {
            return nil
        }
        let rect = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setFillColor(color.cgColor)
            context.setStrokeColor(UIColor(white: 0.7, alpha: 0.6).cgColor)
            context.setLineWidth(0.5)
            context.fill(rect)
            var boundingRect = text.boundingRect(with: rect.size, options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
            boundingRect.origin = CGPoint(x: rect.midX - (boundingRect.width / 2), y: rect.midY - (boundingRect.height / 2))
            text.draw(in: boundingRect)
        }
    }

    func imageWithBorder(width: CGFloat, color: UIColor) -> UIImage? {
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
        //		imageView.contentMode = .center
        imageView.image = self
        //		imageView.layer.cornerRadius = square.width/2
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = width
        imageView.layer.borderColor = color.cgColor
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}
