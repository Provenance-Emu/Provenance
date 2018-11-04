//
//  NSImage+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSImage+BWAdditions.h"

@implementation NSImage (BWAdditions)

// Draw a solid color over an image - taking into account alpha. Useful for coloring template images.

- (NSImage *)bwTintedImageWithColor:(NSColor *)tint 
{
	NSSize size = [self size];
	NSRect imageBounds = NSMakeRect(0, 0, size.width, size.height);    
	
	NSImage *copiedImage = [self copy];
	
	[copiedImage lockFocus];
	
	[tint set];
	NSRectFillUsingOperation(imageBounds, NSCompositeSourceAtop);
	
	[copiedImage unlockFocus];  
	
	return [copiedImage autorelease];
}

@end
