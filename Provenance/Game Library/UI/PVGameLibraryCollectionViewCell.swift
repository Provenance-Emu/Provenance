//  PVGameLibraryCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

// import RealmSwift
import CoreGraphics
import AVFoundation

private let LabelHeight: CGFloat = 44.0

enum BlendModes : String {
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
	var topLeftPoint : CGPoint {
		return CGPoint(x: 0, y: 0)
	}

	var topRightPoint : CGPoint {
		return CGPoint(x: maxX, y: 0)
	}

	var bottomRightPoint : CGPoint {
		return CGPoint(x: maxX, y: maxY)
	}

	var bottomLeftPoint : CGPoint {
		return CGPoint(x: 0, y: maxY)
	}

}

extension CGSize {
	enum Orientation {
		case landscape
		case portrait
		case square
	}

	var orientation : Orientation {
		if width > height {
			return .landscape
		} else if height > width {
			return .portrait
		} else {
			return .square
		}
	}

	var aspectRatio : CGFloat {
		switch orientation {
		case .portrait:
			return width / height
		case .landscape:
			return height / width
		case .square:
			return 1.0
		}
	}

	var longestLength : CGFloat {
		return max(width, height)
	}

	var shortestLength : CGFloat {
		return min(width, height)
	}

	var debugDescription : String {
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
	func scaleAspectToFitInside(_ rect : CGRect) -> CGRect {
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
		return AVMakeRect(aspectRatio: self.size, insideRect: rect)
	}

	var debugDescription : String {
		return "(x:\(origin.x) y:\(origin.y) width:\(size.width) height:\(size.height))"
	}
}

extension UIImageView {
	// What is the bounds of the image when it's scaled to fit
	var contentClippingRect: CGRect {
		guard let image = image else {
			VLOG("No image")
			return bounds
		}
		guard contentMode == .scaleAspectFit else {
			VLOG("Unsupported content mode")
			return bounds
		}
		let imageSize = image.size
		guard imageSize.width > 0 && imageSize.height > 0 else { return bounds }

		var clippingRect = CGRect(origin: .zero, size: imageSize).scaleAspectToFitInside(bounds)
		clippingRect.origin.x = (bounds.width - clippingRect.width) / 2.0
		clippingRect.origin.y = (bounds.height - clippingRect.height) / 2.0

//		VLOG("imageSize:\(imageSize.debugDescription) bounds:\(bounds.debugDescription) clippingRect:\(clippingRect.debugDescription) ratio:\(imageSize.aspectRatio)")

		return clippingRect
	}
}

//@IBDesignable
class CornerBadgeView : UIView {
	enum FillCorner {
		case topLeft
		case topRight
		case bottomLeft
		case bottomRight
	}

	@IBInspectable var glyph : String = "" {
		didSet {
			setNeedsDisplay()
		}
	}

	@IBInspectable var fillColor : UIColor = UIColor.orange {
		didSet {
			setNeedsDisplay()
		}
	}

	@IBInspectable var strokeColor : UIColor = UIColor.orange {
		didSet {
			setNeedsDisplay()
		}
	}

	@IBInspectable var textColor : UIColor = UIColor.black {
		didSet {
			setNeedsDisplay()
		}
	}

	var fillCorner : FillCorner = .topRight {
		didSet {
			setNeedsDisplay()
		}
	}

	override func draw(_ rect: CGRect) {
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
			triangleBounds = triangleBounds.offsetBy(dx: triangleBounds.size.width * 0.35, dy: triangleBounds.size.width * -0.15)
		default:
			break
		}

		let attributes : [NSAttributedStringKey:Any] = [ .font: UIFont.systemFont(ofSize: triangleBounds.height*0.7), .foregroundColor: textColor ]
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

extension UIImage {
    class func image(withSize size: CGSize, color: UIColor, text: NSAttributedString) -> UIImage? {

        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)

