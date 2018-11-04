//
//  BWAnchoredButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAnchoredButtonCell.h"
#import "BWAnchoredButtonBar.h"
#import "BWAnchoredButton.h"
#import "NSColor+BWAdditions.h"
#import "NSImage+BWAdditions.h"

static NSColor *fillStop1, *fillStop2, *fillStop3, *fillStop4;
static NSColor *topBorderColor, *bottomBorderColor, *sideBorderColor, *sideInsetColor, *pressedColor;
static NSColor *enabledTextColor, *disabledTextColor, *enabledImageColor, *disabledImageColor;
static NSColor *borderedSideBorderColor, *borderedTopBorderColor;
static NSGradient *fillGradient;
static NSShadow *contentShadow;

@interface NSCell (BWABCPrivate)
- (NSDictionary *)_textAttributes;
@end

@interface BWAnchoredButtonCell (BWABCPrivate)
- (NSColor *)textColor;
- (NSColor *)imageColor;
- (NSRect)highlightRectForBounds:(NSRect)cellFrame;
@end

@implementation BWAnchoredButtonCell

+ (void)initialize;
{
    fillStop1			= [[NSColor colorWithCalibratedWhite:(253.0f / 255.0f) alpha:1] retain];
    fillStop2			= [[NSColor colorWithCalibratedWhite:(242.0f / 255.0f) alpha:1] retain];
    fillStop3			= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	fillStop4			= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	
    fillGradient		= [[NSGradient alloc] initWithColorsAndLocations:
						   fillStop1, (CGFloat)0.0,
						   fillStop2, (CGFloat)0.45454,
						   fillStop3, (CGFloat)0.45454,
						   fillStop4, (CGFloat)1.0,
						   nil];
	
	topBorderColor		= [[NSColor colorWithCalibratedWhite:(202.0f / 255.0f) alpha:1] retain];
	bottomBorderColor	= [[NSColor colorWithCalibratedWhite:(170.0f / 255.0f) alpha:1] retain];
	sideBorderColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.2] retain];
	sideInsetColor		= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.5] retain];
	
	pressedColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.35] retain];
	
	enabledTextColor	= [[NSColor colorWithCalibratedWhite:(10.0f / 255.0f) alpha:1] retain];
	disabledTextColor	= [[enabledTextColor colorWithAlphaComponent:0.6] retain];
	
	enabledImageColor	= [[NSColor colorWithCalibratedWhite:(72.0f / 255.0f) alpha:1] retain];
	disabledImageColor	= [[enabledImageColor colorWithAlphaComponent:0.6] retain];
	
	borderedSideBorderColor	= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.25] retain];
	borderedTopBorderColor	= [[NSColor colorWithCalibratedWhite:(190.0f / 255.0f) alpha:1] retain];

	contentShadow = [[NSShadow alloc] init];
	[contentShadow setShadowOffset:NSMakeSize(0,-1)];
	[contentShadow setShadowColor:[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.75]];
}

- (NSControlSize)controlSize
{
	return NSSmallControlSize;
}

- (void)setControlSize:(NSControlSize)size
{
	
}

#pragma mark Draw Bezel

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[super drawWithFrame:cellFrame inView:controlView];

	// @fpillet: added checks for showState and state if NSOnState should highlight
	if ([self isHighlighted] || ([self showsStateBy] && [self state] != NSOffState))
	{
		[pressedColor set];
		NSRectFillUsingOperation([self highlightRectForBounds:cellFrame], NSCompositeSourceOver);
	}
}

- (NSRect)highlightRectForBounds:(NSRect)bounds
{
	return bounds;
}

- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	BOOL inBorderedBar = YES;
	
	if ([[[self controlView] superview] respondsToSelector:@selector(isAtBottom)])
	{
		if ([(BWAnchoredButtonBar *)[[self controlView] superview] isAtBottom])
			inBorderedBar = NO;			
	}
	
	[fillGradient drawInRect:cellFrame angle:90];
	
	[bottomBorderColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	[sideInsetColor bwDrawPixelThickLineAtPosition:1 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
	[sideInsetColor bwDrawPixelThickLineAtPosition:1 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	
	if (inBorderedBar)
	{
		[borderedTopBorderColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
		[borderedSideBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		[borderedSideBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
	else
	{
		[topBorderColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
		[sideBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		[sideBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}

	if (inBorderedBar && [[self controlView] respondsToSelector:@selector(isAtLeftEdgeOfBar)])
	{
		if ([(BWAnchoredButton *)[self controlView] isAtLeftEdgeOfBar])
			[bottomBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		if ([(BWAnchoredButton *)[self controlView] isAtRightEdgeOfBar])
			[bottomBorderColor bwDrawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
}

#pragma mark Draw Title

- (NSColor *)textColor
{
	return [self isEnabled] ? enabledTextColor : disabledTextColor;
}

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	[attributes setObject:[self textColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
	[attributes setObject:contentShadow forKey:NSShadowAttributeName];
	
	return attributes;
}

- (NSRect)titleRectForBounds:(NSRect)bounds
{
	return NSOffsetRect([super titleRectForBounds:bounds], 0, 1);
}

#pragma mark Draw Image

- (NSColor *)imageColor
{
	return [self isEnabled] ? enabledImageColor : disabledImageColor;
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{	
	if ([[image name] isEqualToString:@"NSActionTemplate"])
		[image setSize:NSMakeSize(10,10)];
	
	NSImage *newImage = image;
	
	// Only tint if the image is a template and shouldn't be rendered as a blue active state
	if ([image isTemplate] && !([self showsStateBy] == NSContentsCellMask && [self intValue] == 1))
	{
		newImage = [image bwTintedImageWithColor:[self imageColor]];
		[newImage setTemplate:NO];

		[contentShadow set];
	}

	[super drawImage:newImage withFrame:NSOffsetRect(frame, 0, 1) inView:controlView];
}

@end
