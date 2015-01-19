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
		[self setMultipleTouchEnabled:YES];
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
	CGPoint location = [touch locationInView:[self superview]];
	
	for (JSButton *button in [self buttons])
	{
		if (CGRectContainsPoint([button frame], location))
		{
			[button touchesBegan:touches withEvent:event];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:[self superview]];
	
	for (JSButton *button in [self buttons])
	{
		if (CGRectContainsPoint([button frame], location))
		{
			[button touchesMoved:touches withEvent:event];
		}
		else
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
