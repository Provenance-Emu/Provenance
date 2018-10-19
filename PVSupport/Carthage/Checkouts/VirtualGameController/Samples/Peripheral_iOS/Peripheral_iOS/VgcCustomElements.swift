//
//  VgcCustomElements.swift
//  
//
//  Created by Rob Reuss on 10/11/15.
//
//

import Foundation
import VirtualGameController

///
/// Create a case for each one of your custom elements, along with a raw value in
/// the range shown below (to prevent collisions with the standard elements).

public enum CustomElementType: Int {
    
    case FiddlestickX   = 50
    case FiddlestickY   = 51
    case FiddlestickZ   = 52
    case Keyboard       = 53
    case DebugViewTap = 54
    case VibrateDevice = 56
    case Image = 57
}

///
/// Your customElements class must descend from CustomElementsSuperclass
///
open class CustomElements: CustomElementsSuperclass {

    public override init() {
        
        super.init()
        
        ///
        /// CUSTOMIZE HERE
        ///
        /// Create a constructor for each of your custom elements.  
        ///
        /// - parameter name: Human-readable name, used in logging
        /// - parameter dataType: Supported types include .Float, .String and .Int
        /// - parameter type: Unique identifier, numbered beginning with 50 to keep them out of collision with standard elements
        ///
        
        customProfileElements = [
            CustomElement(name: "Fiddlestick X", dataType: .Float, type:CustomElementType.FiddlestickX.rawValue),
            CustomElement(name: "Fiddlestick Y", dataType: .Float, type:CustomElementType.FiddlestickY.rawValue),
            CustomElement(name: "Fiddlestick Z", dataType: .Float, type:CustomElementType.FiddlestickZ.rawValue),
            CustomElement(name: "Keyboard", dataType: .String, type:CustomElementType.Keyboard.rawValue),
            CustomElement(name: "DebugView Tap", dataType: .Data, type:CustomElementType.DebugViewTap.rawValue),
        ]

    }

}


