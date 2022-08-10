//
//  TouchControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/1/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

extension TouchControllerSkin
{
    public enum LayoutAxis
    {
        case vertical
        case horizontal
    }
}

public struct TouchControllerSkin
{
    public var name: String { "TouchControllerSkin" }
    public var identifier: String { "com.delta.TouchControllerSkin" }
    public var gameType: GameType { self.controllerSkin.gameType }
    public var isDebugModeEnabled: Bool { false }
    
    public var screenLayoutAxis: LayoutAxis = .vertical
    public var layoutGuide: UILayoutGuide?
    
    private let controllerSkin: ControllerSkin
    
    public init(controllerSkin: ControllerSkin)
    {
        self.controllerSkin = controllerSkin
    }
}

extension TouchControllerSkin: ControllerSkinProtocol
{
    public func supports(_ traits: ControllerSkin.Traits) -> Bool
    {
        return true
    }
    
    public func image(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    {
        return nil
    }
    
    public func thumbstick(for item: ControllerSkin.Item, traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> (UIImage, CGSize)?
    {
        return nil
    }
    
    public func inputs(for traits: ControllerSkin.Traits, at point: CGPoint) -> [Input]?
    {
        // Return empty array since touch inputs are normally filtered out.
        return []
    }
    
    public func items(for traits: ControllerSkin.Traits) -> [ControllerSkin.Item]?
    {
        guard
            let fullScreenFrame = self.fullScreenFrame(for: traits),
            var touchScreenItem = self.controllerSkin.items(for: traits)?.first(where: { $0.kind == .touchScreen })
        else { return nil }
        
        let touchScreenFrame: CGRect
        
        if let touchScreenIndex = self.controllerSkin.screens(for: traits)?.firstIndex(where: { touchScreenItem.frame.contains($0.outputFrame) }),
           let updatedScreen = self.screens(for: traits)?[touchScreenIndex]
        {
            // This (original) screen is completely covered by a touch screen input,
            // therefore we assume it's a touch screen and use its (updated) frame.
            touchScreenFrame = updatedScreen.outputFrame
        }
        else
        {
            // The touch screen (if one exists) is partially covering the main screen,
            // so calculate the intersection to determine where to place touch screen.
            
            var screenFrame = self.controllerSkin.gameScreenFrame(for: traits) ?? fullScreenFrame
            var itemFrame = touchScreenItem.frame
            
            // Align itemFrame relative to screenFrame's origin.
            itemFrame.origin.x -= screenFrame.minX
            itemFrame.origin.y -= screenFrame.minY
            screenFrame.origin = .zero
            
            var intersection = screenFrame.intersection(itemFrame)
            intersection.origin.x /= screenFrame.width
            intersection.origin.y /= screenFrame.height
            intersection.size.width /= screenFrame.width
            intersection.size.height /= screenFrame.height
            
            intersection.origin.x *= fullScreenFrame.width
            intersection.origin.y *= fullScreenFrame.height
            intersection.size.width *= fullScreenFrame.width
            intersection.size.height *= fullScreenFrame.height
            
            // Translate intersection back to correct location.
            intersection.origin.x += fullScreenFrame.minX
            intersection.origin.y += fullScreenFrame.minY
            
            touchScreenFrame = intersection
        }
        
        touchScreenItem.frame = touchScreenFrame
        touchScreenItem.extendedFrame = touchScreenFrame
        return [touchScreenItem]
    }
    
    public func isTranslucent(for traits: ControllerSkin.Traits) -> Bool?
    {
        return false
    }

    public func screens(for traits: ControllerSkin.Traits) -> [ControllerSkin.Screen]?
    {
        guard let fullScreenFrame = self.fullScreenFrame(for: traits) else { return nil }

        let screensCount = CGFloat(self.controllerSkin.screens(for: traits)?.count ?? 0)
        
        let screens = self.controllerSkin.screens(for: traits)?.enumerated().map { (index, screen) -> ControllerSkin.Screen in
            var screen = screen
            
            switch self.screenLayoutAxis
            {
            case .horizontal:
                let length = fullScreenFrame.width / screensCount
                screen.outputFrame = CGRect(x: fullScreenFrame.minX + length * CGFloat(index), y: fullScreenFrame.minY, width: length, height: fullScreenFrame.height)
                
            case .vertical:
                let length = fullScreenFrame.height / screensCount
                screen.outputFrame = CGRect(x: fullScreenFrame.minX, y: fullScreenFrame.minY + length * CGFloat(index), width: fullScreenFrame.width, height: length)
            }
            
            return screen
        }
        
        return screens
    }
    
    public func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin.aspectRatio(for: traits)
    }
}

private extension TouchControllerSkin
{
    func fullScreenFrame(for traits: ControllerSkin.Traits) -> CGRect?
    {
        // Assumes skin is a full screen skin.
        
        guard let mappingSize = self.aspectRatio(for: traits), let core = Delta.core(for: self.gameType) else { return nil }
        
        let fullScreenSize: CGSize
        
        if let screens = self.controllerSkin.screens(for: traits), let outputFrame = screens.first?.outputFrame
        {
            var size = CGSize(width: outputFrame.width * mappingSize.width, height: outputFrame.height * mappingSize.height)
            
            // Assume screens are the same size.
            switch self.screenLayoutAxis
            {
            case .horizontal: size.width *= CGFloat(screens.count)
            case .vertical: size.height *= CGFloat(screens.count)
            }
            
            fullScreenSize = size
        }
        else
        {
            fullScreenSize = core.videoFormat.dimensions
        }
        
        let layoutFrame: CGRect
        let containingSize: CGSize
        
        if let layoutGuide = self.layoutGuide, let bounds = layoutGuide.owningView?.bounds
        {
            var frame = layoutGuide.layoutFrame
            frame.size.height = bounds.height - frame.minY // HACK: Ignore bottom insets to prevent home indicator messing up calculations.
            
            layoutFrame = frame
            containingSize = bounds.size
        }
        else
        {
            layoutFrame = CGRect(origin: .zero, size: mappingSize)
            containingSize = layoutFrame.size
        }
        
        var screenFrame = AVMakeRect(aspectRatio: fullScreenSize, insideRect: layoutFrame)
        screenFrame.origin.x /= containingSize.width
        screenFrame.origin.y /= containingSize.height
        screenFrame.size.width /= containingSize.width
        screenFrame.size.height /= containingSize.height

        return screenFrame
    }
}