        guard let context: CGContext = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(color.cgColor)
        context.setStrokeColor(UIColor(white: 0.7, alpha: 0.6).cgColor)
        context.setLineWidth(0.5)
        context.fill(rect)
        var boundingRect: CGRect = text.boundingRect(with: rect.size, options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
        boundingRect.origin = CGPoint(x: rect.midX - (boundingRect.width / 2), y: rect.midY - (boundingRect.height / 2))
        text.draw(in: boundingRect)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

	func imageWithBorder(width: CGFloat, color: UIColor) -> UIImage? {
		let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
		imageView.contentMode = .center
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

class PVGameLibraryCollectionViewCell: UICollectionViewCell {
	@IBOutlet private(set) var imageView: UIImageView! {
		didSet {
			if #available(iOS 9.0, tvOS 9.0, *) {

			} else {
				imageView.contentMode = .scaleAspectFit
				imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			}

			#if os(iOS)
			//Ignore Smart Invert
			imageView.ignoresInvertColors = true
			#else
			imageView.adjustsImageWhenAncestorFocused = true
			imageView.clipsToBounds = false
			#endif
		}
	}
	@IBOutlet /*weak*/ var artworkContainerView: UIView?

	@IBOutlet /*weak*/ var discCountContainerView: UIView? {
		didSet {
			roundDiscCountCorners()
		}
	}
	@IBOutlet /*weak*/ var discCountLabel: UILabel? {
		didSet {
			discCountLabel?.adjustsFontSizeToFitWidth = true
		}
	}
	@IBOutlet weak var topRightCornerBadgeView: CornerBadgeView?

	@IBOutlet private(set) var titleLabel: UILabel! {
		didSet {
			#if os(tvOS)
			// The label's alpha will get set to 1 on focus
			titleLabel.alpha = 0
			titleLabel.textColor = UIColor.white
			titleLabel.layer.masksToBounds = false
			titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.8)
			titleLabel.shadowOffset = CGSize(width: -1, height: 1)

			#else // iOS

			if #available(iOS 9.0, tvOS 9.0, *) {
				// Use XIB
			} else {
				titleLabel.font = titleLabel.font.withSize(12)

				titleLabel.backgroundColor = UIColor.clear
				titleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
				titleLabel.textAlignment = .center
				titleLabel.baselineAdjustment = .alignBaselines
				titleLabel.numberOfLines = 2
			}

			#endif

			if #available(iOS 9.0, tvOS 9.0, *) {
//				titleLabel.allowsDefaultTighteningForTruncation = true
//				titleLabel.translatesAutoresizingMaskIntoConstraints = false
			} else {
				titleLabel.lineBreakMode = .byTruncatingTail

				titleLabel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
				titleLabel.minimumScaleFactor = 0.6

				titleLabel.backgroundColor = UIColor.clear
				titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
				titleLabel.textAlignment = .center
				titleLabel.adjustsFontSizeToFitWidth = true
			}

		}
	}
    var operation: BlockOperation?

	@IBOutlet weak var missingFileView: UIView? {
		didSet {
//			missingFileView!.layer.compositingFilter = BlendModes.hardLightBlendMode.rawValue //"colorDodgeBlendMode"
		}
	}
	@IBOutlet weak var missingRedSquareView: UIView! {
		didSet {
			missingRedSquareView.layer.compositingFilter = BlendModes.hardLightBlendMode.rawValue //"colorDodgeBlendMode"
		}
	}

	@IBOutlet weak var waringSignLabel: UIImageView! {
		didSet {
//			waringSignLabel.layer.compositingFilter = BlendModes.screenBlendMode.rawValue //"colorDodgeBlendMode"
		}
	}
	@IBOutlet weak var topRightBadgeTopConstraint: NSLayoutConstraint?
	@IBOutlet weak var topRightBadgeTrailingConstraint: NSLayoutConstraint?
	@IBOutlet weak var topRightBadgeWidthConstraint: NSLayoutConstraint?
	@IBOutlet weak var discCountTrailingConstraint: NSLayoutConstraint?
	@IBOutlet weak var missingFileWidthContraint: NSLayoutConstraint?
	@IBOutlet weak var missingFileHeightContraint: NSLayoutConstraint?
	@IBOutlet weak var titleLabelHeightConstraint: NSLayoutConstraint?

