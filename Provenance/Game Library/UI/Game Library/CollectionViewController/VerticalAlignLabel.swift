//
//  UILabel+Theming.swift
//  Provenance
//
//  Created by Sev Gerk on 5/19/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

@IBDesignable public final class VerticalAlignLabel: UILabel {
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

    public override func awakeFromNib() {
        super.awakeFromNib()
        applyAlignmentCode()
    }

    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        applyAlignmentCode()
    }

    enum VerticalAlignment {
        case top
        case topcenter
        case middle
        case bottom
    }

    var verticalAlignment: VerticalAlignment = .top {
        didSet {
            setNeedsDisplay()
        }
    }

    public override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: limitedToNumberOfLines)

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
                return CGRect(x: (self.bounds.size.width / 2) - (rect.size.width / 2), y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
            case .middle:
                return CGRect(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height) / 2, width: rect.size.width, height: rect.size.height)
            case .bottom:
                return CGRect(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height), width: rect.size.width, height: rect.size.height)
            }
        }
    }

    public override func drawText(in rect: CGRect) {
        let r = textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines)
        super.drawText(in: r)
    }
}
