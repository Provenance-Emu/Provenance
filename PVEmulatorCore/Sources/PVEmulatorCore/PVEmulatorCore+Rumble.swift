//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
#if canImport(GameController)
import GameController
#endif
import PVLogging
import PVAudio

#warning("Finish me before app store release vc viu on Twitter would like it.")

@objc extension PVEmulatorCore: EmulatorCoreRumbleDataSource {
    open var supportsRumble: Bool { return false }
    open func rumble(player: Int) {
        
    }

    #if os(iOS)
    @objc
    @discardableResult
    public func startHaptic() -> Bool {
        return false

        //        if (!NSThread.isMainThread) {
        //            __block BOOL started = NO;
        //            dispatch_sync(dispatch_get_main_queue(), ^{
        //                started = [self startHaptic];
        //            });
        //            return started;
        //        }
        //
        //#if !TARGET_OS_OSX
        //        if (self.supportsRumble && !(self.controller1 != nil && !self.controller1.isAttachedToDevice)) {
        //            self.rumbleGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        //            [self.rumbleGenerator prepare];
        //            return YES;
        //        }
        //#endif
        //
        //        return NO;
    }

    @objc
    public func stopHaptic() {
        //#if !TARGET_OS_OSX
        //        if (!NSThread.isMainThread) {
        //            MAKEWEAK(self);
        //            dispatch_async(dispatch_get_main_queue(), ^{
        //                MAKESTRONG_RETURN_IF_NIL(self);
        //                [strongself stopHaptic];
        //            });
        //            return;
        //        }
        //        self.rumbleGenerator = nil;
        //#endif
    }
    #else
    @objc
    @discardableResult
    public func startHaptic() -> Bool { return false }
    @objc
    public func stopHaptic() { }
    #endif
}