	class func cellSize(forImageSize imageSize: CGSize) -> CGSize {
		let size : CGSize
		if #available(iOS 9.0, tvOS 9.0, *) {
			size = CGSize(width: imageSize.width, height: imageSize.height + (imageSize.height * 0.15))
		} else {
			size = CGSize(width: imageSize.width, height: imageSize.height + LabelHeight)
		}
		return size
    }

	#if os(tvOS)
	override var canBecomeFocused: Bool {
		return true
	}

	#endif

    var token: NotificationToken?
    var game: PVGame? {
        didSet {
            DispatchQueue.main.async { [unowned self] in
                self.token?.invalidate()

                if let game = self.game {
                    self.token = game.observe { [weak self] change in
                        switch change {
                        case .change(let properties):
                            if !properties.isEmpty {
                                self?.setup(with: game)
                            }
                        case .error(let error):
                            ELOG("An error occurred: \(error)")
                        case .deleted:
                            ELOG("The object was deleted.")
                        }
                    }
					self.missingFileView?.isHidden = !game.file.missing
                    self.setup(with: game)
				} else {
					self.discCountContainerView?.isHidden = true
					self.topRightCornerBadgeView?.isHidden = true
					self.missingFileView?.isHidden = true
				}

				self.tintImageIfMissing()
            }
        }
    }

    deinit {
        token?.invalidate()
    }

	private func updateImageBageConstraints() {

	}

