//
//  TouchInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class TouchInputView: UIView
{
    var valueChangedHandler: ((CGPoint?) -> Void)?
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.isMultipleTouchEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        // Manually track touches because UIPanGestureRecognizer delays touches near screen edges,
        // even if we've opted to de-prioritize system gestures.
        self.touchesMoved(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        var adjustedLocation = CGPoint(x: location.x / self.bounds.width, y: location.y / self.bounds.height)
        adjustedLocation.x = min(max(adjustedLocation.x, 0), 1)
        adjustedLocation.y = min(max(adjustedLocation.y, 0), 1)
        
        self.valueChangedHandler?(adjustedLocation)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.touchesEnded(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.valueChangedHandler?(nil)
    }
}
