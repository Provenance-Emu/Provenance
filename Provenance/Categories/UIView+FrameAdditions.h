#import <Foundation/Foundation.h>


@interface UIView (UIView_FrameAdditions)

- (void)setOrigin:(CGPoint)origin;
- (void)setOriginX:(CGFloat)originX;
- (void)setOriginY:(CGFloat)originY;

- (void)setSize:(CGSize)size;
- (void)setHeight:(CGFloat)height;
- (void)setWidth:(CGFloat)width;

@end