    private func setup(with game: PVGame) {
        let artworkURL: String = game.customArtworkURL
        let originalArtworkURL: String = game.originalArtworkURL
        if PVSettingsModel.shared.showGameTitles {
            titleLabel.text = game.title
        }

            // TODO: May be renabled later
        let placeholderImageText: String = game.title
        if artworkURL.isEmpty && originalArtworkURL.isEmpty {
            var artworkText: String
            if PVSettingsModel.shared.showGameTitles {
                artworkText = placeholderImageText
            } else {
                artworkText = game.title
            }
			imageView.image = image(withText: artworkText) //?.withRenderingMode(.alwaysTemplate)
			updateImageConstraints()
			setNeedsLayout()
        } else {
            var maybeKey: String? = !artworkURL.isEmpty ? artworkURL : nil
            if maybeKey == nil {
                maybeKey = !originalArtworkURL.isEmpty ? originalArtworkURL : nil
            }
            if let key = maybeKey {
                operation = PVMediaCache.shareInstance().image(forKey: key, completion: {(_ image: UIImage?) -> Void in
					DispatchQueue.main.async {
						var artworkText: String
						if PVSettingsModel.shared.showGameTitles {
							artworkText = placeholderImageText
						} else {
							artworkText = game.title
						}
						let artwork: UIImage? = image ?? self.image(withText: artworkText)
						self.imageView.image = artwork //?.imageWithBorder(width: 1, color: UIColor.red) //?.withRenderingMode(.alwaysTemplate)
						#if os(tvOS)
						let width: CGFloat = self.frame.width
						let boxartSize = CGSize(width: width, height: width / game.boxartAspectRatio.rawValue)
						self.imageView.frame = CGRect(x: 0, y: 0, width: width, height: boxartSize.height)
						#else
						if #available(iOS 9.0, tvOS 9.0, *) {
						} else {
							var imageHeight: CGFloat = self.frame.size.height
							if PVSettingsModel.shared.showGameTitles {
								imageHeight -= 44
							}
							self.imageView.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: imageHeight)
						}
						#endif
						self.updateImageConstraints()
						self.setNeedsLayout()
					}
                })
            }
        }

		self.setupBadges()

        setNeedsLayout()
        if #available(iOS 9.0, tvOS 9.0, *) {
            setNeedsFocusUpdate()
        }
    }

	func tintImageIfMissing() {
//		let missing = game?.file.missing ?? true
//		imageView.tintColor = missing ? UIColor.red : nil
	}

	private func setupBadges() {
		if !PVSettingsModel.shared.showGameBadges {
			self.topRightCornerBadgeView?.isHidden = true
			return
		}

		guard let game = game else {
			self.topRightCornerBadgeView?.isHidden = true
			self.discCountContainerView?.isHidden = true
			return
		}

		let multieDisc = game.isCD && game.discCount > 1
		self.discCountContainerView?.isHidden = !multieDisc
		self.discCountLabel?.text = "\(game.discCount)"
		self.discCountLabel?.textColor = UIColor.white

		let hasPlayed = game.playCount > 0
		let favorite = game.isFavorite
		self.topRightCornerBadgeView?.glyph = favorite ? "★" : ""

		if favorite {
			#if os(iOS)
			self.topRightCornerBadgeView?.fillColor = Theme.currentTheme.barButtonItemTint!.withAlphaComponent(0.65)
			#else
			self.topRightCornerBadgeView?.fillColor = UIColor.blue.withAlphaComponent(0.65)
			#endif
		} else if !hasPlayed {
			self.topRightCornerBadgeView?.fillColor = UIColor(hex: "FF9300")!.withAlphaComponent(0.65)
		}

		self.topRightCornerBadgeView?.isHidden = hasPlayed && !favorite
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		#if os(iOS)
		if #available(iOS 9.0, *) {
			// Using nibs
		} else {
			oldViewInit()
		}
		#else
		oldViewInit()
		#endif

		titleLabel.isHidden = !PVSettingsModel.shared.showGameTitles
	}

	private func oldViewInit() {
		var imageHeight: CGFloat = frame.size.height
		if PVSettingsModel.shared.showGameTitles {
			imageHeight -= 44
		}

		let imageView = UIImageView()
		self.imageView = imageView

		let newTitleLabel = UILabel()
		self.titleLabel = newTitleLabel

		contentView.addSubview(titleLabel)
		contentView.addSubview(imageView)

		let imageFrame = CGRect(x: 0, y: 0, width: frame.size.width, height: imageHeight)
		let titleFrame = CGRect(x: 0, y: imageView.frame.size.height, width: frame.size.width, height: LabelHeight)

		let dccWidth = imageFrame.size.width * 0.25
		let discCountContainerFrame = CGRect(x: imageFrame.maxX-dccWidth, y: imageFrame.maxX-dccWidth, width: dccWidth, height: dccWidth)
		discCountContainerView = UIView(frame: discCountContainerFrame)
		contentView.addSubview(discCountContainerView!)

		discCountLabel = UILabel(frame: CGRect(x: 0, y: 0, width: dccWidth, height: dccWidth))
		discCountContainerView?.addSubview(discCountLabel!)

		if #available(iOS 9.0, tvOS 9.0, *) {
			discCountContainerView?.trailingAnchor.constraint(equalTo: imageView.trailingAnchor).isActive = true
			discCountContainerView?.bottomAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
			discCountContainerView?.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.25, constant: 0).isActive = true
			discCountContainerView?.heightAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 0.25, constant: 0).isActive = true

			discCountLabel?.centerXAnchor.constraint(equalTo: discCountContainerView!.centerXAnchor).isActive = true
			discCountLabel?.centerYAnchor.constraint(equalTo: discCountContainerView!.centerYAnchor).isActive = true
			discCountLabel?.leadingAnchor.constraint(equalTo: discCountContainerView!.leadingAnchor, constant: 8.0).isActive = true
			discCountLabel?.trailingAnchor.constraint(equalTo: discCountContainerView!.trailingAnchor, constant: 8.0).isActive = true
			discCountLabel?.heightAnchor.constraint(equalTo: discCountContainerView!.heightAnchor, multiplier: 0.75, constant: 0).isActive = true
		} else {
			// TODO: iOS 8 layout, or just hide them?
			discCountContainerView?.isHidden = true
		}
		imageView.frame = imageFrame
		titleLabel.frame = titleFrame
	}

    required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
    }

	override func awakeFromNib() {
		super.awakeFromNib()

		self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		self.contentView.translatesAutoresizingMaskIntoConstraints = true

		titleLabel.isHidden = !PVSettingsModel.shared.showGameTitles

//		contentView.layer.borderWidth = 1.0
//		contentView.layer.borderColor = UIColor.white.cgColor
//
//		imageView.layer.borderWidth = 1.0
//		imageView.layer.borderColor = UIColor.green.cgColor
	}

    func image(withText text: String) -> UIImage? {
        #if os(iOS)
        let backgroundColor: UIColor = Theme.currentTheme.settingsCellBackground!
        #else
        let backgroundColor: UIColor = UIColor.init(white: 0.9, alpha: 0.9)
        #endif
        if text == "" {
            return UIImage.image(withSize: CGSize(width: CGFloat(PVThumbnailMaxResolution), height: CGFloat(PVThumbnailMaxResolution)), color: backgroundColor, text: NSAttributedString(string: ""))
        }
            // TODO: To be replaced with the correct system placeholder
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        #if os(iOS)
        let attributedText = NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 30.0), NSAttributedStringKey.paragraphStyle: paragraphStyle, NSAttributedStringKey.foregroundColor: Theme.currentTheme.settingsCellText!])
        #else
        let attributedText = NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 30.0), NSAttributedStringKey.paragraphStyle: paragraphStyle, NSAttributedStringKey.foregroundColor: UIColor.gray])
        #endif

        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let ratio: CGFloat = game?.boxartAspectRatio.rawValue ?? 1.0
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
//		imageView.tintColor = nil
        titleLabel.text = nil
		discCountContainerView?.isHidden = true
		topRightCornerBadgeView?.isHidden = true
		missingFileView?.isHidden = true
        token?.invalidate()
        token = nil
    }

    override func layoutSubviews() {
		super.layoutSubviews()

		titleLabel.isHidden = !PVSettingsModel.shared.showGameTitles
#if os(tvOS)
        let titleTransform: CGAffineTransform = titleLabel.transform
        if isFocused {
            titleLabel.transform = .identity
        }
        contentView.bringSubview(toFront: titleLabel ?? UIView())
        titleLabel.sizeToFit()
        titleLabel.setWidth(contentView.bounds.size.width)
        titleLabel.setOriginX(0)
        titleLabel.setOriginY(imageView.frame.maxY)
        titleLabel.transform = titleTransform
#else
		if #available(iOS 9.0, tvOS 9.0, *) {
			self.contentView.frame = self.bounds
		} else {
			var imageHeight: CGFloat = frame.size.height
			if PVSettingsModel.shared.showGameTitles {
				imageHeight -= 44
			}
			imageView.frame.size.height = imageHeight
		}
