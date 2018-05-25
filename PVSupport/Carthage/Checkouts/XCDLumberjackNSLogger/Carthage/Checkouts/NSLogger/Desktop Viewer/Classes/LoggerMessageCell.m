/*
 * LoggerMessageCell.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
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
#include <time.h>
#import "LoggerMessageCell.h"
#import "LoggerMessage.h"
#import "LoggerUtils.h"
#import "LoggerWindowController.h"
#import "NSColor+NSLogger.h"

#define MAX_DATA_LINES				16				// max number of data lines to show

#define MINIMUM_CELL_HEIGHT			30.0f
#define INDENTATION_TAB_WIDTH		10.0f			// in pixels

#define TIMESTAMP_COLUMN_WIDTH		85.0f

static NSMutableDictionary *sDefaultAttributes = nil;
static NSColor *sDefaultTagAndLevelColor = nil;
static CGFloat sMinimumHeightForCell = 0;
static CGFloat sDefaultFileLineFunctionHeight = 0;
static NSMutableDictionary *advancedColors = nil;

NSString * const kMessageAttributesChangedNotification = @"MessageAttributesChangedNotification";
NSString * const kMessageColumnWidthsChangedNotification = @"MessageColumnWidthsChangedNotification";

@implementation LoggerMessageCell

@synthesize message, previousMessage, messageAttributes, modifyingThreadColumnWidth;
@synthesize shouldShowFunctionNames;

// -----------------------------------------------------------------------------
// Class methods
// -----------------------------------------------------------------------------

#pragma mark -
#pragma mark Colors and text attributes

+ (NSColor *)cellStandardBgColor
{
	static NSColor *sColor = nil;
	if (sColor == nil)
		sColor = [[NSColor colorWithCalibratedWhite:0.90 alpha:1.0] retain];
	return sColor;
}

+ (NSColor *)cellSeparatorColor
{
	static NSColor *sColor = nil;
	if (sColor == nil)
		sColor = [[NSColor colorWithCalibratedWhite:0.75 alpha:1.0] retain];
	return sColor;
}

+ (NSDictionary *)defaultAttributesDictionary
{
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];

	// Preferrably use Consolas, but revert to other fonts if not installed (fix by Steven Woolgar)
	NSFont *defaultFont = [NSFont fontWithName:@"Lucida Grande" size:11];
	NSFont *defaultTagAndLevelFont = [NSFont fontWithName:@"Lucida Grande Bold" size:9];
	NSFont *defaultMonospacedFont = [NSFont fontWithName:@"Consolas" size:11];
	if (defaultMonospacedFont == nil)
		defaultMonospacedFont = [NSFont fontWithName:@"Menlo" size:11];
	if (defaultMonospacedFont == nil)
		defaultMonospacedFont = [NSFont fontWithName:@"Courier" size:11];
	
	// Default text attributes
	NSMutableDictionary *dict;
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[style setLineBreakMode:NSLineBreakByTruncatingTail];
	NSMutableDictionary *textAttrs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									  defaultFont, NSFontAttributeName,
									  [NSColor blackColor], NSForegroundColorAttributeName,
									  style, NSParagraphStyleAttributeName,
									  nil];
	[style release];
	
	// Timestamp attributes
	[attrs setObject:textAttrs forKey:@"timestamp"];
	
	// Time Delta attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	[attrs setObject:dict forKey:@"timedelta"];
	[dict release];
	
	// Thread ID attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	[attrs setObject:dict forKey:@"threadID"];
	[dict release];

	// Tag and Level attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:defaultTagAndLevelFont forKey:NSFontAttributeName];
	[dict setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attrs setObject:dict forKey:@"tag"];
	[attrs setObject:dict forKey:@"level"];
	[dict release];
	
	// Text message attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:defaultMonospacedFont forKey:NSFontAttributeName];
	style = [[dict objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	[style setLineBreakMode:NSLineBreakByWordWrapping];
	[dict setObject:style forKey:NSParagraphStyleAttributeName];
	[style release];
	[attrs setObject:dict forKey:@"text"];
	[dict release];
	
	// Data message attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:defaultMonospacedFont forKey:NSFontAttributeName];
	[attrs setObject:dict forKey:@"data"];
	[dict release];
	
	// Mark attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:defaultMonospacedFont forKey:NSFontAttributeName];
	style = [[dict objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	[style setAlignment:NSCenterTextAlignment];
	[dict setObject:style forKey:NSParagraphStyleAttributeName];
	[style release];
	[attrs setObject:dict forKey:@"mark"];
	[dict release];

	// File / Line / Function name attributes
	dict = [textAttrs mutableCopy];
	[dict setObject:defaultTagAndLevelFont forKey:NSFontAttributeName];
	[dict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	NSColor *fillColor = [NSColor colorWithCalibratedRed:(239.0f / 255.0f)
												   green:(233.0f / 255.0f)
													blue:(252.0f / 255.0f)
												   alpha:1.0f];
	[dict setObject:fillColor forKey:NSBackgroundColorAttributeName];
	style = [[dict objectForKey:NSParagraphStyleAttributeName] mutableCopy];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[dict setObject:style forKey:NSParagraphStyleAttributeName];
	[style release];
	[attrs setObject:dict forKey:@"fileLineFunction"];
	[dict release];

	return attrs;
}

+ (NSDictionary *)defaultAttributes
{
	if (sDefaultAttributes == nil)
	{
		// Try to load the default text attributes from user defaults
		NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"Message Attributes"];
		if (data != nil)
			sDefaultAttributes = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
		if (sDefaultAttributes == nil)
			[self setDefaultAttributes:[self defaultAttributesDictionary]];

		// upgrade from pre-1.0b5, adding attributes for markers
		if ([sDefaultAttributes objectForKey:@"mark"] == nil)
		{
			NSMutableDictionary *attrs = [sDefaultAttributes mutableCopy];
			NSMutableDictionary *dict = [[sDefaultAttributes objectForKey:@"text"] mutableCopy];
			NSMutableParagraphStyle *style = [[dict objectForKey:NSParagraphStyleAttributeName] mutableCopy];
			[style setAlignment:NSCenterTextAlignment];
			[dict setObject:style forKey:NSParagraphStyleAttributeName];
			[style release];
			[attrs setObject:dict forKey:@"mark"];
			[dict release];
			[self setDefaultAttributes:attrs];
			[attrs release];
		}

		// update from pre-1.0b7, adding attributes for file / line / function
		if ([sDefaultAttributes objectForKey:@"fileLineFunction"] == nil)
		{
			NSMutableDictionary *attrs = [sDefaultAttributes mutableCopy];
			NSMutableDictionary *dict = [[attrs objectForKey:@"tag"] mutableCopy];
			[dict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
			NSColor *fillColor = [NSColor colorWithCalibratedRed:(239.0f / 255.0f)
														   green:(233.0f / 255.0f)
															blue:(252.0f / 255.0f)
														   alpha:1.0f];
			[dict setObject:fillColor forKey:NSBackgroundColorAttributeName];
			[attrs setObject:dict forKey:@"fileLineFunction"];
			[dict release];
			[self setDefaultAttributes:attrs];
			[attrs release];
		}
		
		// update from pre-1.0b9, setting middle truncation for file/line/function
		NSParagraphStyle *style = [[sDefaultAttributes objectForKey:@"fileLineFunction"] objectForKey:NSParagraphStyleAttributeName];
		if ([style lineBreakMode] != NSLineBreakByTruncatingMiddle)
		{
			NSMutableDictionary *attrs = [sDefaultAttributes mutableCopy];
			NSMutableDictionary *dict = [[attrs objectForKey:@"fileLineFunction"] mutableCopy];
			NSMutableParagraphStyle *style = [[dict objectForKey:NSParagraphStyleAttributeName] mutableCopy];
			[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
			[dict setObject:style forKey:NSParagraphStyleAttributeName];
			[style release];
			[attrs setObject:dict forKey:@"fileLineFunction"];
			[dict release];
			[self setDefaultAttributes:attrs];
			[attrs release];
		}
	}
	return sDefaultAttributes;
}

+ (void)setDefaultAttributes:(NSDictionary *)newAttributes
{
	[sDefaultAttributes release];
	sDefaultAttributes = [newAttributes copy];
	sMinimumHeightForCell = 0;
	sDefaultFileLineFunctionHeight = 0;
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:sDefaultAttributes] forKey:@"Message Attributes"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kMessageAttributesChangedNotification object:nil];
}

+ (NSColor *)defaultTagAndLevelColor
{
	if (sDefaultTagAndLevelColor == nil)
		sDefaultTagAndLevelColor = [[NSColor colorWithCalibratedRed:0.51f green:0.57f blue:0.79f alpha:1.0f] retain];
	return sDefaultTagAndLevelColor;
}

+ (NSColor *)colorFromHexRGB:(NSString *)colorString
{
	NSColor *result = nil;
	unsigned int colorCode = 0;
	unsigned char redByte, greenByte, blueByte;
	
    if ([colorString hasPrefix:@"#"]) {
        colorString = [colorString substringFromIndex:1];
    }
	if (nil != colorString)
	{
		NSScanner *scanner = [NSScanner scannerWithString:colorString];
		(void) [scanner scanHexInt:&colorCode];	// ignore error
	}
	redByte		= (unsigned char) (colorCode >> 16);
	greenByte	= (unsigned char) (colorCode >> 8);
	blueByte	= (unsigned char) (colorCode);	// masks off high bits
	result = [NSColor
              colorWithCalibratedRed:		(float)redByte	/ 0xff
              green:	(float)greenByte/ 0xff
              blue:	(float)blueByte	/ 0xff
              alpha:1.0];
	return result;
}

+ (void)loadAdvancedColors
{
    NSArray *advancedColorsPrefs = [[NSUserDefaults standardUserDefaults] objectForKey:@"advancedColors"];
    if (advancedColors) {
        [advancedColors release];
    }
    advancedColors = [[NSMutableDictionary alloc] initWithCapacity:[advancedColorsPrefs count]];
    NSError *error = nil;
    NSRegularExpression *regexp;
    NSColor *color;
    BOOL isBold;
    for(NSDictionary *colorSpec in advancedColorsPrefs) {
        regexp = [[NSRegularExpression alloc] initWithPattern:[colorSpec objectForKey:@"regexp"] options:NSRegularExpressionCaseInsensitive error:&error];
        if (! regexp) {
            NSLog(@"** Warning: invalid regular expression '%@': %@", [colorSpec objectForKey:@"regexp"], error);
            continue;
        }
        NSString *colorName = [[colorSpec objectForKey:@"colors"] lowercaseString];
        isBold = NO;
        if ([colorName hasPrefix:@"bold"]) {
            colorName = [[colorName componentsSeparatedByString:@" "] objectAtIndex:1];
            isBold = YES;
        }
        if ([colorName hasPrefix:@"#"]) {
            color = [self colorFromHexRGB:colorName];
        } else if ([colorName hasPrefix:@"blue"]) {
            color = [self colorFromHexRGB:@"#0047AB"];
        } else if ([colorName hasPrefix:@"red"]) {
            color = [self colorFromHexRGB:@"#DC143C"];
//            color = [NSColor redColor];
        } else if ([colorName hasPrefix:@"green"]) {
            color = [self colorFromHexRGB:@"#008000"];
        } else {
            NSString *selectorName = [NSString stringWithFormat:@"%@Color", colorName];
            SEL colorSelector = NSSelectorFromString(selectorName);
            if ([NSColor respondsToSelector:colorSelector]) {
                color = [NSColor performSelector:colorSelector];
            }
			else {
				color = nil;
			}
        }
        if (color == nil) {
            NSLog(@"** Warning: unexpected color spec '%@'", colorName);
        }
		else {
			color.bold = isBold;
			[advancedColors setObject:color forKey:regexp];
		}
		[regexp release];
    }
}

+ (NSColor *)colorForString:(NSString *)string
{
    if (!advancedColors) {
        [self loadAdvancedColors];
    }
    NSRegularExpression *regexp;
    for(regexp in [advancedColors allKeys]) {
        NSArray* chunks = [regexp matchesInString:string options:0 range:NSMakeRange(0, [string length])];
        if ([chunks count] > 0) {
            return [advancedColors objectForKey:regexp];
        }
    }
    return nil;
}

+ (NSColor *)colorForTag:(NSString *)tag
{
    NSColor *color = [self colorForString:[NSString stringWithFormat:@"tag=%@", tag]];
    if (! color ){
        color = [self defaultTagAndLevelColor];
    }
    return color;
}

+ (NSColor *)colorForMessage:(LoggerMessage *)message
{
    return [self colorForString:message.description];
}

#pragma mark -
#pragma mark Helpers

+ (NSArray *)stringsWithData:(NSData *)data
{
	// convert NSData block to hex-ascii strings
	NSMutableArray *strings = [[NSMutableArray alloc] init];
	NSUInteger offset = 0, dataLen = [data length];
	NSString *str;
	char buffer[6+16*3+1+16+1+1];
	buffer[0] = '\0';
	const unsigned char *q = [data bytes];
	if (dataLen == 1)
		[strings addObject:NSLocalizedString(@"Raw data, 1 byte:", @"")];
	else
		[strings addObject:[NSString stringWithFormat:NSLocalizedString(@"Raw data, %u bytes:", @""), dataLen]];
	while (dataLen)
	{
		if ([strings count] == MAX_DATA_LINES)
		{
			[strings addObject:NSLocalizedString(@"Double-click to see all data...", @"")];
			break;
		}
		int i, b = sprintf(buffer,"%04x: ", (int)offset);
		for (i=0; i < 16 && i < dataLen; i++)
			sprintf(&buffer[b+3*i], "%02x ", (int)q[i]);
		for (int j=i; j < 16; j++)
			strcat(buffer, "   ");
		
		b = strlen(buffer);
		buffer[b++] = '\'';
		for (i=0; i < 16 && i < dataLen; i++, q++)
		{
			if (*q >= 32 && *q < 128)
				buffer[b++] = *q;
			else
				buffer[b++] = ' ';
		}
		for (int j=i; j < 16; j++)
			buffer[b++] = ' ';
		buffer[b++] = '\'';
		buffer[b] = 0;
		
		str = [[NSString alloc] initWithBytes:buffer length:strlen(buffer) encoding:NSISOLatin1StringEncoding];
		[strings addObject:str];
		[str release];
		
		dataLen -= i;
		offset += i;
	}
	return [strings autorelease];
}

#pragma mark -
#pragma mark Cell size calculations

+ (CGFloat)minimumHeightForCell
{
	if (sMinimumHeightForCell == 0)
	{
		NSRect r1 = [@"10:10:10.256" boundingRectWithSize:NSMakeSize(1024, 1024)
												  options:NSStringDrawingUsesLineFragmentOrigin
											   attributes:[[self defaultAttributes] objectForKey:@"timestamp"]];
		NSRect r2 = [@"+999ms" boundingRectWithSize:NSMakeSize(1024, 1024)
											options:NSStringDrawingUsesLineFragmentOrigin
										 attributes:[[self defaultAttributes] objectForKey:@"timedelta"]];
		NSRect r3 = [@"Main Thread" boundingRectWithSize:NSMakeSize(1024, 1024)
												 options:NSStringDrawingUsesLineFragmentOrigin
											  attributes:[[self defaultAttributes] objectForKey:@"threadID"]];
		NSRect r4 = [@"qWTy" boundingRectWithSize:NSMakeSize(1024, 1024)
										  options:NSStringDrawingUsesLineFragmentOrigin
									   attributes:[[self defaultAttributes] objectForKey:@"tag"]];
		sMinimumHeightForCell = fmaxf(NSHeight(r1) + NSHeight(r2), NSHeight(r3) + NSHeight(r4)) + 4;
	}
	return sMinimumHeightForCell;
}

+ (CGFloat)heightForFileLineFunction
{
	if (sDefaultFileLineFunctionHeight == 0)
	{
		NSRect r = [@"file:100 funcQyTg" boundingRectWithSize:NSMakeSize(1024, 1024)
													  options:NSStringDrawingUsesLineFragmentOrigin
												   attributes:[[self defaultAttributes] objectForKey:@"fileLineFunction"]];
		sDefaultFileLineFunctionHeight = NSHeight(r) + 6;
	}
	return sDefaultFileLineFunctionHeight;
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

	sz.width -= TIMESTAMP_COLUMN_WIDTH + threadColumWidth + 8;
	sz.height -= 4;

	switch (aMessage.contentsType)
	{
		case kMessageString: {
			// restrict message length for very long contents
			NSString *s = aMessage.message;
			if ([s length] > 2048)
				s = [s substringToIndex:2048];

			NSRect lr = [s boundingRectWithSize:sz
										options:(NSStringDrawingOneShot | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
									 attributes:[[self defaultAttributes] objectForKey:@"text"]];
			sz.height = fminf(NSHeight(lr), sz.height);
			break;
		}

		case kMessageData: {
			NSUInteger numBytes = [(NSData *)aMessage.message length];
			int nLines = (numBytes >> 4) + ((numBytes & 15) ? 1 : 0) + 1;
			if (nLines > MAX_DATA_LINES)
				nLines = MAX_DATA_LINES + 1;
			NSRect lr = [@"000:" boundingRectWithSize:sz
											  options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
										   attributes:[[self defaultAttributes] objectForKey:@"data"]];
			sz.height = NSHeight(lr) * nLines;
			break;
		}
			
		case kMessageImage: {
			// approximate, compute ratio then refine height
			NSSize imgSize = aMessage.imageSize;
			CGFloat ratio = fmaxf(1.0f, fmaxf(imgSize.width / sz.width, imgSize.height / (sz.height / 2.0f)));
			sz.height = ceilf(imgSize.height / ratio);
			break;
		}
		default:
			break;
	}

	// If there is file / line / function information, add its height
	if (showFunctionNames && ([aMessage.filename length] || [aMessage.functionName length]))
		sz.height += [self heightForFileLineFunction];
	
	// cache and return cell height
	cellSize.height = fmaxf(sz.height + 6, minimumHeight);
	aMessage.cachedCellSize = cellSize;
	return cellSize.height;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Instance methods
// -----------------------------------------------------------------------------

- (id)copyWithZone:(NSZone *)zone
{
	LoggerMessageCell *c = [super copyWithZone:zone];
	c->message = [message retain];
	c->previousMessage = [previousMessage retain];
	c->messageAttributes = [messageAttributes retain];
	return c;
}

- (void)dealloc
{
	[message release];
	[previousMessage release];
	[messageAttributes release];
	[super dealloc];
}

- (NSMutableDictionary *)timestampAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"timestamp"];
	return [messageAttributes objectForKey:@"timestamp"];
}

- (NSMutableDictionary *)timedeltaAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"timedelta"];
	return [messageAttributes objectForKey:@"timedelta"];
}

- (NSMutableDictionary *)threadIDAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"threadID"];
	return [messageAttributes objectForKey:@"threadID"];
}

- (NSMutableDictionary *)tagAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"tag"];
	return [messageAttributes objectForKey:@"tag"];	
}

- (NSMutableDictionary *)levelAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"level"];
	return [messageAttributes objectForKey:@"level"];
}

- (NSMutableDictionary *)messageTextAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"text"];
	return [messageAttributes objectForKey:@"text"];
}

- (NSMutableDictionary *)messageDataAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"data"];
	return [messageAttributes objectForKey:@"data"];
}

- (NSMutableDictionary *)fileLineFunctionAttributes
{
	if (messageAttributes == nil)
		return [[[self class] defaultAttributes] objectForKey:@"fileLineFunction"];
	return [messageAttributes objectForKey:@"fileLineFunction"];
}

#pragma mark -
#pragma mark Drawing

- (void)drawTimestampAndDeltaInRect:(NSRect)r highlightedTextColor:(NSColor *)highlightedTextColor
{
	// Draw timestamp and time delta column
	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, NSRectToCGRect(r));
	NSRect tr = NSInsetRect(r, 2, 0);
	
	// Prepare time delta between this message and the previous displayed (filtered) message
	struct timeval tv = message.timestamp;
	struct timeval td;
	if (previousMessage != nil)
		[message computeTimeDelta:&td since:previousMessage];
	
	time_t sec = tv.tv_sec;
	struct tm *t = localtime(&sec);
	NSString *timestampStr;
	if (tv.tv_usec == 0)
		timestampStr = [NSString stringWithFormat:@"%02d:%02d:%02d", t->tm_hour, t->tm_min, t->tm_sec];
	else
		timestampStr = [NSString stringWithFormat:@"%02d:%02d:%02d.%03d", t->tm_hour, t->tm_min, t->tm_sec, tv.tv_usec / 1000];
	
	NSString *timeDeltaStr = nil;
	if (previousMessage != nil)
		timeDeltaStr = StringWithTimeDelta(&td);
	
	NSMutableDictionary *attrs = [self timestampAttributes];
	NSRect bounds = [timestampStr boundingRectWithSize:tr.size
											   options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
											attributes:attrs];
	NSRect timeRect = NSMakeRect(NSMinX(tr), NSMinY(tr), NSWidth(tr), NSHeight(bounds));
	NSRect deltaRect = NSMakeRect(NSMinX(tr), NSMaxY(timeRect)+1, NSWidth(tr), NSHeight(tr) - NSHeight(bounds) - 1);
	
	if (highlightedTextColor)
	{
		attrs = [[attrs mutableCopy] autorelease];
		[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
	}
	[timestampStr drawWithRect:timeRect
					   options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
					attributes:attrs];
	
	attrs = [self timedeltaAttributes];
	if (highlightedTextColor)
	{
		attrs = [[attrs mutableCopy] autorelease];
		[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
	}
	[timeDeltaStr drawWithRect:deltaRect
					   options:NSStringDrawingUsesLineFragmentOrigin
					attributes:attrs];
	CGContextRestoreGState(ctx);	
}

- (void)drawThreadIDAndTagInRect:(NSRect)drawRect highlightedTextColor:(NSColor *)highlightedTextColor
{
	NSRect r = drawRect;

	// Draw thread ID
	NSMutableDictionary *attrs = [self threadIDAttributes];
	if (highlightedTextColor != nil)
	{
		attrs = [[attrs mutableCopy] autorelease];
		[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
	}
	
	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, NSRectToCGRect(r));
	r.size.height = [message.threadID boundingRectWithSize:r.size
												   options:NSStringDrawingUsesLineFragmentOrigin
												attributes:attrs].size.height;
	[message.threadID drawWithRect:NSInsetRect(r, 3, 0)
						   options:NSStringDrawingUsesLineFragmentOrigin
						attributes:attrs];

	// Draw tag and level, if provided
	NSString *tag = message.tag;
	int level = message.level;
	if ([tag length] || level)
	{
		LoggerWindowController *wc = [[[self controlView] window] windowController];
		CGFloat threadColumnWidth = ([wc isKindOfClass:[LoggerWindowController class]]) ? wc.threadColumnWidth : DEFAULT_THREAD_COLUMN_WIDTH;
		NSSize tagSize = NSZeroSize;
		NSSize levelSize = NSZeroSize;
		NSString *levelString = nil;
		r.origin.y += NSHeight(r);
		if ([tag length])
		{
			tagSize = [tag boundingRectWithSize:NSMakeSize(threadColumnWidth, NSHeight(drawRect) - NSHeight(r))
										options:NSStringDrawingUsesLineFragmentOrigin
									 attributes:[self tagAttributes]].size;
			tagSize.width += 4;
			tagSize.height += 2;
		}
		if (level)
		{
			levelString = [NSString stringWithFormat:@"%d", level];
            
			levelSize = [levelString boundingRectWithSize:NSMakeSize(threadColumnWidth, NSHeight(drawRect) - NSHeight(r))
												  options:NSStringDrawingUsesLineFragmentOrigin
											   attributes:[self levelAttributes]].size;
			levelSize.width += 4;
			levelSize.height += 2;
		}
		CGFloat h = fmaxf(tagSize.height, levelSize.height);
		NSRect tagRect = NSMakeRect(NSMinX(r) + 3,
									NSMinY(r),
									tagSize.width,
									h);
		NSRect levelRect = NSMakeRect(NSMaxX(tagRect),
									  NSMinY(tagRect),
									  levelSize.width,
									  h);
		NSRect tagAndLevelRect = NSUnionRect(tagRect, levelRect);
		
		MakeRoundedPath(ctx, NSRectToCGRect(tagAndLevelRect), 3.0f);
		CGColorRef fillColor = CreateCGColorFromNSColor([[self class] colorForTag:tag]);
		CGContextSetFillColorWithColor(ctx, fillColor);
		CGColorRelease(fillColor);
		CGContextFillPath(ctx);
		if (levelSize.width)
		{
			CGColorRef black = CGColorCreateGenericGray(0.25f, 1.0f);
			CGContextSetFillColorWithColor(ctx, black);
			CGColorRelease(black);
			CGContextSaveGState(ctx);
			CGContextClipToRect(ctx, NSRectToCGRect(levelRect));
			MakeRoundedPath(ctx, NSRectToCGRect(tagAndLevelRect), 3.0f);
			CGContextFillPath(ctx);
			CGContextRestoreGState(ctx);
		}
		
		if (tagSize.width)
		{
			[tag drawWithRect:NSInsetRect(tagRect, 2, 1)
					  options:NSStringDrawingUsesLineFragmentOrigin
				   attributes:[self tagAttributes]];
		}
		if (levelSize.width)
		{
			[levelString drawWithRect:NSInsetRect(levelRect, 2, 1)
							  options:NSStringDrawingUsesLineFragmentOrigin
						   attributes:[self levelAttributes]];
		}
	}
	CGContextRestoreGState(ctx);	
}

- (void)drawMessageInRect:(NSRect)r highlightedTextColor:(NSColor *)highlightedTextColor
{
	/*
	 * Draw the message portion of cells
	 *
	 */
	NSMutableDictionary *attrs;

	if (message.contentsType == kMessageString)
	{
		attrs = [self messageTextAttributes];
		// in case the message text is empty, use the function name as message text
		// this is typically used to record a waypoint in the code flow
		NSString *s = message.message;
		if (![s length] && message.functionName)
			s = message.functionName;
		
		// very long messages can't be displayed entirely. No need to compute their full size,
		// it slows down the UI to no avail. Just cut the string to a reasonable size, and take
		// the calculations from here.
		BOOL truncated = NO;
		if ([s length] > 2048)
		{
			truncated = YES;
			s = [s substringToIndex:2048];
		}
        
		if (highlightedTextColor != nil)
		{
			attrs = [[attrs mutableCopy] autorelease];
			[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
		} else {
            NSColor *color = [[self class] colorForMessage:self.message];
            if (color) {
                attrs = [[attrs mutableCopy] autorelease];
                [attrs setObject:color forKey:NSForegroundColorAttributeName];
                if (color.isBold) {
                    NSFont *font = [attrs objectForKey:NSFontAttributeName];
                    font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait];
                    [attrs setObject:font forKey:NSFontAttributeName];
                }
            }
        }
		
		// compute display string size, limit to cell height
		NSRect lr = [s boundingRectWithSize:r.size
									options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
								 attributes:attrs];
		if (NSHeight(lr) > NSHeight(r))
			truncated = YES;
		else
		{
			r.origin.y += floorf((NSHeight(r) - NSHeight(lr)) / 2.0f);
			r.size.height = NSHeight(lr);
		}
		
		CGFloat hintHeight = 0;
		NSString *hint = nil;
		NSMutableDictionary *hintAttrs = nil;
		if (truncated)
		{
			// display a hint instructing user to double-click message in order
			// to see all contents
			hintAttrs = [[attrs mutableCopy] autorelease];
			[hintAttrs setObject:[NSNumber numberWithFloat:0.20f] forKey:NSObliquenessAttributeName];
			if (highlightedTextColor == nil)
				[hintAttrs setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
            NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
            [style setAlignment:NSRightTextAlignment];
            [hintAttrs setObject:style forKey:NSParagraphStyleAttributeName];
			hint = NSLocalizedString(@"See all...", @"");
			hintHeight = [hint boundingRectWithSize:r.size
											options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
										 attributes:hintAttrs].size.height;
		}
		
		r.size.height -= hintHeight;
		[s drawWithRect:r
				options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine)
			 attributes:attrs];
		
		// Draw hint "Double click to see all text..." if needed
		if (hint != nil)
		{
			r.origin.y += NSHeight(r);
			r.size.height = hintHeight;
			[hint drawWithRect:r
					   options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
					attributes:hintAttrs];
		}
	}
	else if (message.contentsType == kMessageData)
	{
		NSArray *strings = [[self class] stringsWithData:(NSData *)message.message];
		attrs = [self messageDataAttributes];
		if (highlightedTextColor != nil)
		{
			attrs = [[attrs mutableCopy] autorelease];
			[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
		}
		CGFloat y = NSMinY(r);
		CGFloat availHeight = NSHeight(r);
		int lineIndex = 0;
		for (NSString *s in strings)
		{
			if (lineIndex == 16)
			{
				attrs = [[attrs mutableCopy] autorelease];
				[attrs setObject:[NSNumber numberWithFloat:0.20f] forKey:NSObliquenessAttributeName];
				[attrs setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
			}
			NSRect lr = [s boundingRectWithSize:r.size
										options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
									 attributes:attrs];
			[s drawWithRect:NSMakeRect(NSMinX(r),
									   y,
									   NSWidth(r),
									   NSHeight(lr))
					options:NSStringDrawingUsesLineFragmentOrigin
				 attributes:attrs];
			availHeight -= NSHeight(lr);
			if (availHeight < NSHeight(lr))
				break;
			y += NSHeight(lr);
			lineIndex++;
		}
	}
	else if (message.contentsType == kMessageImage)
	{
		// Scale the image to fit in the cell. Since we're flipped, we also must vertically flip
		// the image
		r = NSInsetRect(r, 0, 1);
		NSSize srcSize = message.imageSize;
		CGFloat ratio = fmaxf(1.0f, fmaxf(srcSize.width / NSWidth(r), srcSize.height / NSHeight(r)));
		CGSize newSize = CGSizeMake(floorf(srcSize.width / ratio), floorf(srcSize.height / ratio));
		CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, NSMinX(r), NSMinY(r) + NSHeight(r));
		CGContextScaleCTM(ctx, 1.0f, -1.0f);
		[message.image drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height)
						 fromRect:NSMakeRect(0, 0, srcSize.width, srcSize.height)
						operation:NSCompositeCopy
						 fraction:1.0f];
		CGContextRestoreGState(ctx);
	}
}

