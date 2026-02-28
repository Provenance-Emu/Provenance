//
//  GCController+PVShareButton.h
//  PVCoreObjCBridge
//
//  Shared utility for detecting the Share/Create/Capture button across
//  different controller types (DualSense, DualShock, Xbox, Switch Pro).
//
//  Usage:
//    #import <PVCoreObjCBridge/GCController+PVShareButton.h>
//    GCControllerButtonInput *btn = PVShareLikeButtonForController(controller);
//
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

#pragma once

#ifdef __OBJC__
#import <GameController/GameController.h>

/// Returns the Share/Create/Capture button for any supported controller,
/// using the physical input profile button name lookup.
///
/// - DualSense: "Button Create"
/// - DualShock 4: "Button Share"
/// - Switch Pro: "Button Capture"
/// - Xbox (older firmware): "Button Share" via physical profile
///
/// For Xbox controllers on newer firmware, prefer @c GCXboxGamepad.buttonShare
/// directly, as it is typed and always correct.
///
/// @param controller The GCController to query. May be nil.
/// @return The first matching button input, or nil if none found.
NS_INLINE GCControllerButtonInput * _Nullable
PVShareLikeButtonForController(GCController * _Nullable controller) {
    if (!controller) { return nil; }
    NSDictionary<NSString *, GCControllerButtonInput *> *profileButtons =
        controller.physicalInputProfile.buttons;
    if (![profileButtons isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    GCControllerButtonInput *button = profileButtons[@"Button Share"];
    if (!button) { button = profileButtons[@"Button Create"]; }
    if (!button) { button = profileButtons[@"Button Capture"]; }
    return button;
}

#endif /* __OBJC__ */
