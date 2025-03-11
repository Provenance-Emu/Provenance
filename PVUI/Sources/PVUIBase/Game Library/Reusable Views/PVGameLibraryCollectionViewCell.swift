//  PVGameLibraryCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

import AVFoundation
import CoreGraphics
import PVLibrary
import PVSupport
import RealmSwift
#if canImport(UIKit)
import UIKit
#endif
import PVThemes
import PVSettings
import PVRealm
import PVLogging
import PVMediaCache

private let LabelHeight: CGFloat = 44.0

public extension UIView {
    @IBInspectable var borderColor: UIColor? {
        get {
            guard let bc = layer.borderColor else {
                return nil
            }
            return UIColor(cgColor: bc)
        }
        set {
            if let borderColor = newValue {
                layer.borderWidth = 1.0
                layer.borderColor = borderColor.cgColor
            } else {
                layer.borderWidth = 0.0
                layer.borderColor = nil
            }
        }
    }
}

enum BlendModes: String {
    case normalBlendMode
    //
    case darkenBlendMode
    case multiplyBlendMode
    case colorBurnBlendMode
    //
    case lightenBlendMode
    case screenBlendMode
    case colorDodgeBlendMode
    //
    case overlayBlendMode
    case softLightBlendMode
    case hardLightBlendMode
    //
    case differenceBlendMode
    case exclusionBlendMode
    //
    /*
     case hueBlendMode
     case saturationBlendMode
     case colorBlendMode
     case luminosityBlendMode
     */
}

extension CGRect {
    var topLeftPoint: CGPoint {
        return CGPoint(x: 0, y: 0)
    }

    var topRightPoint: CGPoint {
        return CGPoint(x: maxX, y: 0)
    }

    var bottomRightPoint: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }

    var bottomLeftPoint: CGPoint {
        return CGPoint(x: 0, y: maxY)
    }
}

extension CGSize {
    enum Orientation {
        case landscape
        case portrait
        case square
    }

    var orientation: Orientation {
        if width > height {
            return .landscape
        } else if height > width {
            return .portrait
        } else {
            return .square
        }
    }

    var aspectRatio: CGFloat {
        switch orientation {
        case .portrait:
            return width / height
        case .landscape:
            return height / width
        case .square:
            return 1.0
        }
    }

    var longestLength: CGFloat {
        return max(width, height)
    }

    var shortestLength: CGFloat {
        return min(width, height)
    }

    var debugDescription: String {
        return "(width:\(width) height:\(height))"
    }

    //	func scaleAspectToFitInside(_ boundingSize : CGSize) -> CGSize {
    //		let mW = boundingSize.width / self.width;
    //		let mH = boundingSize.height / self.height;
//
    //		var newSize = boundingSize
    //		if( mH < mW ) {
    //			newSize.width = boundingSize.height / self.height * self.width;
    //		}
    //		else if( mW < mH ) {
    //			newSize.height = boundingSize.width / self.width * self.height;
    //		}
//
    //		return boundingSize;
    //	}
    //	func scaleAspectToFitInside(_ size : CGSize) -> CGSize {
//
    //		let newSize : CGSize
    //		switch (orientation, size.orientation) {
    //		case (.landscape, .landscape):
    //			newSize = CGSize(width: size.width, height: size.height * aspectRatio)
    //		case (.landscape, .portrait):
    //			newSize = CGSize(width: size.width, height: size.height * aspectRatio)
    //		case (.portrait, .portrait):
    //			newSize = CGSize(width: size.width * aspectRatio, height: size.height)
//
    //		case (.square,.square):
    //			let minSide = size.shortestLength
    //			newSize = CGSize(width: minSide, height: minSide)
    //		}
//
    //		return newSize
    //	}
}

extension CGRect {
    func scaleAspectToFitInside(_ rect: CGRect) -> CGRect {
        //		let newSize = size.scaleAspectToFitInside(rect.size)
        //		var newRect = CGRect(origin: .zero, size: newSize)
        //		if newSize.width < rect.width {
        //			newRect.origin.x = (rect.width - newSize.width) / 2.0
        //		}
//
        //		if newSize.height < rect.height {
        //			newRect.origin.y = (rect.height - newSize.height) / 2.0
        //		}
//
        //		return newRect
        return AVMakeRect(aspectRatio: size, insideRect: rect)
    }