- (void)drawFileLineFunctionInRect:(NSRect)r highlightedTextColor:(NSColor *)highlightedTextColor mouseOver:(BOOL)mouseOver
{
	// @@@ TODO: mouseOver support

	NSMutableDictionary *attrs = [self fileLineFunctionAttributes];
	if (highlightedTextColor == nil)
	{
		NSColor *fillColor = [attrs objectForKey:NSBackgroundColorAttributeName];
		if (fillColor != nil)
		{
			[fillColor set];
			NSRectFill(r);
		}
	}
	NSString *s = @"";
	BOOL hasFilename = ([message.filename length] != 0);
	BOOL hasFunction = ([message.functionName length] != 0);
	if (hasFunction && hasFilename)
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:@"%@ (%@:%d)", message.functionName, [message.filename lastPathComponent], message.lineNumber];
		else
			s = [NSString stringWithFormat:@"%@ (%@)", message.functionName, [message.filename lastPathComponent]];
	}
	else if (hasFunction)
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:NSLocalizedString(@"%@ (line %d)", @""), message.functionName, message.lineNumber];
		else
			s = message.functionName;
	}
	else
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:@"%@:%d", [message.filename lastPathComponent], message.lineNumber];
		else
			s = [message.filename lastPathComponent];
	}
	if ([s length])
	{
		if (highlightedTextColor)
		{
			attrs = [[attrs mutableCopy] autorelease];
			[attrs setObject:highlightedTextColor forKey:NSForegroundColorAttributeName];
			[attrs setObject:[NSColor clearColor] forKey:NSBackgroundColorAttributeName];
		}
		[s drawWithRect:NSInsetRect(r, 4, 2)
				options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
			 attributes:attrs];
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.size = message.cachedCellSize;

	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

	BOOL highlighted = [self isHighlighted];

	NSColor *highlightedTextColor = nil;
	if (highlighted)
		highlightedTextColor = [NSColor whiteColor];

	// Draw cell background
	if (!highlighted)
	{
		CGColorRef cellBgColor = CGColorCreateGenericGray(0.97f, 1.0f);
		CGContextSetFillColorWithColor(ctx, cellBgColor);
		CGContextFillRect(ctx, NSRectToCGRect(cellFrame));
		CGColorRelease(cellBgColor);
	}

	// turn antialiasing off
	CGContextSetShouldAntialias(ctx, false);

	// Draw separators
	CGContextSetLineWidth(ctx, 1.0f);
	CGContextSetLineCap(ctx, kCGLineCapSquare);
	CGColorRef cellSeparatorColor;
	if (highlighted)
		cellSeparatorColor = CGColorCreateGenericGray(1.0f, 1.0f);
	else
		cellSeparatorColor = CGColorCreateGenericGray(0.80f, 1.0f);
	CGContextSetStrokeColorWithColor(ctx, cellSeparatorColor);
	CGColorRelease(cellSeparatorColor);
	CGContextBeginPath(ctx);

	// horizontal bottom separator
	CGContextMoveToPoint(ctx, NSMinX(cellFrame), floorf(NSMaxY(cellFrame)));
	CGContextAddLineToPoint(ctx, NSMaxX(cellFrame), floorf(NSMaxY(cellFrame)));
	
	// timestamp/thread separator
	CGContextMoveToPoint(ctx, floorf(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH), NSMinY(cellFrame));
	CGContextAddLineToPoint(ctx, floorf(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH), floorf(NSMaxY(cellFrame)-1));
	
	// thread/message separator
    LoggerWindowController *wc = [[[self controlView] window] windowController];
	CGFloat threadColumnWidth = ([wc isKindOfClass:[LoggerWindowController class]]) ? wc.threadColumnWidth : DEFAULT_THREAD_COLUMN_WIDTH;
	CGContextMoveToPoint(ctx, floorf(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth), NSMinY(cellFrame));
	CGContextAddLineToPoint(ctx, floorf(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth), floorf(NSMaxY(cellFrame)-1));
	CGContextStrokePath(ctx);
    
	// restore antialiasing
	CGContextSetShouldAntialias(ctx, true);
	
	// Draw timestamp and time delta column
	NSRect r = NSMakeRect(NSMinX(cellFrame),
						  NSMinY(cellFrame),
						  TIMESTAMP_COLUMN_WIDTH,
						  NSHeight(cellFrame));
	[self drawTimestampAndDeltaInRect:r highlightedTextColor:highlightedTextColor];

	// Draw thread ID and tag
	r = NSMakeRect(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH,
				   NSMinY(cellFrame),
				   threadColumnWidth,
				   NSHeight(cellFrame));
	[self drawThreadIDAndTagInRect:r highlightedTextColor:highlightedTextColor];
	
	// Draw message
	r = NSMakeRect(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth + 3,
				   NSMinY(cellFrame),
				   NSWidth(cellFrame) - (TIMESTAMP_COLUMN_WIDTH + threadColumnWidth) - 6,
				   NSHeight(cellFrame));
	CGFloat fileLineFunctionHeight = 0;
	if (shouldShowFunctionNames && ([message.filename length] || [message.functionName length]))
	{
		fileLineFunctionHeight = [[self class] heightForFileLineFunction];
		r.size.height -= fileLineFunctionHeight;
		r.origin.y += fileLineFunctionHeight;
	}
	[self drawMessageInRect:r highlightedTextColor:highlightedTextColor];
	
	// Draw File / Line / Function
	if (fileLineFunctionHeight)
	{
		r = NSMakeRect(NSMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth + 1,
					   NSMinY(cellFrame),
					   NSWidth(cellFrame) - (TIMESTAMP_COLUMN_WIDTH + threadColumnWidth),
					   fileLineFunctionHeight);
		[self drawFileLineFunctionInRect:r highlightedTextColor:highlightedTextColor mouseOver:NO];
	}
}

