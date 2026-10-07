// AppleUtils for iOS and tvOS. Upstream's apple_utils.mm is macOS-only (Cocoa);
// see PATCHES.md patch 1. AppleAuthorization is defined by upstream's
// apple_authorization.cpp, which compiles on both platforms.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "common/apple_utils.h"

namespace AppleUtils {
float GetRefreshRate() {
#if TARGET_OS_TV
    return 60.0f;
#else
    return static_cast<float>(UIScreen.mainScreen.maximumFramesPerSecond);
#endif
}
int IsLowPowerModeEnabled() {
    return NSProcessInfo.processInfo.lowPowerModeEnabled ? 1 : 0;
}
} // namespace AppleUtils
