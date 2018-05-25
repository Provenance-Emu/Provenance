/*
 *
 * Modified BSD license.
 *
 * Based on
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com>
 * Copyright (c) 2008 Loren Brichter,
 *  
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


#import <UIKit/UIKit.h>
#import "LoggerMessageData.h"
#import "LoggerConstView.h"
#import "UIColorRGBA.h"
#import "time_converter.h"
#import "LoggerUtils.h"
#import <CoreText/CoreText.h>
#import "LoggerTextStyleManager.h"
#include "NullStringCheck.h"

extern NSString * const kMessageCellReuseID;
#define DEAFULT_BACKGROUND_GRAY_VALUE	0.98f

@interface LoggerMessageCell : UITableViewCell
{
	UIView					*_messageView;		// a view which draws content of message
	UITableView				*_hostTableView;	// a tableview hosting this cell
	LoggerMessageData		*_messageData;
	UIImage					*_imageData;
}
@property (nonatomic, assign) UITableView				*hostTableView;
@property (nonatomic, retain) LoggerMessageData			*messageData;
@property (nonatomic, retain) UIImage					*imageData;
@property (nonatomic, retain) __attribute__((NSObject)) CFMutableArrayRef textFrameContainer;

// initialize with predefined style and reuse identifier
-(id)initWithPreConfig;

// this method actually draws message content. subclasses should draw their own
-(void)drawMessageView:(CGRect)cellFrame;

-(void)setupForIndexpath:(NSIndexPath *)anIndexPath
			 messageData:(LoggerMessageData *)aMessageData;

- (void)drawTimestampAndDeltaInRect:(CGRect)aDrawRect
			   highlightedTextColor:(UIColor *)aHighlightedTextColor;

- (void)drawMessageInRect:(CGRect)aDrawRect
	 highlightedTextColor:(UIColor *)aHighlightedTextColor;

-(void)setImagedata:(NSData *)anImageData forRect:(CGRect)aRect;

@end
