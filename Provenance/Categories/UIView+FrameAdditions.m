#import "UIView+FrameAdditions.h"


@implementation UIView (UIView_FrameAdditions)

- (void)setOrigin:(CGPoint)origin
{
	CGRect frame = [self frame];
	frame.origin = origin;
	[self setFrame:frame];
}

- (void)setOriginX:(CGFloat)originX
{
	CGRect frame = [self frame];
	frame.origin.x = originX;
	[self setFrame:frame];
}

- (void)setOriginY:(CGFloat)originY
{
	CGRect frame = [self frame];
	frame.origin.y = originY;
	[self setFrame:frame];
}

- (void)setSize:(CGSize)size
{
	CGRect frame = [self frame];
	frame.size = size;
	[self setFrame:frame];
}

- (void)setHeight:(CGFloat)height
{
	CGRect frame = [self frame];
	frame.size.height = height;
	[self setFrame:frame];
}

- (void)setWidth:(CGFloat)width
{
	CGRect frame = [self frame];
	frame.size.width = width;
	[self setFrame:frame];
}

@end

// UIAppearance+Swift.m
#if TARGET_OS_IOS
@implementation UIView (UIViewAppearance_Swift)
+ (instancetype)my_appearanceWhenContainedIn:(Class<UIAppearanceContainer>)containerClass {
	return [self appearanceWhenContainedIn:containerClass, nil];
}
@end
#endif
