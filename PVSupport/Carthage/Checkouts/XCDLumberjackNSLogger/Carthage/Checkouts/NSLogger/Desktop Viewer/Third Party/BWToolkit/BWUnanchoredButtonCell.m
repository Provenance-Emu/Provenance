//
//  BWUnanchoredButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWUnanchoredButtonCell.h"
#import "BWUnanchoredButton.h"
#import "NSColor+BWAdditions.h"

static NSColor *fillStop1, *fillStop2, *fillStop3, *fillStop4;
static NSColor *borderColor, *topBorderColor, *bottomInsetColor, *topInsetColor, *pressedColor;
static NSGradient *fillGradient;

@implementation BWUnanchoredButtonCell

+ (void)initialize;
{
    fillStop1			= [[NSColor colorWithCalibratedWhite:(251.0f / 255.0f) alpha:1] retain];
    fillStop2			= [[NSColor colorWithCalibratedWhite:(251.0f / 255.0f) alpha:1] retain];
    fillStop3			= [[NSColor colorWithCalibratedWhite:(236.0f / 255.0f) alpha:1] retain];
	fillStop4			= [[NSColor colorWithCalibratedWhite:(243.0f / 255.0f) alpha:1] retain];
	
    fillGradient		= [[NSGradient alloc] initWithColorsAndLocations:
						   fillStop1, (CGFloat)0.0,
						   fillStop2, (CGFloat)0.5,
						   fillStop3, (CGFloat)0.5,
						   fillStop4, (CGFloat)1.0,
						   nil];
	
	topBorderColor		= [[NSColor colorWithCalibratedWhite:(126.0f / 255.0f) alpha:1] retain];
	borderColor			= [[NSColor colorWithCalibratedWhite:(151.0f / 255.0f) alpha:1] retain];
	
	topInsetColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.08] retain];
	bottomInsetColor	= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.54] retain];
	
	pressedColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.3] retain];
}

- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[fillGradient drawInRect:NSInsetRect(cellFrame, 0, 2) angle:90];
	
	[topInsetColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];	
	[topBorderColor bwDrawPixelThickLineAtPosition:1 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
	[borderColor bwDrawPixelThickLineAtPosition:1 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	[bottomInsetColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	
	[borderColor bwDrawPixelThickLineAtPosition:0 withInset:2 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	[borderColor bwDrawPixelThickLineAtPosition:0 withInset:2 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
}

- (NSRect)highlightRectForBounds:(NSRect)bounds
{
	return NSInsetRect(bounds, 0, 1);
}

@end
