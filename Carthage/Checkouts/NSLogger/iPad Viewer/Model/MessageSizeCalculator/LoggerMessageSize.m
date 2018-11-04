/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 2010-2012 Florent Pillet,
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
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


#import "LoggerMessageSize.h"
#import "LoggerMessage.h"
#import <CoreText/CoreText.h>

CGFloat			_minHeightForCell;
CGFloat			_heightFileLineFunction;
CGFloat			_heightSingleDataLine;

CGFloat			_hintHeightForLongText;
CGFloat			_hintHeightForLongData;

@implementation LoggerMessageSize
+ (void)initialize
{
	_minHeightForCell = 0;
	_heightFileLineFunction =  0;
	_heightSingleDataLine = 0;

	//initialize base values
	[LoggerMessageSize minimumHeightForCellOnWidth:MSG_CELL_PORTRAIT_WIDTH];
	[LoggerMessageSize heightOfFileLineFunctionOnWidth:MSG_CELL_PORTRAIT_WIDTH];
	[LoggerMessageSize heightOfSingleDataLineOnWidth:MSG_CELL_PORTRAIT_WIDTH];
	
	//@@TODO:: we need a unified, size formatter
	CGFloat maxWidth = MSG_CELL_PORTRAIT_WIDTH-(TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_LATERAL_PADDING);
	CGFloat maxHeight = MSG_CELL_PORTRAIT_MAX_HEIGHT - MSG_CELL_TOP_PADDING;
	CGSize const maxConstraint = CGSizeMake(maxWidth,maxHeight);
	
	// hint text should be short, and small at the bottom so that its size,
	// especially the width, won't exceed the smallest possible width, the portrait width
	NSString *textHint = NSLocalizedString(kBottomHintText, nil);
	CGSize htr = [LoggerTextStyleManager sizeforStringWithDefaultHintFont:textHint constraint:maxConstraint];
	_hintHeightForLongText = htr.height;

	NSString *dataHint = NSLocalizedString(kBottomHintData, nil);
	CGSize hdr = [LoggerTextStyleManager sizeforStringWithDefaultHintFont:dataHint constraint:maxConstraint];
	_hintHeightForLongData = hdr.height;
	
MTLog(@"htr %@ hdr %@",NSStringFromCGSize(htr),NSStringFromCGSize(hdr));

}


+ (CGFloat)minimumHeightForCellOnWidth:(CGFloat)aWidth
{
	// we're to fix the min size of cell since it only is a sets of short strings
	if(_minHeightForCell != 0)
		return _minHeightForCell;

	CGSize const maxConstraint = CGSizeMake(MSG_CELL_PORTRAIT_WIDTH,MSG_CELL_PORTRAIT_MAX_HEIGHT);

	CGSize r1 = [LoggerTextStyleManager sizeForStringWithDefaultFont:@"10:10:10.256" constraint:maxConstraint];
	CGSize r2 = [LoggerTextStyleManager sizeForStringWithDefaultFont:@"+999ms" constraint:maxConstraint];
	CGSize r3 = [LoggerTextStyleManager sizeForStringWithDefaultFont:@"Main Thread" constraint:maxConstraint];
	CGSize r4 = [LoggerTextStyleManager sizeForStringWithDefaultTagAndLevelFont:@"qWTy" constraint:maxConstraint];
		
	_minHeightForCell = fmaxf((r1.height + r2.height), (r3.height + r4.height)) + 4;

	return _minHeightForCell;
}

+ (CGFloat)heightOfFileLineFunctionOnWidth:(CGFloat)aWidth
{
	if(_heightFileLineFunction != 0)
		return _heightFileLineFunction;

	CGSize const maxConstraint = CGSizeMake(MSG_CELL_PORTRAIT_WIDTH,MSG_CELL_PORTRAIT_MAX_HEIGHT);

	CGSize r = [LoggerTextStyleManager sizeForStringWithDefaultTagAndLevelFont:@"file:100 funcQyTg" constraint:maxConstraint];
	
	_heightFileLineFunction = r.height + MSG_CELL_VERTICAL_PADDING;

	return _heightFileLineFunction;
}

