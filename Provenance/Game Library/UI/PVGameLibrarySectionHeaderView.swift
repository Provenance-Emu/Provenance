//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameLibrarySectionHeaderView.m
//  Provenance
//
//  Created by James Addyman on 16/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

class PVGameLibrarySectionFooterView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        #if os(iOS)
            let separator = UIView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 1.0))
            separator.backgroundColor = UIColor(white: 1.0, alpha: 0.6)
            separator.autoresizingMask = .flexibleWidth
            addSubview(separator)
        #endif
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PVGameLibrarySectionHeaderView: UICollectionReusableView {
    private(set) var titleLabel: UILabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
#if os(tvOS)
        titleLabel.frame = CGRect(x: 30, y: 0, width: bounds.size.width - 30, height: bounds.size.height)
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        titleLabel.textColor = colorForText
#else
    let labelHeight: CGFloat = 20.0
    let labelBottomMargin: CGFloat = 5.0

    titleLabel.frame = CGRect(x: 14, y: bounds.size.height - labelHeight - labelBottomMargin, width: bounds.size.width - 40, height: labelHeight)
    titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

//        let topSeparator = UIView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 1.0))
//        topSeparator.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
//        topSeparator.autoresizingMask = .flexibleWidth
//
//        addSubview(topSeparator)

        let bottomSeparator = UIView(frame: CGRect(x: 0, y: bounds.size.height, width: bounds.size.width, height: 1.0))
        bottomSeparator.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        bottomSeparator.autoresizingMask = .flexibleWidth

        addSubview(bottomSeparator)

        // Style
        self.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        titleLabel.textAlignment = .left
        titleLabel.backgroundColor = .clear
        titleLabel.textColor = UIColor(white: 1.0, alpha: 0.5)
//        topSeparator.backgroundColor = UIColor(hex: "#262626")
//        bottomSeparator.backgroundColor = UIColor(hex: "#262626")
        self.clipsToBounds = false
#endif
        titleLabel.numberOfLines = 0
        titleLabel.autoresizingMask = .flexibleWidth
        addSubview(titleLabel)

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if os(tvOS)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        titleLabel.textColor = colorForText
    }
    var colorForText: UIColor {
        if #available(tvOS 10.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.lightGray
            }
        }

        return UIColor.darkGray
    }
#endif
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
}
