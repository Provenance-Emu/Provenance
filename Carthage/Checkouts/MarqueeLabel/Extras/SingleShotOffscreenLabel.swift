//
//  SingleShotOffscreenLabel.swift
//  MarqueeLabelSwift
//
//  Created by Charles Powell on 10/24/16.
//  Copyright © 2016 Charles Powell. All rights reserved.
//

import UIKit

open class SingleShotOffscreenLabel: MarqueeLabel {
    // Override layoutSubviews to catch frame size changes
    open override func layoutSubviews() {
        // Set trailingBuffer to frame width + 10 (to be sure)
        trailingBuffer = frame.width
        super.layoutSubviews()
    }
    
    // Override labelWillBeginScroll to catch when a scroll animation starts
    open override func labelWillBeginScroll() {
        // This only makes sense for leftRight and rightLeft types
        if type == .leftRight || type == .rightLeft {
            // Calculate "away" position time after scroll start
            let awayTime = animationDelay + animationDuration
            // Schedule a timer to restart the label when it hits the "away" position
            Timer.scheduledTimer(timeInterval: TimeInterval(awayTime), target: self, selector: #selector(pauseAndClear), userInfo: nil, repeats: false)
        }
    }
    
    @objc public func pauseAndClear() {
        // Pause label offscreen
        pauseLabel()
        // Change text to nil
        text = nil
        // Unpause (empty) label, clearing the way for a subsequent text change to trigger scroll
        unpauseLabel()
    }
}
