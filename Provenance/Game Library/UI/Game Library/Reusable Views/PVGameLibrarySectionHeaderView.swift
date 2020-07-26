//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameLibrarySectionHeaderView.m
//  Provenance
//
//  Created by James Addyman on 16/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//
import RxSwift

internal struct GameLibrarySectionViewModel {
    internal let title: String
    internal let collapsable: Bool
    internal let collapsed: Bool

//    internal init(title : String, collapsable: Bool, collapsed: Bool) {
//        self.init(title: title, collapsable: collapsable, collapsed: collapsed)
//    }
}

final class PVGameLibrarySectionHeaderView: UICollectionReusableView {
    private(set) var titleLabel: UILabel = UILabel()
    var collapseImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "chevron_down"))
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFit
        #if os(iOS)
            iv.tintColor = Theme.currentTheme.gameLibraryHeaderText
        #endif
        return iv
    }()

    var disposeBag = DisposeBag()

    var viewModel: GameLibrarySectionViewModel {
        didSet {
            #if os(tvOS)
                titleLabel.text = viewModel.title
                titleLabel.font = UIFont.boldSystemFont(ofSize: 42)
            #else
                titleLabel.text = viewModel.title.uppercased()
                titleLabel.font = UIFont.boldSystemFont(ofSize: 12)
            #endif
            collapseImageView.isHidden = !viewModel.collapsable
            collapseImageView.transform = viewModel.collapsed ? CGAffineTransform(rotationAngle: CGFloat.pi / 2.0) : .identity
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        viewModel = GameLibrarySectionViewModel(title: "", collapsable: false, collapsed: false)
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
            backgroundColor = UIColor.black.withAlphaComponent(0.8)
            titleLabel.textAlignment = .left
            titleLabel.backgroundColor = .clear
            titleLabel.textColor = UIColor(white: 1.0, alpha: 0.5)
//        topSeparator.backgroundColor = UIColor(hex: "#262626")
//        bottomSeparator.backgroundColor = UIColor(hex: "#262626")
            clipsToBounds = false
        #endif
        titleLabel.numberOfLines = 0
        titleLabel.autoresizingMask = .flexibleWidth
        addSubview(titleLabel)

        addSubview(collapseImageView)
        collapseImageView.translatesAutoresizingMaskIntoConstraints = false
        collapseImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1).isActive = true
        collapseImageView.widthAnchor.constraint(equalTo: heightAnchor, multiplier: 1).isActive = true
        collapseImageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        collapseImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true

        isOpaque = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(tvOS)
        override func traitCollectionDidChange(_: UITraitCollection?) {
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
        disposeBag = DisposeBag()
    }
}
