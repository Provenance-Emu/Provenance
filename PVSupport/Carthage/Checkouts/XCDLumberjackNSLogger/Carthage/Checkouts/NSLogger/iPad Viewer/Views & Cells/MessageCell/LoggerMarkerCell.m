/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 2010-2014 Florent Pillet,
 * Copyright (c) 2012-2014 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
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

NSString * const kMarkerCellReuseID = @"markerCell";
extern UIFont *displayDefaultFont;
extern UIFont *displayTagAndLevelFont;
extern UIFont *displayMonospacedFont;

@implementation LoggerMarkerCell

-(id)initWithPreConfig
{
	return
		[self
		 initWithStyle:UITableViewCellStyleDefault
		 reuseIdentifier:kMarkerCellReuseID];
}


-(void)setupForIndexpath:(NSIndexPath *)anIndexPath
			 messageData:(LoggerMessageData *)aMessageData
{
	self.messageData = aMessageData;
	self.imageData = nil;
	
	
	[self setNeedsDisplay];
}

- (void)drawMessageView:(CGRect)cellFrame
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	BOOL highlighted = NO;
	
	UIColor *separatorColor =
		[UIColor
		 colorWithRed:(162.0f / 255.0f)
		 green:(174.0f / 255.0f)
		 blue:(10.0f / 255.0f)
		 alpha:1.f];
	
	if (!highlighted)
	{
		UIColor *backgroundColor =
			[UIColor
			 colorWithRed:1.f
			 green:1.f
			 blue:(197.0f / 255.0f)
			 alpha:1.f];
		
		[backgroundColor set];
		CGContextFillRect(context, cellFrame);
	}
	
	CGContextSetShouldAntialias(context, false);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSetLineCap(context, kCGLineCapSquare);
	CGContextSetStrokeColorWithColor(context, separatorColor.CGColor);

	CGContextBeginPath(context);
	CGContextMoveToPoint(context, CGRectGetMinX(cellFrame), floorf(CGRectGetMinY(cellFrame)));
	CGContextAddLineToPoint(context, floorf(CGRectGetMaxX(cellFrame)), floorf(CGRectGetMinY(cellFrame)));
	CGContextMoveToPoint(context, CGRectGetMinX(cellFrame), floorf(CGRectGetMaxY(cellFrame)));
	CGContextAddLineToPoint(context, CGRectGetMaxX(cellFrame), floorf(CGRectGetMaxY(cellFrame)));
	CGContextStrokePath(context);
	CGContextSetShouldAntialias(context, true);
	
	// Draw client info
	CGRect r = CGRectMake(CGRectGetMinX(cellFrame) + MSG_CELL_LEFT_PADDING,
						  CGRectGetMinY(cellFrame) + MSG_CELL_TOP_PADDING,
						  CGRectGetWidth(cellFrame) - MSG_CELL_LATERAL_PADDING,
						  CGRectGetHeight(cellFrame) - MSG_CELL_VERTICAL_PADDING);
	
	
	// set black color for text
	[[UIColor blackColor] set];
	
	[[self.messageData textRepresentation]
	 drawInRect:r
	 withFont:displayMonospacedFont
	 lineBreakMode:NSLineBreakByWordWrapping
	 alignment:NSTextAlignmentCenter];
}

@end
