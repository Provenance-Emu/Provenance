#pragma once
#import "PVPPSSPPCore.h"
#import <UIKit/UIKit.h>

// Swift owns the render controllers and imports the bridge. Runtime lookup avoids
// a reverse dependency from the ObjC++ target to that Swift module.
@interface UIViewController (PPSSPPSwiftRenderController)
- (instancetype)initWithResFactor:(int8_t)resFactor
                       videoWidth:(CGFloat)videoWidth
                      videoHeight:(CGFloat)videoHeight
                             core:(PVPPSSPPCoreBridge *)core;
@end

typedef UIViewController PPSSPPVulkanViewController;
typedef UIViewController PPSSPPOGLViewController;
#define PV_PPSSPP_SWIFT_CLASS(name) NSClassFromString(@"PVPPSSPP." #name)