    var debugDescription: String {
        return "(x:\(origin.x) y:\(origin.y) width:\(size.width) height:\(size.height))"
    }
}

extension UIImageView {
    // What is the bounds of the image when it's scaled to fit
    var contentClippingRect: CGRect {
        guard let image = image else {
//            VLOG("No image")
            return bounds
        }
        guard contentMode == .scaleAspectFit else {
            VLOG("Unsupported content mode")
            return bounds
        }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        var clippingRect = CGRect(origin: .zero, size: imageSize).scaleAspectToFitInside(bounds)
        clippingRect.origin.x = (bounds.width - clippingRect.width) / 2.0
        clippingRect.origin.y = (bounds.height - clippingRect.height) / 2.0

        //		VLOG("imageSize:\(imageSize.debugDescription) bounds:\(bounds.debugDescription) clippingRect:\(clippingRect.debugDescription) ratio:\(imageSize.aspectRatio)")

        return clippingRect
    }
}

func + (left: NSAttributedString, right: NSAttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString()
    result.append(left)
    result.append(right)
    return NSAttributedString(attributedString: result)
}

protocol GameLibraryCollectionViewDelegate: AnyObject {
    func promptToDeleteGame(_ game: PVGame, completion: ((_ deleted: Bool) -> Swift.Void)?)
}
// MARK: Corner Badge Glyph
@IBDesignable
public final class CornerBadgeView: UIView {
    enum FillCorner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    @IBInspectable public var glyph: String = "" {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable public var fillColor: UIColor = UIColor.orange {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable public var strokeColor: UIColor = UIColor.orange {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable public var textColor: UIColor = UIColor.black {
        didSet {
            setNeedsDisplay()
        }
    }

    var fillCorner: FillCorner = .topRight {
        didSet {
            setNeedsDisplay()
        }
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context: CGContext = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(0.5)

        let triangle = createTriangle()
        triangle.fill()
        triangle.stroke(with: .darken, alpha: 0.8)

        context.setFillColor(textColor.cgColor)
        context.setBlendMode(.luminosity)
        drawGlyph()
    }

    private func drawGlyph() {
        guard !glyph.isEmpty else {
            return
        }

        let gString = glyph as NSString

        var triangleBounds = createTriangle().bounds
        switch fillCorner {
        case .topRight:
            triangleBounds = triangleBounds.offsetBy(dx: triangleBounds.size.width * 0.4, dy: triangleBounds.size.height * -0.08)
        default:
            break
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: triangleBounds.height * 0.64), .foregroundColor: ThemeManager.shared.currentPalette.gameLibraryText ?? UIColor(white: 1.0, alpha: 0.6)]
        gString.draw(in: triangleBounds, withAttributes: attributes)
    }

    private func createTriangle() -> UIBezierPath {
        let triangle = UIBezierPath()
        switch fillCorner {
        case .topLeft:
            triangle.move(to: bounds.topLeftPoint)
            triangle.addLine(to: bounds.topRightPoint)
            triangle.addLine(to: bounds.bottomLeftPoint)
        case .topRight:
            triangle.move(to: bounds.topLeftPoint)
            triangle.addLine(to: bounds.topRightPoint)
            triangle.addLine(to: bounds.bottomRightPoint)
        case .bottomLeft:
            triangle.move(to: bounds.topLeftPoint)
            triangle.addLine(to: bounds.bottomLeftPoint)
            triangle.addLine(to: bounds.bottomRightPoint)
        case .bottomRight:
            triangle.move(to: bounds.topRightPoint)
            triangle.addLine(to: bounds.bottomRightPoint)
            triangle.addLine(to: bounds.bottomLeftPoint)
        }
        triangle.close()
        return triangle
    }

    /*
     override func prepareForInterfaceBuilder() {
     self.layer.cornerRadius = self.bounds.size.width/2
     self.layer.borderWidth = 6
     self.layer.borderColor = UIColor.blackColor().CGColor
     self.layer.masksToBounds = true
     }*/
}

public
final class PVGameLibraryCollectionViewCell: UICollectionViewCell {
    weak var delegate: GameLibraryCollectionViewDelegate?

