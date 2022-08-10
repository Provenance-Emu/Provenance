//
//  ControllerSkinProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 10/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

public protocol ControllerSkinProtocol
{
    var name: String { get }
    var identifier: String { get }
    var gameType: GameType { get }
    var isDebugModeEnabled: Bool { get }
    
    func supports(_ traits: ControllerSkin.Traits) -> Bool
    
    func image(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    func thumbstick(for item: ControllerSkin.Item, traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> (UIImage, CGSize)?
    
    /// Provided point should be normalized [0,1] for both axies.
    func inputs(for traits: ControllerSkin.Traits, at point: CGPoint) -> [Input]?
    
    func items(for traits: ControllerSkin.Traits) -> [ControllerSkin.Item]?
    
    func isTranslucent(for traits: ControllerSkin.Traits) -> Bool?
    
    func gameScreenFrame(for traits: ControllerSkin.Traits) -> CGRect?
    func screens(for traits: ControllerSkin.Traits) -> [ControllerSkin.Screen]?
    
    func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    
    func supportedTraits(for traits: ControllerSkin.Traits) -> ControllerSkin.Traits?
}

public extension ControllerSkinProtocol
{
    func supportedTraits(for traits: ControllerSkin.Traits) -> ControllerSkin.Traits?
    {
        var traits = traits
        
        while !self.supports(traits)
        {
            guard traits.device == .iphone, traits.displayType == .edgeToEdge else { return nil }
            
            traits.displayType = .standard
        }
        
        return traits
    }
    
    func gameScreenFrame(for traits: DeltaCore.ControllerSkin.Traits) -> CGRect?
    {
        return self.screens(for: traits)?.first?.outputFrame
    }
}

public func ==(lhs: ControllerSkinProtocol?, rhs: ControllerSkinProtocol?) -> Bool
{
    return lhs?.identifier == rhs?.identifier
}

public func !=(lhs: ControllerSkinProtocol?, rhs: ControllerSkinProtocol?) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(pattern: ControllerSkinProtocol?, value: ControllerSkinProtocol?) -> Bool
{
    return pattern == value
}
