//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameLibrarySectionHeaderView.m
//  Provenance
//
//  Created by James Addyman on 16/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

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
        titleLabel.frame = CGRect(x: 20, y: 0, width: bounds.size.width - 40, height: bounds.size.height)
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        let topSeparator = UIView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 0.5))
        topSeparator.backgroundColor = UIColor(white: 0.7, alpha: 0.6)
        topSeparator.autoresizingMask = .flexibleWidth
        
        addSubview(topSeparator)
        
        titleLabel.textAlignment = .center
        
        let bottomSeparator = UIView(frame: CGRect(x: 0, y: bounds.size.height, width: bounds.size.width, height: 0.5))
        bottomSeparator.backgroundColor = UIColor(white: 0.7, alpha: 0.6)
        bottomSeparator.autoresizingMask = .flexibleWidth
        
        addSubview(bottomSeparator)
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
        titleLabel?.textColor = colorForText()
    }
    var colorForText : UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.lightGray
        }
        return UIColor.darkGray
    }
#endif
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
}

