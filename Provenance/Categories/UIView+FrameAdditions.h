#import <Foundation/Foundation.h>


@interface UIView (UIView_FrameAdditions)

- (void)setOrigin:(CGPoint)origin;
- (void)setOriginX:(CGFloat)originX;
- (void)setOriginY:(CGFloat)originY;

- (void)setSize:(CGSize)size;
- (void)setHeight:(CGFloat)height;
- (void)setWidth:(CGFloat)width;

@end

#if TARGET_OS_IOS
// UIAppearance in workaround for iOS 8
// https://stackoverflow.com/questions/24136874/appearancewhencontainedin-in-swift
// UIAppearance+Swift.h
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface UIView (UIViewAppearance_Swift)
// appearanceWhenContainedIn: is not available in Swift. This fixes that.
+ (instancetype)my_appearanceWhenContainedIn:(Class<UIAppearanceContainer>)containerClass;
@end
NS_ASSUME_NONNULL_END
#endif
