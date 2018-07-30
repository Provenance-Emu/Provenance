//
//  MarqueeLabelDemoPushController.swift
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/26/16.
//
//

import UIKit

class MarqueeLabelDemoPushController: UIViewController {
    @IBOutlet weak var demoLabel: MarqueeLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        demoLabel.type = .continuous
        demoLabel.speed = .duration(15)
        demoLabel.animationCurve = .easeInOut
        demoLabel.fadeLength = 10.0
        demoLabel.leadingBuffer = 30.0
        
        let strings = ["When shall we three meet again in thunder, lightning, or in rain? When the hurlyburly's done, When the battle 's lost and won.",
                       "I have no spur to prick the sides of my intent, but only vaulting ambition, which o'erleaps itself, and falls on the other.",
                       "Double, double toil and trouble; Fire burn, and cauldron bubble.",
                       "By the pricking of my thumbs, Something wicked this way comes.",
                       "My favorite things in life don't cost any money. It's really clear that the most precious resource we all have is time.",
                       "Be a yardstick of quality. Some people aren't used to an environment where excellence is expected."]
        
        demoLabel.text = strings[Int(arc4random_uniform(UInt32(strings.count)))]
    }
}
