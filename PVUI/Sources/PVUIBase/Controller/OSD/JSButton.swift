//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  JSButton.swift
//  Controller
//
//  Created by James Addyman on 29/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import PVSupport
#if canImport(UIKit)
import UIKit
#endif
import PVSettings
import PVThemes

public enum ControlTag: Int {
    case dpad1 = 100
    case dpad2 = 101
    case joypad1 = 102
    case joypad2 = 103
    case buttonGroup = 200
    case leftShoulder = 301
    case rightShoulder = 302
    case leftShoulder2 = 303
    case rightShoulder2 = 304
    case zTrigger = 305
    case start = 401
    case select = 402
    case leftAnalog = 501
    case rightAnalog = 502
}

protocol JSButtonDelegate: AnyObject {
    func buttonPressed(_ button: JSButton)
    func buttonReleased(_ button: JSButton)
}

/// A button that can be moved and resized in the UI
final class JSButton: MovableButtonView {
    /// The label text for the button
    private(set) var label: String?
    private(set) var titleLabel: UILabel!
    private var backgroundImageView: UIImageView! {
        didSet {
            DispatchQueue.main.async { [unowned self] in
                self.backgroundImageView.image = backgroundImage
            }
        }
    }

    // MARK: - NSCoding
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(label, forKey: "label")
        coder.encode(titleLabel?.text ?? "", forKey: "titleText")
        coder.encode(titleEdgeInsets, forKey: "titleEdgeInsets")
        coder.encode(pressed, forKey: "pressed")
        coder.encode(isUserInteractionEnabled, forKey: "isEnabled")
    }

    required init?(coder: NSCoder) {
        label = coder.decodeObject(forKey: "label") as? String ?? ""
        super.init(coder: coder)

        // Initialize UI elements
        commonInit()

        // Set decoded values
        titleLabel.text = coder.decodeObject(forKey: "titleText") as? String
        titleEdgeInsets = coder.decodeUIEdgeInsets(forKey: "titleEdgeInsets")
        pressed = coder.decodeBool(forKey: "pressed")
        isUserInteractionEnabled = coder.decodeBool(forKey: "isEnabled")
    }

    public required init(frame: CGRect, label: String?) {
        self.label = label
        super.init(frame: frame)
        commonInit()
    }

    var backgroundImage: UIImage? {
        didSet {
            if pressed {
                DispatchQueue.main.async { [unowned self] in
                    self.backgroundImageView.image = backgroundImage
                }
            }
        }
    }

    var backgroundImagePressed: UIImage? {
        didSet {
            if !pressed {
                DispatchQueue.main.async { [unowned self] in
                    self.backgroundImageView.image = backgroundImage
                }
            }
        }
    }

//	var hitAreaInset: UIEdgeInsets {
//		let width = frame.size.width
//		let height = frame.size.height
//		let widthInset = width * -0.5
//		let heightInset = height * -0.5
//		return UIEdgeInsets(top: heightInset,
//							left: widthInset,
//							bottom: heightInset,
//							right: widthInset)
//	}

    var titleEdgeInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    override var tintColor: UIColor? {
        didSet {
            if Defaults[.buttonTints] {
                backgroundImageView?.tintColor = tintColor
            } else {
                backgroundImageView?.tintColor = ThemeManager.shared.currentPalette.defaultTintColor ?? UIColor.white
            }
        }
    }

    var pressed = false {
        didSet {
            if pressed == oldValue {
                return
            }

            DispatchQueue.main.async { [unowned self] in
                self.backgroundImageView?.image = pressed ? backgroundImagePressed : backgroundImage
            }
        }
    }

    weak var delegate: JSButtonDelegate?

    func setEnabled(_ enabled: Bool) {
        isUserInteractionEnabled = enabled
    }

    func commonInit() {
        backgroundImageView = UIImageView(image: backgroundImage)
        backgroundImageView.frame = bounds
        backgroundImageView.contentMode = .center
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundImageView.layer.shadowColor = UIColor.black.cgColor
        backgroundImageView.layer.shadowRadius = 4.0
        backgroundImageView.layer.shadowOpacity = 0.75
        backgroundImageView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        addSubview(backgroundImageView)

        titleLabel = UILabel()
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.shadowRadius = 1.0
        titleLabel.layer.shadowOpacity = 0.75
        titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        titleLabel.frame = bounds
        titleLabel.textAlignment = .center
        titleLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(titleLabel)

        addObserver(self as NSObject, forKeyPath: "pressed", options: .new, context: nil)
        addObserver(self as NSObject, forKeyPath: "backgroundImage", options: .new, context: nil)
        addObserver(self as NSObject, forKeyPath: "backgroundImagePressed", options: .new, context: nil)
        pressed = false
        tintColor = UIColor.white
    }

    deinit {
        removeObserver(self as NSObject, forKeyPath: "pressed")
        removeObserver(self as NSObject, forKeyPath: "backgroundImage")
        removeObserver(self as NSObject, forKeyPath: "backgroundImagePressed")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView?.frame = bounds

        if let titleLabel = titleLabel {
            titleLabel.frame = bounds
            var frame = titleLabel.frame
            frame.origin.x += titleEdgeInsets.left
            frame.origin.y += titleEdgeInsets.top
            frame.size.width -= titleEdgeInsets.right
            frame.size.height -= titleEdgeInsets.bottom
            titleLabel.frame = frame
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isUserInteractionEnabled {
            // DLOG("Touch ignored - button not enabled")
            return
        }

        if inMoveMode {
            // DLOG("Touch in move mode - delegating to super")
            super.touchesBegan(touches, with: event)
            return
        }

        // DLOG("Normal button touch began")
        delegate?.buttonPressed(self)
        pressed = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isUserInteractionEnabled {  return }

        if inMoveMode {
            super.touchesMoved(touches, with: event)
            return
        }

        guard let touch = touches.first else {
            return
        }

        let point = touch.location(in: superview)
        let touchArea = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)

        var pressed: Bool = self.pressed
        if !touchArea.intersects(frame) {
            if pressed {
                pressed = false
                delegate?.buttonReleased(self)
            }
        } else if !pressed {
            pressed = true
            delegate?.buttonPressed(self)
        }

        self.pressed = pressed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isUserInteractionEnabled {  return }

        if inMoveMode {
            super.touchesEnded(touches, with: event)
            return
        }

        delegate?.buttonReleased(self)
        pressed = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isUserInteractionEnabled {  return }

        if inMoveMode {
            super.touchesCancelled(touches, with: event)
            return
        }

        delegate?.buttonReleased(self)
        pressed = false
    }
}
