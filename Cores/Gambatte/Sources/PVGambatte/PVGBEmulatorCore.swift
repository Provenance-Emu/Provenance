//
//  PVGBEmulatorCore.swift
//  PVGB
//
//  Created by Joseph Mattiello on 6/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore

@objc
@objcMembers
public class PVGBEmulatorCore: PVEmulatorCore, ObjCBridgedCore, @unchecked Sendable {
    
    // PVEmulatorCoreBridged
    public typealias Bridge = PVGBEmulatorCoreBridge
    public lazy var bridge: Bridge = {
        let core = PVGBEmulatorCoreBridge()
        return core
    }()
    
    //@interface PVGBEmulatorCore()
    //-(NSInteger)currentDisplayMode;
    //-(void)changeDisplayMode:(NSInteger)displayMode;
    //@property (nonatomic, readonly) BOOL isGameboyColor;
    //@end
    public var displayMode: GBPalette = .default
    public var isGameboyColor: Bool = false

//    @objc
//    public var videoBuffer: [UInt32]?
//    @objc
//    public var inSoundBuffer: [UInt32]? = nil
//    @objc
//    public var outSoundBuffer: [Int16]? = nil
}

extension PVGBEmulatorCore: CoreActions {
    public var coreActions: [CoreAction]? {
        if !isGameboyColor {
            return [CoreAction(title: "Change Palette", options: nil)]
        } else {
            return nil
        }
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case "Change Palette":
            let nextI = displayMode.rawValue + 1
            let next = GBPalette(rawValue: nextI) ?? .default
            displayMode = next
        default:
            print("Unknown action: " + action.title)
        }
    }
}
