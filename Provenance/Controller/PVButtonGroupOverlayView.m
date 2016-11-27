//
//  PVButtonOverlayView.m
//  Provenance
//
//  Created by James Addyman on 17/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVButtonGroupOverlayView.h"
#import "JSButton.h"

@interface PVButtonGroupOverlayView ()

@property (nonatomic, strong) NSArray *buttons;

@end

@implementation PVButtonGroupOverlayView

- (id)initWithButtons:(NSArray *)buttons
{
	if ((self = [super initWithFrame:CGRectZero]))
	{
#if !TARGET_OS_TV
		[self setMultipleTouchEnabled:YES];
#endif
		[self setBackgroundColor:[UIColor clearColor]];
		self.buttons = buttons;
	}
	
	return self;
}

- (void)dealloc
{
	self.buttons = nil;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
	[super willMoveToSuperview:newSuperview];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];
	
	for (JSButton *button in [self buttons])
	{
        CGRect touchArea = CGRectMake(location.x - 10, location.y - 10, 20, 20);
        CGRect buttonFrame = [self convertRect:[button frame] toView:self];
        if (CGRectIntersectsRect(touchArea, buttonFrame))
//		if (CGRectContainsPoint([button frame], location))
		{
			[button touchesBegan:touches withEvent:event];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];
	
	for (JSButton *button in [self buttons])
	{
        CGRect touchArea = CGRectMake(location.x - 10, location.y - 10, 20, 20);
        CGRect buttonFrame = [self convertRect:[button frame] toView:self];
        if (CGRectIntersectsRect(touchArea, buttonFrame))
//		if (CGRectContainsPoint([button frame], location))
		{
			[button touchesMoved:touches withEvent:event];
		}
		else if (button.pressed)
		{
			[button touchesEnded:touches withEvent:event];
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (JSButton *button in [self buttons])
	{
		[button touchesCancelled:touches withEvent:event];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (JSButton *button in [self buttons])
	{
		[button touchesEnded:touches withEvent:event];
	}
}

@end
