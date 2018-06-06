//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  JSButton.swift
//  Controller
//
//  Created by James Addyman on 29/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import UIKit

protocol JSButtonDelegate: class {
    func buttonPressed(_ button: JSButton)
    func buttonReleased(_ button: JSButton)
}

class JSButton: UIView {
    private(set) var titleLabel: UILabel!
    private var backgroundImageView: UIImageView! {
        didSet {
            backgroundImageView.image = backgroundImage
        }
    }

    var backgroundImage: UIImage? {
        didSet {
            if pressed {
                backgroundImageView.image = backgroundImage
            }
        }
    }
    var backgroundImagePressed: UIImage? {
        didSet {
            if !pressed {
                backgroundImageView.image = backgroundImage
            }
        }
    }

    var titleEdgeInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    override var tintColor: UIColor? {
        didSet {
            if PVSettingsModel.shared.buttonTints {
                backgroundImageView?.tintColor = tintColor
            } else {
                backgroundImageView?.tintColor = UIColor.white
            }
        }
    }

    var pressed = false {
        didSet {
            if pressed == oldValue {
                return
            }

            backgroundImageView?.image = pressed ? backgroundImagePressed : backgroundImage
        }
    }
    weak var delegate: JSButtonDelegate?

    func setEnabled(_ enabled: Bool) {
        isUserInteractionEnabled = enabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
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
        delegate?.buttonPressed(self)
        pressed = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        delegate?.buttonReleased(self)
        pressed = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.buttonReleased(self)
        pressed = false
    }
}
