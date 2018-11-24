#import "UIView+AnyPromise.h"
#import "UIViewController+AnyPromise.h"

typedef NS_OPTIONS(NSInteger, PMKAnimationOptions) {
    PMKAnimationOptionsNone = 1 << 0,
    PMKAnimationOptionsAppear = 1 << 1,
    PMKAnimationOptionsDisappear = 1 << 2,
};
