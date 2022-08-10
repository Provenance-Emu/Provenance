//
//  ControllerSkinTraits.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

extension ControllerSkin
{
    public enum Device: String
    {
        // Naming conventions? I treat the "P" as the capital letter, so since it's a value (not a type) I've opted to lowercase it
        case iphone
        case ipad
    }

    public enum DisplayType: String
    {
        case standard
        case edgeToEdge
        case splitView
    }

    public enum Orientation: String
    {
        case portrait
        case landscape
    }
    
    public enum Size: String
    {
        case small
        case medium
        case large
    }
    
    public struct Traits: Hashable, CustomStringConvertible
    {
        public var device: Device
        public var displayType: DisplayType
        public var orientation: Orientation
        
        /// CustomStringConvertible
        public var description: String {
            return self.device.rawValue + "-" + self.displayType.rawValue + "-" + self.orientation.rawValue
        }
        
        public init(device: Device, displayType: DisplayType, orientation: Orientation)
        {
            self.device = device
            self.displayType = displayType
            self.orientation = orientation
        }
        
        public static func defaults(for window: UIWindow) -> ControllerSkin.Traits
        {
            let device: Device
            let displayType: DisplayType
            let orientation: Orientation
            
            // Use trait collection to determine device because our container app may be containing us in an "iPhone" trait collection despite being on iPad
            // 99% of the time, won't make a difference ¯\_(ツ)_/¯
            if window.traitCollection.userInterfaceIdiom == .pad
            {
                device = .ipad
                
                if !window.bounds.equalTo(window.screen.bounds)
                {
                    displayType = .splitView
                    
                    // Use screen bounds because in split view window bounds might be portrait, but device is actually landscape (and we want landscape skin)
                    orientation = (window.screen.bounds.width > window.screen.bounds.height) ? .landscape : .portrait
                }
                else
                {
                    displayType = .standard
                    orientation = (window.bounds.width > window.bounds.height) ? .landscape : .portrait
                }
            }
            else
            {
                device = .iphone
                displayType = (window.safeAreaInsets.bottom != 0) ? .edgeToEdge : .standard
                orientation = (window.bounds.width > window.bounds.height) ? .landscape : .portrait
            }
            
            let traits = ControllerSkin.Traits(device: device, displayType: displayType, orientation: orientation)
            return traits
        }
    }
}
