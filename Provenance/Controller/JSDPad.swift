//
//  JSDPad.swift
//  Controller
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import UIKit

enum JSDPadDirection: Int {
    case upLeft = 1
    case up
    case upRight
    case left
    case none
    case right
    case downLeft
    case down
    case downRight
}

protocol JSDPadDelegate: class {
    func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection)
    func dPadDidReleaseDirection(_ dPad: JSDPad)
}

class JSDPad: UIView {
    weak var delegate: JSDPadDelegate?

    private var currentDirection: JSDPadDirection = .none

    private lazy var dPadImageView: UIImageView = {
        let dPadImageView = UIImageView(image: UIImage(named: "dPad-None"))
        let frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height)
        dPadImageView.frame = frame
        dPadImageView.translatesAutoresizingMaskIntoConstraints = true
        dPadImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dPadImageView.contentMode = .center
        dPadImageView.layer.masksToBounds = false
        dPadImageView.layer.shadowColor = UIColor.black.cgColor
        dPadImageView.layer.shadowRadius = 4.0
        dPadImageView.layer.shadowOpacity = 0.75
        dPadImageView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        return dPadImageView
    }()

    func setEnabled(_ enabled: Bool) {
        isUserInteractionEnabled = enabled
    }

    override var tintColor: UIColor? {
        didSet {
            dPadImageView.tintColor = PVSettingsModel.shared.buttonTints ? tintColor : .white
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        tintColor = .white
        addSubview(dPadImageView)
        clipsToBounds = false
    }

    func direction(for point: CGPoint) -> JSDPadDirection {
        let x: CGFloat = point.x
        let y: CGFloat = point.y
        if (x <= 0) || (x >= bounds.size.width) || (y <= 0) || (y >= bounds.size.height) {
            return .none
        }
        let column = Int((x / (bounds.size.width / 3)))
        let row = Int((y / (bounds.size.height / 3)))
        let direction = JSDPadDirection(rawValue: (row * 3) + column + 1)!
        return direction
    }

    func image(for direction: JSDPadDirection) -> UIImage? {
        var image: UIImage? = nil
        switch direction {
            case .up:
                image = UIImage(named: "dPad-Up")
            case .down:
                image = UIImage(named: "dPad-Down")
            case .left:
                image = UIImage(named: "dPad-Left")
            case .right:
                image = UIImage(named: "dPad-Right")
            case .upLeft:
                image = UIImage(named: "dPad-UpLeft")
            case .upRight:
                image = UIImage(named: "dPad-UpRight")
            case .downLeft:
                image = UIImage(named: "dPad-DownLeft")
            case .downRight:
                image = UIImage(named: "dPad-DownRight")
            case .none:
                image = UIImage(named: "dPad-None")
        }
        return image
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let point = touch.location(in: self)
        let direction: JSDPadDirection = self.direction(for: point)
        if direction != currentDirection {
            currentDirection = direction
            dPadImageView.image = image(for: currentDirection)

            delegate?.dPad(self, didPress: currentDirection)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let point = touch.location(in: self)
        let direction: JSDPadDirection = self.direction(for: point)
        if direction != currentDirection {
            currentDirection = direction
            dPadImageView.image = image(for: currentDirection)
            delegate?.dPad(self, didPress: currentDirection)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentDirection = .none
        dPadImageView.image = image(for: currentDirection)
        delegate?.dPadDidReleaseDirection(self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentDirection = .none
        dPadImageView.image = image(for: currentDirection)
        delegate?.dPadDidReleaseDirection(self)
    }
}