- (BOOL)isColumnResizingHotPoint:(NSPoint)mouseDownPoint inView:(NSView *)controlView
{
    // BEWARE This works since the cell origin.x is the same as the controlView (the tableview) origin.x. The startPoint is in the control view coordinates, so this is a special case.
    // converting the startPoint in the cell coordinates is not that easy!

    LoggerWindowController *wc = [[[self controlView] window] windowController];
	if (![wc isKindOfClass:[LoggerWindowController class]])
		return NO;		// we may be in the Preferences window fake log message display

    CGFloat threadColumnWidth = wc.threadColumnWidth;
    if(mouseDownPoint.x >= (0. + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth - 5.) && mouseDownPoint.x <= (0. + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth + 5.))
        return YES;

    return NO;
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    // BEWARE This works since the cell origin.x is the same as the controlView (the tableview) origin.x. The startPoint is in the control view coordinates, so this is a special case.
    // converting the startPoint in the cell coordinates is not that easy!
    
    // if clicking around the thread / message separator, then track
    if([self isColumnResizingHotPoint:startPoint inView:controlView])
    {
        [[NSCursor resizeLeftRightCursor] push];
        self.modifyingThreadColumnWidth = YES;
        return YES;
    }

    return [super startTrackingAt:startPoint inView:controlView];
}

- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
    if(self.modifyingThreadColumnWidth == YES)
    {
        LoggerWindowController *wc = [[[self controlView] window] windowController];
        CGFloat threadColumnWidth = wc.threadColumnWidth;

        CGFloat currentColWidth = threadColumnWidth;
        CGFloat difference = currentPoint.x - lastPoint.x;
        
        if(currentColWidth + difference > 20.) // avoids tiny column
        {
            wc.threadColumnWidth = currentColWidth + difference;
            [controlView setNeedsDisplay:YES];
        }
        
        return YES;
    }
    
    return [super continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView];
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    if(self.modifyingThreadColumnWidth == YES)
    {
        self.modifyingThreadColumnWidth = NO;
        [[NSCursor resizeLeftRightCursor] pop];
    }
    
    [super stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag];
}

#pragma mark -
#pragma mark Contextual menu

- (NSMenu *)menuForEvent:(NSEvent *)anEvent inRect:(NSRect)cellFrame ofView:(NSView *)aView
{
	// @@@ TODO: filter / highlight by same thread, same tag, same message, etc
	return nil;
}

@end
