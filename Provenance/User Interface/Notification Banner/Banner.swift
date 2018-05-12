//
//  Banner.swift
//
//  Created by Harlan Haskins on 7/27/15.
//  Copyright (c) 2015 Bryx. All rights reserved.
//

import UIKit

private enum BannerState {
    case showing, hidden, gone
}

/// Wheter the banner should appear at the top or the bottom of the screen.
///
/// - Top: The banner will appear at the top.
/// - Bottom: The banner will appear at the bottom.
public enum BannerPosition {
    case top, bottom
}

/// A level of 'springiness' for Banners.
///
/// - None: The banner will slide in and not bounce.
/// - Slight: The banner will bounce a little.
/// - Heavy: The banner will bounce a lot.
public enum BannerSpringiness {
    case none, slight, heavy
    fileprivate var springValues: (damping: CGFloat, velocity: CGFloat) {
        switch self {
        case .none: return (damping: 1.0, velocity: 1.0)
        case .slight: return (damping: 0.7, velocity: 1.5)
        case .heavy: return (damping: 0.6, velocity: 2.0)
        }
    }
}

/// Banner is a dropdown notification view that presents above the main view controller, but below the status bar.
open class Banner: UIView {
    @objc class func topWindow() -> UIWindow? {
        for window in UIApplication.shared.windows.reversed() {
            if window.windowLevel == UIWindowLevelNormal && window.isKeyWindow && window.frame != CGRect.zero { return window }
        }
        return nil
    }
    
    private let contentView = UIView()
    private let labelView = UIView()
    private let backgroundView = UIView()
    
    /// How long the slide down animation should last.
    @objc open var animationDuration: TimeInterval = 0.4
    
    /// The preferred style of the status bar during display of the banner. Defaults to `.LightContent`.
    ///
    /// If the banner's `adjustsStatusBarStyle` is false, this property does nothing.
    @objc open var preferredStatusBarStyle = UIStatusBarStyle.lightContent
    
    /// Whether or not this banner should adjust the status bar style during its presentation. Defaults to `false`.
    @objc open var adjustsStatusBarStyle = false
    
    /// Wheter the banner should appear at the top or the bottom of the screen. Defaults to `.Top`.
    open var position = BannerPosition.top

    /// How 'springy' the banner should display. Defaults to `.Slight`
    open var springiness = BannerSpringiness.slight
    
    /// The color of the text as well as the image tint color if `shouldTintImage` is `true`.
    @objc open var textColor = UIColor.white {
        didSet {
            resetTintColor()
        }
    }
    
    /// The height of the banner. Default is 80.
    @objc open var minimumHeight: CGFloat = 80
    
    /// Whether or not the banner should show a shadow when presented.
    @objc open var hasShadows = true {
        didSet {
            resetShadows()
        }
    }
    
    /// The color of the background view. Defaults to `nil`.
    override open var backgroundColor: UIColor? {
        get { return backgroundView.backgroundColor }
        set { backgroundView.backgroundColor = newValue }
    }
    
    /// The opacity of the background view. Defaults to 0.95.
    override open var alpha: CGFloat {
        get { return backgroundView.alpha }
        set { backgroundView.alpha = newValue }
    }
    
    /// A block to call when the uer taps on the banner.
    @objc open var didTapBlock: (() -> ())?
    
    /// A block to call after the banner has finished dismissing and is off screen.
    @objc open var didDismissBlock: (() -> ())?
    
    /// Whether or not the banner should dismiss itself when the user taps. Defaults to `true`.
    @objc open var dismissesOnTap = true
    
    /// Whether or not the banner should dismiss itself when the user swipes up. Defaults to `true`.
    @objc open var dismissesOnSwipe = true
    
    /// Whether or not the banner should tint the associated image to the provided `textColor`. Defaults to `true`.
    @objc open var shouldTintImage = true {
        didSet {
            resetTintColor()
        }
    }
    