#endif

		updateImageConstraints()

		#if os(iOS)
		if !PVSettingsModel.shared.showGameTitles, let titleLabelHeightConstraint = titleLabelHeightConstraint {
			titleLabelHeightConstraint.constant = contentView.bounds.height * titleLabelHeightConstraint.multiplier * -1
		} else {
			titleLabelHeightConstraint?.constant = 0.0
		}
		#endif
    }

	func updateImageConstraints() {
		let imageContentFrame = imageView.contentClippingRect

		let topConstant = imageContentFrame.origin.y
		let trailingConstant = imageContentFrame.origin.x * -1.0
//		print("system: \(game?.system.shortName ?? "nil") : trailingConstant:\(trailingConstant) topConstant:\(topConstant)")

		topRightBadgeWidthConstraint?.constant = imageContentFrame.size.longestLength * 0.25
		topRightBadgeTrailingConstraint?.constant = trailingConstant
		topRightBadgeTopConstraint?.constant = topConstant

		discCountTrailingConstraint?.constant = trailingConstant

		missingFileWidthContraint?.constant = imageContentFrame.width
		missingFileHeightContraint?.constant = imageContentFrame.height

		roundDiscCountCorners()
	}

	func roundDiscCountCorners() {
		let maskLayer = CAShapeLayer()
		maskLayer.path = UIBezierPath(roundedRect: discCountContainerView!.bounds, byRoundingCorners: [.topLeft], cornerRadii: CGSize(width: 10, height: 10)).cgPath
		discCountContainerView?.layer.mask = maskLayer
	}

	override func sizeThatFits(_ size: CGSize) -> CGSize {
		if let game = game {
			let ratio = game.boxartAspectRatio.rawValue
			var imageHeight = size.height
			imageHeight *= PVSettingsModel.shared.showGameTitles ? 0.85 : 1.0
			let width = imageHeight * ratio
			return CGSize(width: width, height: size.height)
		} else {
			return size
		}
	}

	override var preferredFocusedView: UIView? {
		return artworkContainerView ?? imageView
	}
}
