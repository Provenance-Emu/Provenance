//
//  UIScreen+ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

public extension UIScreen
{
    var defaultControllerSkinSize: ControllerSkin.Size
    {
        let fixedBounds = self.fixedCoordinateSpace.convert(self.bounds, from: self.coordinateSpace)
        
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            switch fixedBounds.width
            {
            case (...768): return .small
            case (...834): return .medium
            default: return .large
            }
        }
        else
        {
            switch fixedBounds.width
            {
            case 320: return .small
            case 375: return .medium
            default: return .large
            }
        }
    }
}