    @IBOutlet public var imageView: UIImageView! {
        didSet {
            imageView.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    @IBOutlet public /* weak */ var artworkContainerView: UIView?

    @IBOutlet public /* weak */ var discCountContainerView: UIView? {
        didSet {
            roundDiscCountCorners()
        }
    }

    @IBOutlet public /* weak */ var discCountLabel: UILabel? {
        didSet {
            discCountLabel?.adjustsFontSizeToFitWidth = true
        }
    }

    @IBOutlet public var topRightCornerBadgeView: CornerBadgeView?

    @IBOutlet public var titleLabel: UILabel! {
        didSet {
            #if os(tvOS)
            // The label's alpha will get set to 1 on focus
            titleLabel.alpha = 1
            titleLabel.textColor = UIColor.darkGray
            titleLabel.shadowColor = UIColor.init(white: 0.2, alpha: 0.5)
            titleLabel.shadowOffset = .init(width: 0.5, height: 0.5)
            #endif
        }
    }

    var operation: BlockOperation?

    @IBOutlet public var missingFileView: UIView? {
        didSet {
            //			missingFileView!.layer.compositingFilter = BlendModes.hardLightBlendMode.rawValue //"colorDodgeBlendMode"
        }
    }

    @IBOutlet public var missingRedSquareView: UIView! {
        didSet {
            missingRedSquareView.layer.compositingFilter = BlendModes.hardLightBlendMode.rawValue // "colorDodgeBlendMode"
        }
    }

    @IBOutlet public var warningSignLabel: UIImageView! {
        didSet {
            //			warningSignLabel.layer.compositingFilter = BlendModes.screenBlendMode.rawValue //"colorDodgeBlendMode"
        }
    }

    @IBOutlet public var topRightBadgeTopConstraint: NSLayoutConstraint?
    @IBOutlet public var topRightBadgeTrailingConstraint: NSLayoutConstraint?
//    @IBOutlet weak var topRightBadgeWidthConstraint: NSLayoutConstraint?
    @IBOutlet public var discCountTrailingConstraint: NSLayoutConstraint?
    @IBOutlet public var discCountBottomConstraint: NSLayoutConstraint?
    @IBOutlet public var missingFileWidthConstraint: NSLayoutConstraint?
    @IBOutlet public var missingFileHeightConstraint: NSLayoutConstraint?
    @IBOutlet public var titleLabelHeightConstraint: NSLayoutConstraint?
    @IBOutlet public var deleteActionView: UIView? {
        didSet {
            deleteActionView?.alpha = 0
        }
    }
//    @IBOutlet weak var artworkContainerViewHeightConstraint: NSLayoutConstraint?

    class func cellSize(forImageSize imageSize: CGSize) -> CGSize {
        let size: CGSize
        #if os(tvOS)
            size = CGSize(width: imageSize.width, height: imageSize.height )
        #else
            size = CGSize(width: imageSize.width, height: imageSize.height + (imageSize.height * 0.15))
        #endif
        return size
    }

    #if os(tvOS)
    public override var canBecomeFocused: Bool {
            return true
        }

    #endif
    public var game: PVGame? {
        didSet {
            if let game = game?.validatedGame {
                self.setup(with: game)
            } else {
                self.discCountContainerView?.isHidden = true
                self.topRightCornerBadgeView?.isHidden = true
                self.missingFileView?.isHidden = true
            }
        }
    }

    private func updateImageBagConstraints() {}

    @MainActor
    private func setup(with game: PVGame) {
        let artworkURL: String = game.customArtworkURL
        let originalArtworkURL: String = game.originalArtworkURL
        if Defaults[.showGameTitles] {
            titleLabel.text = game.title
        } else { titleLabel.text = nil }

        // TODO: May be renabled later
        let placeholderImageText: String = game.title
        if artworkURL.isEmpty, originalArtworkURL.isEmpty {
            var artworkText: String
            if Defaults[.showGameTitles] {
                artworkText = placeholderImageText
            } else {
                artworkText = game.title
            }
            image = image(withText: artworkText) // ?.withRenderingMode(.alwaysTemplate)
            updateImageConstraints()
            setNeedsLayout()
        } else {
            var maybeKey: String? = !artworkURL.isEmpty ? artworkURL : nil
            if maybeKey == nil {
                maybeKey = !originalArtworkURL.isEmpty ? originalArtworkURL : nil
            }
            if let key = maybeKey {
                let threadSafeGame = game.freeze()
                operation = PVMediaCache.shareInstance().image(forKey: key, completion: { (_ key: String, _ image: UIImage?) -> Void in
                    let game = threadSafeGame.thaw()
                    guard let game = game, key == game.customArtworkURL || key == game.originalArtworkURL else {
                        // We must have recyclied already
                        return
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let `self` = self else { return }

                        var artworkText: String
                        if Defaults[.showGameTitles] {
                            artworkText = placeholderImageText
                        } else {
                            artworkText = game.title
                        }
                        let artwork: UIImage? = image ?? self.image(withText: artworkText)
                        self.image = artwork // ?.imageWithBorder(width: 1, color: UIColor.red) //?.withRenderingMode(.alwaysTemplate)
//                        #if os(tvOS)
//                            let maxAllowedHeight = self.contentView.bounds.height - self.titleLabelHeightConstraint!.constant + 5
//                            let height: CGFloat = min(maxAllowedHeight, self.contentView.bounds.width / game.boxartAspectRatio.rawValue)
//                            self.artworkContainerViewHeightConstraint?.constant = height
//                        #endif
                        self.updateImageConstraints()
                        self.setNeedsLayout()
                    }
                })
            }
        }

        Task.detached { @MainActor [weak self] in
            self?.missingFileView?.isHidden = await game.file?.online ?? true
        }
        setupBadges()
        if !Defaults[.showGameBadges] {
            setupDots()
        }
        setNeedsLayout()
        setNeedsFocusUpdate()
    }

    private func setupTopRightBadge() {
        guard let game = game, Defaults[.showGameBadges], let topRightCornerBadgeView = topRightCornerBadgeView else {
            self.topRightCornerBadgeView?.isHidden = true
            return
        }
        let hasPlayed = game.playCount > 0
        let favorite = game.isFavorite
        topRightCornerBadgeView.glyph = favorite ? "♥︎" : ""

        if favorite {
            topRightCornerBadgeView.fillColor = UIColor(rgb: 0xF71A32).withAlphaComponent(0.85)
        } else if !hasPlayed {
            topRightCornerBadgeView.fillColor = ThemeManager.shared.currentPalette.defaultTintColor ??  UIColor(rgb: 0x17AAF7).withAlphaComponent(0.85)
        }

        topRightCornerBadgeView.isHidden = hasPlayed && !favorite
    }

    private func setupDiscCountBadge() {
        guard let game = game, let discCountContainerView = self.discCountContainerView, let discCountLabel = discCountLabel else {
            self.discCountContainerView?.isHidden = true
            return
        }

        Task { @MainActor in
            let diskCount = await game.diskCount
            let multiDisc = diskCount > 1

            discCountContainerView.isHidden = !multiDisc
            discCountLabel.text = "\(diskCount)"
            discCountLabel.textColor = ThemeManager.shared.currentPalette.settingsCellText ?? UIColor.white
        }
    }

    private func setupBadges() {
        setupTopRightBadge()
        setupDiscCountBadge()
    }

    private func setupDots() {
        guard let game = game else {
            return
        }
        let hasPlayed = game.playCount > 0
        let favorite = game.isFavorite

        var bullet = NSAttributedString(string: "")
        let bulletFavoriteAttribute = [NSAttributedString.Key.foregroundColor: UIColor(rgb: 0xF71A32).withAlphaComponent(0.85)]
        let bulletUnplayedAttribute = [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentPalette.defaultTintColor ??  UIColor(rgb: 0x17AAF7).withAlphaComponent(0.85)]
        let bulletFavorite = NSAttributedString(string: "♥︎ ", attributes: bulletFavoriteAttribute)
        let bulletUnplayed = NSAttributedString(string: "● ", attributes: bulletUnplayedAttribute)
        let attributedTitle = NSMutableAttributedString(string: game.title)

        if favorite {
            bullet = bulletFavorite
        } else if !hasPlayed {
            bullet = bulletUnplayed
        }

        titleLabel.attributedText = bullet + attributedTitle
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.isHidden = !Defaults[.showGameTitles]
    }

    #if os(iOS)
        private func setupPanGesture() {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(PVGameLibraryCollectionViewCell.containerPanGestureRecognized(panGesture:)))
            panGesture.cancelsTouchesInView = true
            panGesture.delegate = self
            panGesture.maximumNumberOfTouches = 1
            self.addGestureRecognizer(panGesture)

            if let deleteActionView = deleteActionView {
                deleteActionView.removeFromSuperview()
                deleteActionView.translatesAutoresizingMaskIntoConstraints = false
                deleteActionView.frame = contentView.bounds
                backgroundView = UIView(frame: bounds)
                backgroundView?.isOpaque = true
                isOpaque = true
                contentView.isOpaque = true

                insertSubview(deleteActionView, belowSubview: contentView)

                deleteActionView.subviews.forEach {
                    if let label = $0 as? UILabel {
                        label.textColor = UIColor.white
                    }
                }

                deleteActionView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor).isActive = true
                deleteActionView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
                deleteActionView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
                deleteActionView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
            }
        }