    /// The label that displays the banner's title.
    @objc open let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
        }()
    
    /// The label that displays the banner's subtitle.
    @objc open let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
        }()
    
    /// The image on the left of the banner.
    @objc let image: UIImage?
    
    /// The image view that displays the `image`.
    @objc open let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
        }()
    
    private var bannerState = BannerState.hidden {
        didSet {
            if bannerState != oldValue {
                forceUpdates()
            }
        }
    }
    
    /// A Banner with the provided `title`, `subtitle`, and optional `image`, ready to be presented with `show()`.
    ///
    /// - parameter title: The title of the banner. Optional. Defaults to nil.
    /// - parameter subtitle: The subtitle of the banner. Optional. Defaults to nil.
    /// - parameter image: The image on the left of the banner. Optional. Defaults to nil.
    /// - parameter backgroundColor: The color of the banner's background view. Defaults to `UIColor.blackColor()`.
    /// - parameter didTapBlock: An action to be called when the user taps on the banner. Optional. Defaults to `nil`.
    @objc public required init(title: String? = nil, subtitle: String? = nil, image: UIImage? = nil, backgroundColor: UIColor = UIColor.black, didTapBlock: (() -> ())? = nil) {
        self.didTapBlock = didTapBlock
        self.image = image
        super.init(frame: CGRect.zero)
        resetShadows()
        addGestureRecognizers()
        initializeSubviews()
        resetTintColor()
        imageView.image = image
        titleLabel.text = title
        detailLabel.text = subtitle
        backgroundView.backgroundColor = backgroundColor
        backgroundView.alpha = 0.95
    }
    
    private func forceUpdates() {
      guard let superview = superview, let showingConstraint = showingConstraint, let hiddenConstraint = hiddenConstraint else { return }
        switch bannerState {
        case .hidden:
            superview.removeConstraint(showingConstraint)
            superview.addConstraint(hiddenConstraint)
        case .showing:
            superview.removeConstraint(hiddenConstraint)
            superview.addConstraint(showingConstraint)
        case .gone:
            superview.removeConstraint(hiddenConstraint)
            superview.removeConstraint(showingConstraint)
            superview.removeConstraints(commonConstraints)
        }
        setNeedsLayout()
        setNeedsUpdateConstraints()
        // Managing different -layoutIfNeeded behaviours among iOS versions (for more, read the UIKit iOS 10 release notes)
        if #available(iOS 10.0, *) {
            superview.layoutIfNeeded()
        } else {
            layoutIfNeeded()
        }
        updateConstraintsIfNeeded()
    }
  
    @objc internal func didTap(_ recognizer: UITapGestureRecognizer) {
        if dismissesOnTap {
            dismiss()
        }
        didTapBlock?()
    }
    
    @objc internal func didSwipe(_ recognizer: UISwipeGestureRecognizer) {
        if dismissesOnSwipe {
            dismiss()
        }
    }
    
    private func addGestureRecognizers() {
        addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(Banner.didTap(_:))))
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(Banner.didSwipe(_:)))
        swipe.direction = .up
        addGestureRecognizer(swipe)
    }
    
    private func resetTintColor() {
        titleLabel.textColor = textColor
        detailLabel.textColor = textColor
        imageView.image = shouldTintImage ? image?.withRenderingMode(.alwaysTemplate) : image
        imageView.tintColor = shouldTintImage ? textColor : nil
    }
    
    private func resetShadows() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = self.hasShadows ? 0.5 : 0.0
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 4
    }
  
    private var contentTopOffsetConstraint: NSLayoutConstraint!
    private var minimumHeightConstraint: NSLayoutConstraint!
  
    private func initializeSubviews() {
        let views = [
            "backgroundView": backgroundView,
            "contentView": contentView,
            "imageView": imageView,
            "labelView": labelView,
            "titleLabel": titleLabel,
            "detailLabel": detailLabel
        ]
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        minimumHeightConstraint = backgroundView.constraintWithAttribute(.height, .greaterThanOrEqual, to: minimumHeight)
        addConstraint(minimumHeightConstraint) // Arbitrary, but looks nice.
        addConstraints(backgroundView.constraintsEqualToSuperview())
        backgroundView.backgroundColor = backgroundColor
        backgroundView.addSubview(contentView)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(labelView)
        labelView.addSubview(titleLabel)
        labelView.addSubview(detailLabel)
        backgroundView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat("H:|[contentView]|", views: views))
        backgroundView.addConstraint(contentView.constraintWithAttribute(.bottom, .equal, to: .bottom, of: backgroundView))
        contentTopOffsetConstraint = contentView.constraintWithAttribute(.top, .equal, to: .top, of: backgroundView)
        backgroundView.addConstraint(contentTopOffsetConstraint)
        let leftConstraintText: String
        if image == nil {
            leftConstraintText = "|"
        } else {
            contentView.addSubview(imageView)
            contentView.addConstraint(imageView.constraintWithAttribute(.leading, .equal, to: contentView, constant: 15.0))
            contentView.addConstraint(imageView.constraintWithAttribute(.centerY, .equal, to: contentView))
            imageView.addConstraint(imageView.constraintWithAttribute(.width, .equal, to: 25.0))
            imageView.addConstraint(imageView.constraintWithAttribute(.height, .equal, to: .width))
            leftConstraintText = "[imageView]"
        }
        let constraintFormat = "H:\(leftConstraintText)-(15)-[labelView]-(8)-|"
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat(constraintFormat, views: views))
        contentView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat("V:|-(>=1)-[labelView]-(>=1)-|", views: views))
        backgroundView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat("H:|[contentView]-(<=1)-[labelView]", options: .alignAllCenterY, views: views))
        
        for view in [titleLabel, detailLabel] {
            let constraintFormat = "H:|[label]-(8)-|"
            contentView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat(constraintFormat, options: NSLayoutFormatOptions(), metrics: nil, views: ["label": view]))
        }
        labelView.addConstraints(NSLayoutConstraint.defaultConstraintsWithVisualFormat("V:|-(10)-[titleLabel][detailLabel]-(10)-|", views: views))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var showingConstraint: NSLayoutConstraint?
    private var hiddenConstraint: NSLayoutConstraint?
    private var commonConstraints = [NSLayoutConstraint]()
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview = superview, bannerState != .gone else { return }
        commonConstraints = self.constraintsWithAttributes([.width], .equal, to: superview)
        superview.addConstraints(commonConstraints)

        switch self.position {
            case .top:
                showingConstraint = self.constraintWithAttribute(.top, .equal, to: .top, of: superview)
                let yOffset: CGFloat = -7.0 // Offset the bottom constraint to make room for the shadow to animate off screen.
                hiddenConstraint = self.constraintWithAttribute(.bottom, .equal, to: .top, of: superview, constant: yOffset)
            case .bottom:
                showingConstraint = self.constraintWithAttribute(.bottom, .equal, to: .bottom, of: superview)
                let yOffset: CGFloat = 7.0 // Offset the bottom constraint to make room for the shadow to animate off screen.
                hiddenConstraint = self.constraintWithAttribute(.top, .equal, to: .bottom, of: superview, constant: yOffset)
        }
    }
  
    open override func layoutSubviews() {
      super.layoutSubviews()
      adjustHeightOffset()
      layoutIfNeeded()
    }
  
    private func adjustHeightOffset() {
      guard let superview = superview else { return }
      if superview === Banner.topWindow() && self.position == .top {
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        let heightOffset = min(statusBarSize.height, statusBarSize.width) // Arbitrary, but looks nice.
        contentTopOffsetConstraint.constant = heightOffset
        minimumHeightConstraint.constant = statusBarSize.height > 0 ? minimumHeight : 40
      } else {
        contentTopOffsetConstraint.constant = 0
        minimumHeightConstraint.constant = 0
      }
    }
  
    /// Shows the banner. If a view is specified, the banner will be displayed at the top of that view, otherwise at top of the top window. If a `duration` is specified, the banner dismisses itself automatically after that duration elapses.
    /// - parameter view: A view the banner will be shown in. Optional. Defaults to 'nil', which in turn means it will be shown in the top window. duration A time interval, after which the banner will dismiss itself. Optional. Defaults to `nil`.
    open func show(_ view: UIView? = nil, duration: TimeInterval? = nil) {
        let viewToUse = view ?? Banner.topWindow()
        guard let view = viewToUse else {
            print("[Banner]: Could not find view. Aborting.")
            return
        }
        view.addSubview(self)
        forceUpdates()
        let (damping, velocity) = self.springiness.springValues
        let oldStatusBarStyle = UIApplication.shared.statusBarStyle
        if adjustsStatusBarStyle {
          UIApplication.shared.setStatusBarStyle(preferredStatusBarStyle, animated: true)
        }
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: .allowUserInteraction, animations: {
            self.bannerState = .showing
            }, completion: { finished in
                guard let duration = duration else { return }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(1000.0 * duration))) {
                    self.dismiss(self.adjustsStatusBarStyle ? oldStatusBarStyle : nil)
                }
        })
    }
  
    /// Dismisses the banner.
    open func dismiss(_ oldStatusBarStyle: UIStatusBarStyle? = nil) {
        let (damping, velocity) = self.springiness.springValues
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: .allowUserInteraction, animations: {
            self.bannerState = .hidden
            if let oldStatusBarStyle = oldStatusBarStyle {
                UIApplication.shared.setStatusBarStyle(oldStatusBarStyle, animated: true)
            }
            }, completion: { finished in
                self.bannerState = .gone
                self.removeFromSuperview()
                self.didDismissBlock?()
        })
    }
}

