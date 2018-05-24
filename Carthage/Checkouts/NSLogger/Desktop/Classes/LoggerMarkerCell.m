/*
 * LoggerMarkerCell.h
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2017 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 * 
 */
#import "LoggerMarkerCell.h"
#import "LoggerMessage.h"

@implementation LoggerMarkerCell

+ (NSDictionary *)markAttributes:(BOOL)highlighted
{
	NSMutableDictionary *attrs = [[self defaultAttributes] objectForKey:@"mark"];
	if (highlighted)
	{
		attrs = [[attrs mutableCopy] autorelease];
		[attrs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	}
	return attrs;
}

+ (CGFloat)heightForCellWithMessage:(LoggerMessage *)aMessage threadColumnWidth:(CGFloat)threadColumWidth maxSize:(NSSize)sz showFunctionNames:(BOOL)showFunctionNames
{
	// return cached cell height if possible
	CGFloat minimumHeight = [self minimumHeightForCell];
	NSSize cellSize = aMessage.cachedCellSize;
	if (cellSize.width == sz.width)
		return cellSize.height;
	
	cellSize.width = sz.width;
	
	// new width is larger, but cell already at minimum height, don't recompute
	if (cellSize.width > 0 && cellSize.width < sz.width && cellSize.height == minimumHeight)
		return minimumHeight;
	
	sz.width -= 8;
	sz.height -= 4;
	
	NSRect lr = [aMessage.message boundingRectWithSize:sz
											   options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
											attributes:[self markAttributes:NO]];
	sz.height = fminf(NSHeight(lr), sz.height);			
	
	// cache and return cell height
	cellSize.height = fmaxf(sz.height + 4, minimumHeight);
	aMessage.cachedCellSize = cellSize;
	return cellSize.height;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.size = message.cachedCellSize;

	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	BOOL highlighted = [self isHighlighted];
	
	CGColorRef separatorColor = CGColorCreateGenericRGB(162.0f / 255.0f,
														174.0f / 255.0f,
														10.0f / 255.0f,
														1.0f);
	CGColorRef backgroundColor = CGColorCreateGenericRGB(1.0f,
														 1.0f,
														 197.0f / 255.0f,
														 1.0f);

	if (!highlighted)
	{
		CGContextSetFillColorWithColor(ctx, backgroundColor);
		CGContextFillRect(ctx, NSRectToCGRect(cellFrame));
	}
	
	CGContextSetShouldAntialias(ctx, false);
	CGContextSetLineWidth(ctx, 1.0f);
	CGContextSetLineCap(ctx, kCGLineCapSquare);
	CGContextSetStrokeColorWithColor(ctx, separatorColor);

	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, NSMinX(cellFrame), floorf(NSMinY(cellFrame)));
	CGContextAddLineToPoint(ctx, floorf(NSMaxX(cellFrame)), floorf(NSMinY(cellFrame)));
	CGContextMoveToPoint(ctx, NSMinX(cellFrame), floorf(NSMaxY(cellFrame)));
	CGContextAddLineToPoint(ctx, NSMaxX(cellFrame), floorf(NSMaxY(cellFrame)));
	CGContextStrokePath(ctx);
	CGContextSetShouldAntialias(ctx, true);
	
	CGColorRelease(separatorColor);
	CGColorRelease(backgroundColor);
	
	// If the window is not main, don't change the text color
	if (highlighted && ![[controlView window] isMainWindow])
		highlighted = NO;
	
	NSRect r = NSMakeRect(NSMinX(cellFrame) + 3,
						  NSMinY(cellFrame),
						  NSWidth(cellFrame) - 6,
						  NSHeight(cellFrame));
	
	NSDictionary *attrs = [[self class] markAttributes:highlighted];
	NSRect lr = [(NSString *)message.message boundingRectWithSize:r.size
														  options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
													   attributes:attrs];
	r.size.height = lr.size.height;
	CGFloat offset = floorf((NSHeight(cellFrame) - NSHeight(lr)) / 2.0f);
	if (offset > 0)
		r.origin.y += offset;
	[(NSString *)message.message drawWithRect:r
									  options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
								   attributes:attrs];
}

@end