        @objc
        private func containerPanGestureRecognized(panGesture: UIPanGestureRecognizer) {
            guard let delegate = delegate, let game = game else {
                return
            }

            struct Holder {
                static var originalLocation: CGPoint = .zero
            }

            switch panGesture.state {
            case .began:
                Holder.originalLocation = panGesture.location(in: contentView)
                deleteActionView?.alpha = 1
            case .changed:
                let newX = min(max(panGesture.location(in: self).x - Holder.originalLocation.x, contentView.frame.width * 0.85 * -1), 0)

                var f = contentView.frame
                f.origin.x = newX

                contentView.frame = f
            case .ended:
                var f = contentView.frame

                let animateBack: (() -> Void) = {
                    f.origin.x = 0
                    UIView.animate(withDuration: 0.25, delay: 0.1, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: {
                        self.deleteActionView?.alpha = 0
                        self.contentView.frame = f
                    }) { _ in
                    }
                }

                let swipeDistanceRequired = contentView.frame.width * 0.6 * -1
                let swipedFarEnough = contentView.frame.origin.x < swipeDistanceRequired
                if swipedFarEnough {
                    let finalX = contentView.frame.width * 0.9 * -1
                    f.origin.x = finalX
                    UIView.animate(withDuration: 0.1) {
                        self.contentView.frame = f
                    }
                    delegate.promptToDeleteGame(game) { _ in
                        animateBack()
                    }
                } else {
                    animateBack()
                }
            case .cancelled:
                var f = contentView.frame
                f.origin.x = 0
                UIView.animate(withDuration: 0.25) {
                    self.contentView.frame = f
                }
            default:
                break
            }
        }
    #endif

