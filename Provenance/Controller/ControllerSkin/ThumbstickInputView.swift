//
//  ThumbstickInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import simd

extension ThumbstickInputView
{
    private enum Direction
    {
        case up
        case down
        case left
        case right
        
        init?(xAxis: Double, yAxis: Double, threshold: Double)
        {
            let deadzone = -threshold...threshold
            switch (xAxis, yAxis)
            {
            case (deadzone, deadzone): return nil
            case (...0, deadzone): self = .left
            case (0..., deadzone): self = .right
            case (deadzone, ...0): self = .down
            case (deadzone, 0...): self = .up
            default: return nil
            }
        }
    }
}

class ThumbstickInputView: UIView
{
    var isHapticFeedbackEnabled = true
    
    var valueChangedHandler: ((Double, Double) -> Void)?
    
    var thumbstickImage: UIImage? {
        didSet {
            self.update()
        }
    }
    
    var thumbstickSize: CGSize? {
        didSet {
            self.update()
        }
    }
    
    private let imageView = UIImageView(image: nil)
    private let panGestureRecognizer = ImmediatePanGestureRecognizer(target: nil, action: nil)
    
    private let lightFeedbackGenerator = UISelectionFeedbackGenerator()
    private let mediumFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var isActivated = false
    
    private var trackingOrigin: CGPoint?
    private var previousDirection: Direction?
    
    private var isTracking: Bool {
        return self.trackingOrigin != nil
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.panGestureRecognizer.addTarget(self, action: #selector(ThumbstickInputView.handlePanGesture(_:)))
        self.panGestureRecognizer.delaysTouchesBegan = true
        self.panGestureRecognizer.cancelsTouchesInView = true
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        self.addSubview(self.imageView)
        
        self.update()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.update()
    }
}

private extension ThumbstickInputView
{
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer)
    {
        switch gestureRecognizer.state
        {
        case .began:
            let location = gestureRecognizer.location(in: self)
            self.trackingOrigin = location
            
            if self.isHapticFeedbackEnabled
            {
                self.lightFeedbackGenerator.prepare()
                self.mediumFeedbackGenerator.prepare()
            }
            
            self.update()
            
        case .changed:
            // When initially tracking the gesture, we calculate the translation
            // relative to where the user began the pan gesture.
            // This works well, but becomes weird once we leave the bounds then return later,
            // since it's more obvious at that point if the thumbstick position doesn't match the user's finger.
            //
            // To compensate, once we've left the bounds (and have reached maximum translation),
            // we reset the origin we're using for calculation to 0.
            // This won't change the visual position of the thumbstick since it's snapped to the edge,
            // but will correctly track user's finger upon re-entering the bounds.
            
            guard var origin = self.trackingOrigin else { break }

            let location = gestureRecognizer.location(in: self)
            let translationX = location.x - origin.x
            let translationY = location.y - origin.y

            let x = origin.x + translationX
            let y = origin.y + translationY
            
            let horizontalRange = self.bounds.minX...self.bounds.maxX
            let verticalRange = self.bounds.minY...self.bounds.maxY
            
            if !horizontalRange.contains(x) && abs(translationX) >= self.bounds.midX
            {
                origin.x = self.bounds.midX
            }

            if !verticalRange.contains(y) && abs(translationY) >= self.bounds.midY
            {
                origin.y = self.bounds.midY
            }

            let translation = CGPoint(x: translationX, y: translationY)
            self.update(translation)
            
            self.trackingOrigin = origin
            
        case .ended, .cancelled:
            
            if self.isHapticFeedbackEnabled
            {
                self.mediumFeedbackGenerator.impactOccurred()
            }
            
            self.update()
            
            self.trackingOrigin = nil
            self.isActivated = false
            self.previousDirection = nil
            
        default: break
        }
    }
    
    func update(_ translation: CGPoint = CGPoint(x: 0, y: 0))
    {
        let center = SIMD2(Double(self.bounds.midX), Double(self.bounds.midY))
        let point = SIMD2(Double(translation.x), Double(translation.y))
        
        self.imageView.image = self.thumbstickImage
        
        if let size = self.thumbstickSize
        {
            self.imageView.bounds.size = CGSize(width: size.width, height: size.height)
        }
        else
        {
            self.imageView.sizeToFit()
        }
        
        guard !self.bounds.isEmpty, self.isTracking else {
            self.imageView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            return
        }
        
        let maximumDistance = Double(self.bounds.midX)
        let distance = min(simd_length(point), maximumDistance)
        
        let angle = atan2(point.y, point.x)
        
        var adjustedX = distance * cos(angle)
        adjustedX += center.x
        
        var adjustedY = distance * sin(angle)
        adjustedY += center.y
        
        let insetSideLength = maximumDistance / sqrt(2)
        let insetFrame = CGRect(x: center.x - insetSideLength / 2,
                                y: center.y - insetSideLength / 2,
                                width: insetSideLength,
                                height: insetSideLength)
        
        let threshold = 0.1
        
        var xAxis = Double((CGFloat(adjustedX) - insetFrame.minX) / insetFrame.width)
        xAxis = max(xAxis, 0)
        xAxis = min(xAxis, 1)
        xAxis = (xAxis * 2) - 1 // Convert range from [0, 1] to [-1, 1].
        
        if abs(xAxis) < threshold
        {
            xAxis = 0
        }
        
        var yAxis = Double((CGFloat(adjustedY) - insetFrame.minY) / insetFrame.height)
        yAxis = max(yAxis, 0)
        yAxis = min(yAxis, 1)
        yAxis = -((yAxis * 2) - 1) // Convert range from [0, 1] to [-1, 1], then invert it (due to flipped coordinates).
        
        if abs(yAxis) < threshold
        {
            yAxis = 0
        }
        
        let magnitude = simd_length(SIMD2(xAxis, yAxis))
        let isActivated = (magnitude > 0.1)
        
        if let direction = Direction(xAxis: xAxis, yAxis: yAxis, threshold: threshold)
        {
            if self.previousDirection != direction && self.isHapticFeedbackEnabled
            {
                self.mediumFeedbackGenerator.impactOccurred()
            }
            
            self.previousDirection = direction
        }
        else
        {
            if isActivated && !self.isActivated && self.isHapticFeedbackEnabled
            {
                self.lightFeedbackGenerator.selectionChanged()
            }
            
            self.previousDirection = nil
        }
        
        self.isActivated = isActivated

        self.imageView.center = CGPoint(x: adjustedX, y: adjustedY)
        self.valueChangedHandler?(xAxis, yAxis)
    }
}
