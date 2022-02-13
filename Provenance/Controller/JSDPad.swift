//
//  JSDPad.swift
//  Controller
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import UIKit

enum JSDPadDirection: Int, CaseIterable {
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

typealias JoystickValue = (x: Float, y: Float)

protocol JSDPadDelegate: AnyObject {
    func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection)
    func dPad(_ dPad: JSDPad, joystick value: JoystickValue)
    func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection)
}


final class JSDPad: UIView {
    
    public class func JoyPad(frame: CGRect) -> JSDPad {
        let dpad = JSDPad.init(frame: frame)
        dpad.analogMode = true
        return dpad
    }
    
    var analogMode: Bool = false {
        didSet {
            dPadImageView.isHidden = analogMode
        }
    }
    
    lazy var centerPoint: CGPoint = CGPoint(x: bounds.midX, y: bounds.midY)
    lazy var analogPoint: CGPoint = centerPoint {
        didSet {
            let radius: CGFloat = (frame.size.width - 10)/12

            let maxX = bounds.width - radius
            let minX: CGFloat = radius
            let maxY = bounds.height - radius
            let minY: CGFloat = radius

            var point = analogPoint
            var needUpdate = false
            if point.x > maxX {
                point.x = maxX
                needUpdate = true
            } else if point.x < minX {
                point.x = minX
                needUpdate = true
            }
            if point.y > maxY {
                point.y = maxY
                needUpdate = true
            } else if point.y < minY {
                point.y = minY
                needUpdate = true
            }
            
            if needUpdate {
                analogPoint = point
            } else {
                setNeedsDisplay()
            }
        }
    }
    
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
        dPadImageView.isHidden = analogMode
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
        var image: UIImage?
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

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let delegate = delegate, let touch = touches.first else {
            return
        }

        let point = touch.location(in: self)
        if analogMode {
            analogPoint = point
            sendJoyPoint(point)
        } else {
            let direction: JSDPadDirection = self.direction(for: point)
            if direction != currentDirection {
                currentDirection = direction
                dPadImageView.image = image(for: currentDirection)

                delegate.dPad(self, didPress: currentDirection)
            }
        }
    }
    
    private func sendJoyPoint(_ point: CGPoint) {
        let x: CGFloat = (point.x / self.bounds.width)
        let y: CGFloat = (point.y / self.bounds.height)
        delegate!.dPad(self, joystick: (x: Float(x), y: Float(y)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let delegate = delegate, let touch = touches.first else {
            return
        }

        let point = touch.location(in: self)
        if analogMode {
            analogPoint = point
            sendJoyPoint(point)
        } else {
            let direction: JSDPadDirection = self.direction(for: point)
            if direction != currentDirection {
                currentDirection = direction
                dPadImageView.image = image(for: currentDirection)
                delegate.dPad(self, didPress: currentDirection)
            }
        }
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        currentDirection = .none
        dPadImageView.image = image(for: currentDirection)
        
        guard let delegate = delegate else {
            return
        }

        if analogMode {
            analogPoint = centerPoint
            sendJoyPoint(centerPoint)
        } else {
            JSDPadDirection.allCases.forEach { delegate.dPad(self, didRelease: $0) }
        }
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        currentDirection = .none
        dPadImageView.image = image(for: currentDirection)
        
        guard let delegate = delegate else {
            return
        }

        if analogMode {
            analogPoint = centerPoint
            sendJoyPoint(centerPoint)
        } else {
            JSDPadDirection.allCases.forEach { delegate.dPad(self, didRelease: $0) }
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard analogMode else {
            super.draw(rect)
            return
        }
        // Get the Graphics Context
        if let context = UIGraphicsGetCurrentContext() {
            
            context.clear(rect)
            
            // Set the circle outerline-width
            context.setLineWidth(5.0)
            
            // Set the circle outerline-colour
            tintColor?.set()
            
            // Create Circle
            let radius = (frame.size.width - 10)/2
            context.addArc(center: centerPoint, radius: radius, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: true)
                
            // Draw
            context.strokePath()
            
            // Create touch point
            context.addArc(center: analogPoint, radius: radius / 6, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: true)
            // Draw
            context.fillPath()
        }
    }
}