    private func oldViewInit() {
        var imageHeight: CGFloat = frame.size.height
        if Defaults[.showGameTitles] {
            imageHeight -= LabelHeight
        }

        let imageView = UIImageView()
        self.imageView = imageView

        let newTitleLabel = UILabel()
        newTitleLabel.textAlignment = .center
        titleLabel = newTitleLabel

        contentView.addSubview(titleLabel)
        contentView.addSubview(imageView)

        let imageFrame = CGRect(x: 0, y: 0, width: frame.size.width, height: imageHeight)
        let titleFrame = CGRect(x: 0, y: imageView.frame.size.height, width: frame.size.width, height: LabelHeight)

        let dccWidth = imageFrame.size.width * 0.25
        let discCountContainerFrame = CGRect(x: imageFrame.maxX - dccWidth, y: imageFrame.maxX - dccWidth, width: dccWidth, height: dccWidth)
        discCountContainerView = UIView(frame: discCountContainerFrame)
        contentView.addSubview(discCountContainerView!)

        discCountLabel = UILabel(frame: CGRect(x: 0, y: 0, width: dccWidth, height: dccWidth))
        discCountContainerView?.addSubview(discCountLabel!)

        discCountContainerView?.translatesAutoresizingMaskIntoConstraints = false
        discCountLabel?.translatesAutoresizingMaskIntoConstraints = false

        discCountContainerView?.trailingAnchor.constraint(equalTo: imageView.trailingAnchor).isActive = true
        discCountContainerView?.bottomAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
        discCountContainerView?.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.25, constant: 0).isActive = true
        discCountContainerView?.heightAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 0.25, constant: 0).isActive = true

        discCountLabel?.centerXAnchor.constraint(equalTo: discCountContainerView!.centerXAnchor).isActive = true
        discCountLabel?.centerYAnchor.constraint(equalTo: discCountContainerView!.centerYAnchor).isActive = true
        discCountLabel?.widthAnchor.constraint(equalTo: discCountContainerView!.widthAnchor, multiplier: 1, constant: -16).isActive = true
        discCountLabel?.heightAnchor.constraint(equalTo: discCountContainerView!.heightAnchor, multiplier: 0.75, constant: 0).isActive = true

