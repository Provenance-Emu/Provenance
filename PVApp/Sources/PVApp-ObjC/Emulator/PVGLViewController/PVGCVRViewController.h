//
//  PVGCVRViewController.h
//  VirtualBoyVR-iOS
//
//  Created by Tom Kidd on 9/3/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

// TODO: Use newer SDK
// https://developers.google.com/cardboard/develop/ios/quickstart
#import "GVRCardboardView.h"

@class PVEmulatorCore;

@interface PVGCVRViewController : PVGPUViewController<GVRCardboardViewDelegate>

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
