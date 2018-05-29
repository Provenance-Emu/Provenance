//
//  UILabel+Theming.swift
//  Provenance
//
//  Created by Sev Gerk on 5/19/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation

@IBDesignable class VerticalAlignLabel: UILabel {

    @IBInspectable var alignmentCode: Int = 0 {
        didSet {
            applyAlignmentCode()
        }
    }

    func applyAlignmentCode() {
        switch alignmentCode {
        case 0:
            verticalAlignment = .top
        case 1:
            verticalAlignment = .topcenter
        case 2:
            verticalAlignment = .middle
        case 3:
            verticalAlignment = .bottom
        default:
            break
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.applyAlignmentCode()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        self.applyAlignmentCode()
    }

    enum VerticalAlignment {
        case top
        case topcenter
        case middle
        case bottom
    }

    var verticalAlignment : VerticalAlignment = .top {
        didSet {
            setNeedsDisplay()
        }
    }

    override public func textRect(forBounds bounds: CGRect, limitedToNumberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: limitedToNumberOfLines)

        if #available(iOS 9.0, *) {
            if UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft {
                switch verticalAlignment {
                case .top:
                    return CGRect(x: self.bounds.size.width - rect.size.width, y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
                case .topcenter:
                    return CGRect(x: self.bounds.size.width - (rect.size.width / 2), y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
                case .middle:
                    return CGRect(x: self.bounds.size.width - rect.size.width, y: bounds.origin.y + (bounds.size.height - rect.size.height) / 2, width: rect.size.width, height: rect.size.height)
                case .bottom:
                    return CGRect(x: self.bounds.size.width - rect.size.width, y: bounds.origin.y + (bounds.size.height - rect.size.height), width: rect.size.width, height: rect.size.height)
                }
            } else {
                switch verticalAlignment {
                case .top:
                    return CGRect(x: bounds.origin.x, y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
                case .topcenter:
                    return CGRect(x: (self.bounds.size.width / 2 ) - (rect.size.width / 2), y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
                case .middle:
                    return CGRect(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height) / 2, width: rect.size.width, height: rect.size.height)
                case .bottom:
                    return CGRect(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height), width: rect.size.width, height: rect.size.height)
                }
            }
        } else {
            // Fallback on earlier versions
            return rect
        }
    }

    override public func drawText(in rect: CGRect) {
        let r = self.textRect(forBounds: rect, limitedToNumberOfLines: self.numberOfLines)
        super.drawText(in: r)
    }
}