        imageView.frame = imageFrame
        titleLabel.frame = titleFrame
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        titleLabel.isHidden = !Defaults[.showGameTitles]

        #if os(iOS)
            setupPanGesture()
        #else

        #endif

        #if os(tvOS)
        if let topRightCornerBadgeView = topRightCornerBadgeView {
            topRightCornerBadgeView.removeFromSuperview()
            topRightCornerBadgeView.constraints.forEach { topRightCornerBadgeView.removeConstraint($0) }
            imageView.overlayContentView.addSubview(topRightCornerBadgeView)
            topRightCornerBadgeView.trailingAnchor.constraint(equalTo: imageView.overlayContentView.trailingAnchor).isActive = true
            topRightCornerBadgeView.topAnchor.constraint(equalTo: imageView.overlayContentView.topAnchor).isActive = true
            topRightCornerBadgeView.widthAnchor.constraint(equalTo: imageView.overlayContentView.widthAnchor, multiplier: 0.25, constant: 0).isActive = true
            topRightCornerBadgeView.heightAnchor.constraint(equalTo: topRightCornerBadgeView.widthAnchor).isActive = true
        }
        if let discCountContainerView = discCountContainerView {
            discCountContainerView.removeFromSuperview()
            discCountContainerView.constraints.forEach { discCountContainerView.removeConstraint($0) }
            imageView.overlayContentView.addSubview(discCountContainerView)

            discCountContainerView.trailingAnchor.constraint(equalTo: imageView.overlayContentView.trailingAnchor).isActive = true
            discCountContainerView.bottomAnchor.constraint(equalTo: imageView.overlayContentView.bottomAnchor).isActive = true
            discCountContainerView.widthAnchor.constraint(equalTo: imageView.overlayContentView.widthAnchor, multiplier: 0.25, constant: 0).isActive = true
            discCountContainerView.heightAnchor.constraint(equalTo: discCountContainerView.widthAnchor).isActive = true
        }
        #endif
    }

