//
//  NoAnimationReturn.swift
//  MarqueeLabel
//
//  Created by Charles Powell on 10/23/16.
//  Copyright © 2016 Charles Powell. All rights reserved.

import UIKit

open class NoAnimationReturn: MarqueeLabel {
    // Override labelWillBeginScroll to catch when a scroll animation starts
    override open func labelWillBeginScroll() {
        // This only makes sense for leftRight and rightLeft types
        if type == .leftRight || type == .rightLeft {
            // Calculate "away" position time after scroll start
            let awayTime = animationDelay + animationDuration
            // Schedule a timer to restart the label when it hits the "away" position
            Timer.scheduledTimer(timeInterval: TimeInterval(awayTime), target: self, selector: #selector(restartLabel), userInfo: nil, repeats: false)
        }
    }
}