extension NSLayoutConstraint {
    @objc class func defaultConstraintsWithVisualFormat(_ format: String, options: NSLayoutFormatOptions = NSLayoutFormatOptions(), metrics: [String: AnyObject]? = nil, views: [String: AnyObject] = [:]) -> [NSLayoutConstraint] {
        return NSLayoutConstraint.constraints(withVisualFormat: format, options: options, metrics: metrics, views: views)
    }
}

extension UIView {
    @objc func constraintsEqualToSuperview(_ edgeInsets: UIEdgeInsets = UIEdgeInsets.zero) -> [NSLayoutConstraint] {
        self.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [NSLayoutConstraint]()
        if let superview = self.superview {
            constraints.append(self.constraintWithAttribute(.leading, .equal, to: superview, constant: edgeInsets.left))
            constraints.append(self.constraintWithAttribute(.trailing, .equal, to: superview, constant: edgeInsets.right))
            constraints.append(self.constraintWithAttribute(.top, .equal, to: superview, constant: edgeInsets.top))
            constraints.append(self.constraintWithAttribute(.bottom, .equal, to: superview, constant: edgeInsets.bottom))
        }
        return constraints
    }
    
    @objc func constraintWithAttribute(_ attribute: NSLayoutAttribute, _ relation: NSLayoutRelation, to constant: CGFloat, multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        self.translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: relation, toItem: nil, attribute: .notAnAttribute, multiplier: multiplier, constant: constant)
    }
    
    @objc func constraintWithAttribute(_ attribute: NSLayoutAttribute, _ relation: NSLayoutRelation, to otherAttribute: NSLayoutAttribute, of item: AnyObject? = nil, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0) -> NSLayoutConstraint {
        self.translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: relation, toItem: item ?? self, attribute: otherAttribute, multiplier: multiplier, constant: constant)
    }
    
    @objc func constraintWithAttribute(_ attribute: NSLayoutAttribute, _ relation: NSLayoutRelation, to item: AnyObject, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0) -> NSLayoutConstraint {
        self.translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: relation, toItem: item, attribute: attribute, multiplier: multiplier, constant: constant)
    }
    
    func constraintsWithAttributes(_ attributes: [NSLayoutAttribute], _ relation: NSLayoutRelation, to item: AnyObject, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0) -> [NSLayoutConstraint] {
        return attributes.map { self.constraintWithAttribute($0, relation, to: item, multiplier: multiplier, constant: constant) }
    }
}