+(CGFloat)heightOfSingleDataLineOnWidth:(CGFloat)aWidth
{
	if(_heightSingleDataLine != 0)
		return _heightSingleDataLine;

	CGSize const maxConstraint = CGSizeMake(MSG_CELL_PORTRAIT_WIDTH,MSG_CELL_PORTRAIT_MAX_HEIGHT);
	CGSize r = [LoggerTextStyleManager sizeForStringWithDefaultMonospacedFont:@"000:" constraint:maxConstraint];

	_heightSingleDataLine = r.height;

	return _heightFileLineFunction;
}

+ (CGFloat)heightOfFileLineFunction:(LoggerMessage * const)aMessage
									maxWidth:(CGFloat)aMaxWidth
								   maxHeight:(CGFloat)aMaxHeight
{
	CGSize const maxConstraint = CGSizeMake(aMaxWidth,aMaxHeight);
	NSString *s = aMessage.fileFuncString;
	CGSize fs = [LoggerTextStyleManager sizeForStringWithDefaultFileAndFunctionFont:s constraint:maxConstraint];
	return fs.height;
}

+ (CGSize)sizeOfMessage:(LoggerMessage * const)aMessage
				maxWidth:(CGFloat)aMaxWidth
			   maxHeight:(CGFloat)aMaxHeight
{
	CGFloat minimumHeight = \
		[LoggerMessageSize minimumHeightForCellOnWidth:aMaxWidth];

	CGSize sz = CGSizeMake(aMaxWidth,aMaxHeight);
	CGSize const maxConstraint = CGSizeMake(aMaxWidth,aMaxHeight);
	
	switch (aMessage.contentsType)
	{
		case kMessageString: {
			
			NSString *s = aMessage.textRepresentation;
			CGSize frameSize = [LoggerTextStyleManager sizeForStringWithDefaultFont:s constraint:maxConstraint];
			sz.height = fminf(frameSize.height, sz.height);
			break;
		}

		case kMessageData: {
			NSUInteger numBytes = [(NSData *)aMessage.message length];
			NSInteger nLines = (numBytes >> 4) + ((numBytes & 15) ? 1 : 0) + 1;
			if (nLines > MAX_DATA_LINES)
				nLines = MAX_DATA_LINES + 1;
			
			CGFloat slh = [LoggerMessageSize heightOfSingleDataLineOnWidth:aMaxWidth];
			sz.height = slh * nLines;
			break;
		}

		case kMessageImage: {
			// approximate, compute ratio then refine height
			CGSize imgSize = aMessage.imageSize;
			CGFloat ratio = fmaxf(1.0f, fmaxf(imgSize.width / sz.width, imgSize.height / (sz.height / 2.0f)));
			sz.height = ceilf(imgSize.height / ratio);
			break;
		}
		default:
			break;
	}

	//CGFloat displayHeight = sz.height + MSG_CELL_VERTICAL_PADDING;
	sz.height = fmaxf(sz.height, minimumHeight);

	// return calculated drawing size
	return sz;
}

+ (CGFloat)heightOfHint:(LoggerMessage * const)aMessage maxWidth:(CGFloat)aMaxWidth maxHeight:(CGFloat)aMaxHeight
{
/*
	CGSize sz = CGSizeMake(aMaxWidth,aMaxHeight);
	CGSize const maxConstraint = CGSizeMake(aMaxWidth,aMaxHeight);
	switch (aMessage.contentsType)
	{
		case kMessageString: {
			
			CGSize hr = [LoggerTextStyleManager sizeForStringWithDefaultMonospacedFont:hintForLongText constraint:maxConstraint];
			sz.height = fminf(hr.height, sz.height);
			break;
		}
			
		case kMessageData: {
			CGSize hr = [LoggerTextStyleManager sizeForStringWithDefaultMonospacedFont:hintForLargeData constraint:maxConstraint];
			sz.height = fminf(hr.height, sz.height);
			break;
		}

		case kMessageImage:
		default:
			break;
	}

	// return calculated drawing size
	return sz;
*/
	
	switch (aMessage.contentsType)
	{
		case kMessageString: {
			return _hintHeightForLongText;
		}
			
		case kMessageData: {
			return _hintHeightForLongData;
		}
			
		case kMessageImage:
		default:
			break;
	}

	return 0.f;
}

@end