    func image(withText text: String) -> UIImage? {
        #if os(iOS)
        let backgroundColor: UIColor = ThemeManager.shared.currentPalette.gameLibraryCellBackground ?? .systemGray5
        #else
            let backgroundColor: UIColor = UIColor(white: 0.18, alpha: 1.0)
        #endif
        if text == "" {
            return UIImage.image(withSize: CGSize(width: CGFloat(PVThumbnailMaxResolution), height: CGFloat(PVThumbnailMaxResolution)), color: backgroundColor, text: NSAttributedString(string: ""))
        }
        // TODO: To be replaced with the correct system placeholder
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        #if os(iOS)
            let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0), NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentPalette.settingsCellText!])
        #else
            let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 60.0), NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.foregroundColor: UIColor.gray])
        #endif

        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let ratio: CGFloat = game?.boxartAspectRatio.rawValue ?? 1.0

        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage
    }

    var image: UIImage? {
        set {
            imageView?.image = newValue
            if newValue == nil {
                imageView?.layer.shouldRasterize = false
            } else {
                imageView?.layer.shouldRasterize = true
                #if os(tvOS)
                    imageView?.layer.rasterizationScale = 2.0
                #else
                    imageView?.layer.rasterizationScale = UIScreen.main.scale
                #endif
            }
        } get {
            return imageView?.image
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()

        // Clear image loading from the queue is not needed
        if let operation = operation, !operation.isFinished, !operation.isExecuting {
            operation.cancel()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        titleLabel.isHidden = !Defaults[.showGameTitles]
        #if os(tvOS)
//        if let game = game {
//            let height: CGFloat = self.contentView.bounds.width / game.boxartAspectRatio.rawValue
//            self.artworkContainerViewHeightConstraint?.constant = height
//        } else {
//            let height: CGFloat = self.contentView.bounds.height
//            self.artworkContainerViewHeightConstraint?.constant = height
//        }
            // Fixes the box art clipping…
            sizeToFit()

            contentView.bringSubviewToFront(titleLabel!)
        #else
            self.contentView.frame = self.bounds
        #endif

        DispatchQueue.main.async {
            self.updateImageConstraints()
        }

        #if os(iOS)
            if !Defaults[.showGameTitles], let titleLabelHeightConstraint = titleLabelHeightConstraint {
                titleLabelHeightConstraint.constant = contentView.bounds.height * titleLabelHeightConstraint.multiplier * -1
            } else {
                //			titleLabelHeightConstraint?.constant = 0.0
            }
        #endif
    }

    func updateImageConstraints() {
        let imageContentFrame = imageView.contentClippingRect

        let topConstant = imageContentFrame.origin.y
        let bottomConstant = imageContentFrame.origin.y * -1.0
        let trailingConstant = imageContentFrame.origin.x * -1.0
        //		print("system: \(game?.system.shortName ?? "nil") : trailingConstant:\(trailingConstant) topConstant:\(topConstant)")

//        topRightBadgeWidthConstraint?.constant = imageContentFrame.size.longestLength * 0.25
        topRightBadgeTrailingConstraint?.constant = trailingConstant
        topRightBadgeTopConstraint?.constant = topConstant

        discCountTrailingConstraint?.constant = trailingConstant
        discCountBottomConstraint?.constant = bottomConstant

        missingFileWidthConstraint?.constant = imageContentFrame.width
        missingFileHeightConstraint?.constant = imageContentFrame.height

        roundDiscCountCorners()
    }

    func roundDiscCountCorners() {
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(roundedRect: discCountContainerView!.bounds, byRoundingCorners: [.topLeft], cornerRadii: CGSize(width: 10, height: 10)).cgPath
        discCountContainerView?.layer.mask = maskLayer
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let game = game?.validatedGame {
            let ratio = game.boxartAspectRatio.rawValue
            var imageHeight = size.height
            if Defaults[.showGameTitles] {
                imageHeight -= titleLabel.bounds.height
            }
            let width = imageHeight * ratio
            return CGSize(width: width, height: size.height)
        } else {
            return size
        }
    }

    public override var preferredFocusedView: UIView? {
        return artworkContainerView ?? imageView
    }

    #if os(tvOS)
    public override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)

            //		struct wrapper {
            //			static let s_atvMotionEffect :UIMotionEffectGroup = {
            //				let verticalMotionEffect = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
            //				verticalMotionEffect.minimumRelativeValue = -10
            //				verticalMotionEffect.maximumRelativeValue = 10
//
            //				let horizontalMotionEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            //				horizontalMotionEffect.minimumRelativeValue = -10
            //				horizontalMotionEffect.maximumRelativeValue = 10
//
            //				let motionEffectGroup = UIMotionEffectGroup()
            //				motionEffectGroup.motionEffects = [horizontalMotionEffect, verticalMotionEffect]
            //				return motionEffectGroup
            //			}()
            //		}
//
            coordinator.addCoordinatedAnimations({ () -> Void in
                if self.isFocused {
                    let transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                    if let header = self.superview?.subviews.filter({$0 is PVGameLibrarySectionHeaderView}).first {
                        self.superview?.insertSubview(self, belowSubview: header)
                    } else {
                        self.superview?.bringSubviewToFront(self)
                    }

                    if Defaults[.showGameTitles] {
//                        let imageContentFrame = self.imageView.contentClippingRect // .applying(transform)

                        let yOffset = CGFloat(31.0) // (round(imageContentFrame.maxY) - round(self.titleLabel.frame.minY) + 36)
                        self.titleLabel.textColor = UIColor.white
                        self.titleLabel.transform = transform.translatedBy(x: 0, y: yOffset)
                        self.titleLabel.alpha = 1.0
                        self.titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
                        }
                    //				self.artworkContainerView?.addMotionEffect(wrapper.s_atvMotionEffect)
                } else {
                    //				self.artworkContainerView?.removeMotionEffect(wrapper.s_atvMotionEffect)
                    self.titleLabel.transform = .identity
                    self.titleLabel.textColor = UIColor.darkGray
                    self.titleLabel.font = UIFont.systemFont(ofSize: 20)
                    // self.titleLabel.alpha = 0.0
                }
            }) { () -> Void in }
        }
    #endif
}

extension PVGameLibraryCollectionViewCell: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            return delegate != nil && game != nil && velocity.x < -150 && abs(velocity.y) < 75
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}
