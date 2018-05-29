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


#import "LoggerMessageCell.h"
#import "LoggerUtils.h"

NSString * const kMessageCellReuseID = @"messageCell";
UIFont *displayDefaultFont = nil;
UIFont *displayTagAndLevelFont = nil;
UIFont *displayMonospacedFont = nil;

CGColorRef _defaultGrayColor = NULL;
CGColorRef _defaultWhiteColor = NULL;
CGColorRef _fileFuncBackgroundColor = NULL;
CGColorRef _hintTextForegroundColor = NULL;
CGColorRef _defaultTagColor = NULL;
CGColorRef _defaultLevelColor = NULL;

NSString *defaultTextHint = nil;
NSString *defaultDataHint = nil;

//#define USE_UIKIT_FOR_DRAWING
//#define DEBUG_CT_STR_RANGE
//#define DEBUG_CT_FRAME_RANGE
//#define DEBUG_DRAW_AREA

#define TEXT_LENGH_BETWEEN_LOCS(LOCATION_1,LOCATION_0) (labs(LOCATION_1 - LOCATION_0))
#define BORDER_LINE_WIDTH 1.f

@interface LoggerMessageView : UIView
@end
@implementation LoggerMessageView
- (void)drawRect:(CGRect)aRect
{
    UIView *superView = [self superview];
    UIView *superSuperView = [superView superview];
    if ([superSuperView respondsToSelector:@selector(drawMessageView:)]) {
        [(LoggerMessageCell *)superSuperView drawMessageView:aRect];
    } else {
        if ([superView respondsToSelector:@selector(drawMessageView:)]) {
            [(LoggerMessageCell *)superView drawMessageView:aRect];
        } else {
            NSLog(@"Cannot draw this cell: %@", superSuperView);
        }
    }
}
@end

@implementation LoggerMessageCell
{
	CFMutableAttributedStringRef _displayString;
	CTFramesetterRef _textFrameSetter;
	CFMutableArrayRef _textFrameContainer;
	
	CGRect					_tagHighlightRect;
	CGRect					_levelHightlightRect;
}
@synthesize hostTableView = _hostTableView;
@synthesize messageData = _messageData;
@synthesize imageData = _imageData;
@synthesize textFrameContainer = _textFrameContainer;

+(void)initialize
{
	defaultTextHint = [NSLocalizedString(@"Double-click to see all text...", nil) retain];

	defaultDataHint = [NSLocalizedString(@"Double-click to see all data...", nil) retain];

	if(displayDefaultFont == nil)
	{
		displayDefaultFont =
			[[UIFont
			  fontWithName:kDefaultFontName
			  size:DEFAULT_FONT_SIZE] retain];
	}
	
	if(displayTagAndLevelFont == nil)
	{
		displayTagAndLevelFont =
			[[UIFont
			  fontWithName:kTagAndLevelFontName
			  size:DEFAULT_TAG_LEVEL_SIZE] retain];
	}
	
	if(displayMonospacedFont == nil)
	{
		displayMonospacedFont =
			[[UIFont
			  fontWithName:kMonospacedFontName
			  size:DEFAULT_MONOSPACED_SIZE] retain];
	}
	
	CGColorSpaceRef csr = CGColorSpaceCreateDeviceRGB();
	if(_defaultGrayColor == NULL){
		CGFloat fcomps[] = { 0.5f, 0.5f, 0.5f, 1.f };
		CGColorRef fc = CGColorCreate(csr, fcomps);
		_defaultGrayColor = fc;
	}

	if(_defaultWhiteColor == NULL)
	{
		CGFloat fcomps[] = { 1.f, 1.f, 1.f, 1.f };
		CGColorRef fc = CGColorCreate(csr, fcomps);
		_defaultWhiteColor = fc;
	}
	
	if(_fileFuncBackgroundColor == NULL)
	{
		CGFloat comps[] = { (239.0f / 255.0f), (233.0f / 255.0f), (252.0f / 255.0f), 1.f };
		CGColorRef bc = CGColorCreate(csr, comps);
		_fileFuncBackgroundColor = bc;
	}
	
	if(_hintTextForegroundColor == NULL)
	{
		CGFloat comps[] = { 0.3f, 0.3f, 0.3f, 1.f };
		CGColorRef fc = CGColorCreate(csr, comps);
		_hintTextForegroundColor = fc;
	}

	if(_defaultTagColor == NULL){
		CGFloat comps[] = { 0.25f, 0.25f, 0.25f, 1.f };
		CGColorRef c = CGColorCreate(csr, comps);
		_defaultTagColor = c;
	}
	
	if(_defaultLevelColor == NULL){
		CGFloat comps[] = { 0.51f, 0.57f, 0.79f, 1.f };
		CGColorRef c = CGColorCreate(csr, comps);
		_defaultLevelColor = c;
	}
	
	CGColorSpaceRelease(csr);

}

-(id)initWithPreConfig
{
	return
		[self
		 initWithStyle:UITableViewCellStyleDefault
		 reuseIdentifier:kMessageCellReuseID];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
	{
		self.accessoryType = UITableViewCellAccessoryNone;
		_messageView = [[LoggerMessageView alloc] initWithFrame:CGRectZero];
		
		//@@TODO:: measure performance with this
		_messageView.opaque = YES;
		_messageView.clearsContextBeforeDrawing = NO;
		[self addSubview:_messageView];
		[_messageView release];
		
		
		//@@TODO :: check if memory is properly released, retained
		CFMutableArrayRef frameContainer = CFArrayCreateMutable(kCFAllocatorDefault,0, &kCFTypeArrayCallBacks );
		self.textFrameContainer = frameContainer;
		CFRelease(frameContainer);
		
    }
    return self;
}

-(void)dealloc
{
	self.hostTableView = nil;
	self.messageData = nil;
	self.imageData = nil;
	CFArrayRemoveAllValues(self.textFrameContainer);
	self.textFrameContainer = nil;

	[super dealloc];
}

- (void)setFrame:(CGRect)aFrame
{
	[super setFrame:aFrame];
	CGRect bound = [self bounds];

	// leave room for the seperator line
	//CGRect messageFrame = CGRectInset(bound, 0, 1);

	[_messageView setFrame:bound];
}

- (void)setNeedsDisplay
{
	[super setNeedsDisplay];
	[_messageView setNeedsDisplay];
}

- (void)setNeedsDisplayInRect:(CGRect)rect
{
	[super setNeedsDisplayInRect:rect];
	[_messageView setNeedsDisplayInRect:rect];
}


#if 0
- (void)setNeedsLayout
{
	[super setNeedsLayout];
	[_messageView setNeedsLayout];
}
#endif

-(void)prepareForReuse
{
	[super prepareForReuse];

	if([self.messageData dataType] == kMessageImage)
	{
		[self.messageData cancelImageForCell:self];
	}

	self.imageData = nil;
	self.messageData = nil;
	CFArrayRemoveAllValues(self.textFrameContainer);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

-(void)setupForIndexpath:(NSIndexPath *)anIndexPath
			 messageData:(LoggerMessageData *)aMessageData
{
	self.messageData = aMessageData;
	self.imageData = nil;

	if([aMessageData dataType] == kMessageImage)
	{
		[aMessageData imageForCell:self];
	}
	
	
	if(aMessageData != nil)
	{
		BOOL truncated = [[aMessageData truncated] boolValue];
		float height = [[aMessageData portraitHeight] floatValue];
		float fflh = [aMessageData.portraitFileFuncHeight floatValue];
		
		// file func height
		if(!IS_NULL_STRING(aMessageData.fileFuncRepresentation))
		{
			height += fflh;
		}
		
		// add hint height if truncated
		if(truncated){
			//@@TODO:: find accruate height
			CGFloat hint = [[aMessageData portraitHintHeight] floatValue];
			height += hint + 100;
		}
		
		CGRect cellFrame = (CGRect){CGPointZero,{MSG_CELL_PORTRAIT_WIDTH,height}};
				
		// string range indexes
		NSInteger totalTextLength = 0;
		NSInteger locTimestamp	= 0;
		
		//@@TODO:: timedelta
        
        if (IS_NULL_STRING(aMessageData.tag)) aMessageData.tag = @" ";
        if (IS_NULL_STRING(aMessageData.textRepresentation)) aMessageData.textRepresentation = @"";

		NSInteger locTimedelta	= locTimestamp + [aMessageData.timestampString length];
		NSInteger locThread		= locTimedelta;// + [aMessageData.timeDeltaString length];
		
		NSInteger locTag		= locThread + [aMessageData.threadID length];
		NSInteger locLevel		= locTag + [aMessageData.tag length];
		NSInteger locFileFunc	= locLevel + [[aMessageData.level stringValue] length];
		NSInteger locMessage	= locFileFunc + (IS_NULL_STRING(aMessageData.fileFuncRepresentation)?0:[aMessageData.fileFuncRepresentation length]);
		NSInteger locHint		= 0;

		switch([self.messageData dataType]){
			case kMessageString:{
				locHint = locMessage + [aMessageData.textRepresentation length];
				
				if(truncated){
					totalTextLength = locHint + [defaultTextHint length];
				}else{
					totalTextLength = locHint;
				}
				break;
			}
			case kMessageData: {
				locHint = locMessage + [aMessageData.textRepresentation length];
				
				if(truncated){
					totalTextLength = locHint + [defaultDataHint length];
				}else{
					totalTextLength = locHint;
				}
				break;
			}
			default:
				break;
		}
		
		//  Create an empty mutable string big enough to hold our test
		CFMutableAttributedStringRef as = CFAttributedStringCreateMutable(kCFAllocatorDefault, totalTextLength);
		CFAttributedStringBeginEditing(as);
		
		// Place timestamp string
		CFAttributedStringReplaceString(as, CFRangeMake(locTimestamp, 0), (CFStringRef)aMessageData.timestampString);
		
		// Place thread id string
		CFAttributedStringReplaceString(as, CFRangeMake(locThread, 0), (CFStringRef)aMessageData.threadID);
		
		// Place Tag
        CFAttributedStringReplaceString(as, CFRangeMake(locTag, 0), (CFStringRef)aMessageData.tag);
		
		// Place level
		CFAttributedStringReplaceString(as, CFRangeMake(locLevel, 0), (CFStringRef)[aMessageData.level stringValue]);
		
		// Place File, Func
		if(!IS_NULL_STRING(aMessageData.fileFuncRepresentation)){
			CFAttributedStringReplaceString(as, CFRangeMake(locFileFunc, 0), (CFStringRef)aMessageData.fileFuncRepresentation);
		}
		
		switch([self.messageData dataType]){
			case kMessageString:{
				CFAttributedStringReplaceString(as,CFRangeMake(locMessage, 0),(CFStringRef)aMessageData.textRepresentation);
				
				if(truncated){
					CFAttributedStringReplaceString(as,CFRangeMake(locHint, 0),(CFStringRef)defaultTextHint);
				}
				break;
			}
			case kMessageData: {
				CFAttributedStringReplaceString(as,CFRangeMake(locMessage, 0),(CFStringRef)aMessageData.textRepresentation);
				
				if(truncated){
					CFAttributedStringReplaceString(as,CFRangeMake(locHint, 0),(CFStringRef)defaultDataHint);
				}
				break;
			}
			default:
				break;
		}
	
		//timestamp & delta
		[self
		 timestampAndDeltaAttribute:as
		 timestampRange:CFRangeMake(locTimestamp, TEXT_LENGH_BETWEEN_LOCS(locTimedelta,locTimestamp))
		 deltaRange:CFRangeMake(locTimedelta, TEXT_LENGH_BETWEEN_LOCS(locThread,locTimedelta))
		 hightlighted:NO];

		// thread id
		[self
		 threadIDAttribute:as
		 threadRange:CFRangeMake(locThread, TEXT_LENGH_BETWEEN_LOCS(locTag,locThread))
		 hightlighted:NO];
		
		// tag attribute
		[self
		 tagAttribute:as
		 tagRange:CFRangeMake(locTag, TEXT_LENGH_BETWEEN_LOCS(locLevel,locTag))
		 hightlighted:NO];
		
		// level attribute
		[self
		 levelAttribute:as
		 levelRange:CFRangeMake(locLevel, TEXT_LENGH_BETWEEN_LOCS(locFileFunc,locLevel))
		 hightlighted:NO];
		
		// file name & function name
		if(!IS_NULL_STRING(aMessageData.fileFuncRepresentation))
		{
			[self
			 fileLineFunctionAttribute:as
			 stringRange:CFRangeMake(locFileFunc, TEXT_LENGH_BETWEEN_LOCS(locMessage,locFileFunc))
			 hightlighted:NO];
		}

		// message body & hint
		if([aMessageData dataType] != kMessageImage)
		{
			[self
			 messageAttribute:as
			 truncated:truncated
			 messageType:[aMessageData dataType]
			 messageRange:CFRangeMake(locMessage, TEXT_LENGH_BETWEEN_LOCS(locHint,locMessage))
			 hintRange:CFRangeMake(locHint, TEXT_LENGH_BETWEEN_LOCS(totalTextLength,locHint))
			 hightlighted:NO];
		}
		
		// done editing the attributed string
		CFAttributedStringEndEditing(as);

		
		
		
		CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(as);
		//timestamp and delta
		CGRect drawRect = [self timestampAndDeltaRect:cellFrame];
		CTFrameRef frame = \
			[self
			 timestampAndDeltaText:drawRect
			 stringForRect:as
			 stringRange:CFRangeMake(locTimestamp, TEXT_LENGH_BETWEEN_LOCS(locThread,locTimestamp))
			 frameSetter:framesetter];
			 
		CFArrayAppendValue(self.textFrameContainer,frame);
		CFRelease(frame);

		//thread id
		drawRect = [self threadIDAndTagTextRect:cellFrame];
		CFRange tidrng = CFRangeMake(locThread, TEXT_LENGH_BETWEEN_LOCS(locTag,locThread));
		frame = [self threadIDText:drawRect stringForRect:as stringRange:tidrng frameSetter:framesetter];
		CFArrayAppendValue(self.textFrameContainer,frame);
		CFRelease(frame);

		// thread-id size
		CGSize tidsz	= [self desiredThreadIdSize:drawRect.size threadRange:tidrng frameSetter:framesetter];
		CGSize tgsz		= CGSizeZero;
		
		if(!IS_NULL_STRING([aMessageData tag])){
			// tag & tag hight area drawing
			CFRange tgrng	= CFRangeMake(locTag, TEXT_LENGH_BETWEEN_LOCS(locLevel,locTag));
			CGSize	sz		= [self desiredTagSize:drawRect.size tagRange:tgrng frameSetter:framesetter];
			tgsz			= CGSizeMake(roundf(sz.width), round(sz.height));

			CGRect tghr =
				(CGRect){{CGRectGetMinX(drawRect), CGRectGetMinY(drawRect) + tidsz.height},
						{tgsz.width + MSG_CELL_TAG_LEVEL_LEFT_PADDING * 2, tgsz.height + MSG_CELL_TAG_LEVEL_TOP_PADDING * 2}};
			
			CGRect tgr =
				(CGRect){{CGRectGetMinX(drawRect) + MSG_CELL_TAG_LEVEL_LEFT_PADDING, CGRectGetMaxY(drawRect) - tgsz.height - tidsz.height - MSG_CELL_TAG_LEVEL_TOP_PADDING},
						tgsz};

			frame = [self tagText:tgr stringForRect:as stringRange:tgrng frameSetter:framesetter];
			CFArrayAppendValue(self.textFrameContainer,frame);
			CFRelease(frame);
			
			_tagHighlightRect = tghr;
		}else{
			_tagHighlightRect = CGRectZero;
		}
		
		// level drawing
		if(!IS_NULL_STRING([aMessageData.level stringValue])){

			CFRange lrng	= CFRangeMake(locLevel, TEXT_LENGH_BETWEEN_LOCS(locFileFunc,locLevel));
			CGSize lsz		= [self desiredLevelSize:drawRect.size levelRange:lrng frameSetter:framesetter];

			CGFloat levelDrawBeingX = CGRectGetMinX(drawRect) + tgsz.width + MSG_CELL_TAG_LEVEL_LEFT_PADDING * 2;

			CGRect lhr =
				(CGRect){{levelDrawBeingX, CGRectGetMinY(drawRect) + tidsz.height}
					,{lsz.width + MSG_CELL_TAG_LEVEL_LEFT_PADDING * 2, lsz.height + MSG_CELL_TAG_LEVEL_TOP_PADDING * 2}};

			CGRect lr =
				(CGRect){{levelDrawBeingX + MSG_CELL_TAG_LEVEL_LEFT_PADDING, CGRectGetMaxY(drawRect) - lsz.height - tidsz.height - MSG_CELL_TAG_LEVEL_TOP_PADDING},
					lsz};

			frame = [self LevelText:lr stringForRect:as stringRange:lrng frameSetter:framesetter];
			CFArrayAppendValue(self.textFrameContainer,frame);
			CFRelease(frame);
			
			_levelHightlightRect = lhr;
		}else{
			_levelHightlightRect = CGRectZero;
		}
		
		//file and function
		if(!IS_NULL_STRING(aMessageData.fileFuncRepresentation))
		{
			drawRect = [self fileLineFunctionTextRect:cellFrame lineHeight:fflh];
			frame = \
				[self
				 fileLineFunctionText:drawRect
				 stringForRect:as
				 stringRange:CFRangeMake(locFileFunc, [aMessageData.fileFuncRepresentation length])
				 frameSetter:framesetter];
			
			CFArrayAppendValue(self.textFrameContainer,frame);
			CFRelease(frame);
		}

		//message
		if([aMessageData dataType] != kMessageImage)
		{
			drawRect = [self messageTextRect:cellFrame fileFuncLineHeight:fflh];
			frame = \
				[self
				 messageText:drawRect
				 stringForRect:as
				 stringRange:CFRangeMake(locMessage, TEXT_LENGH_BETWEEN_LOCS(totalTextLength,locMessage))
				 frameSetter:framesetter];
			 
			 CFArrayAppendValue(self.textFrameContainer,frame);
			 CFRelease(frame);
		}

		// throw attributed string as well as frame setter.
		CFRelease(framesetter);
		CFRelease(as);
	}
	
	[self setNeedsDisplay];
}

// draw image data from ManagedObject model (LoggerMessage)
-(void)setImagedata:(NSData *)anImageData forRect:(CGRect)aRect
{
	// in case this cell is detached from tableview,
	if(self.superview == nil)
	{
		return;
	}
	
	UIImage *image = [[UIImage alloc] initWithData:anImageData];
	self.imageData = image;
	[image release],image = nil;
	
	//[self setNeedsDisplayInRect:aRect];
	[self setNeedsDisplay];
}

//------------------------------------------------------------------------------
#pragma mark - Draw Frame
//------------------------------------------------------------------------------
- (CGRect)timestampAndDeltaRect:(CGRect)aBoundRect
{
	CGRect r = CGRectMake(CGRectGetMinX(aBoundRect),
						  CGRectGetMinY(aBoundRect),
						  TIMESTAMP_COLUMN_WIDTH,
						  CGRectGetHeight(aBoundRect));
	return r;
}

- (CGRect)threadIDAndTagTextRect:(CGRect)aBoundRect
{
	CGRect r = CGRectMake(CGRectGetMinX(aBoundRect) + TIMESTAMP_COLUMN_WIDTH + MSG_CELL_LEFT_PADDING,
						  CGRectGetMinY(aBoundRect) + MSG_CELL_TOP_PADDING,
						  DEFAULT_THREAD_COLUMN_WIDTH - MSG_CELL_LATERAL_PADDING,
						  CGRectGetHeight(aBoundRect) - MSG_CELL_VERTICAL_PADDING);
	return r;
}


- (CGSize)desiredThreadIdSize:(CGSize)aConstraint
				  threadRange:(CFRange)aThreadRange
				  frameSetter:(CTFramesetterRef)framesetter
{
	CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, aThreadRange, NULL, aConstraint, NULL);
	return frameSize;
}

- (CGSize)desiredTagSize:(CGSize)aConstraint
				tagRange:(CFRange)aRange
			 frameSetter:(CTFramesetterRef)framesetter
{
	CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, aRange, NULL, aConstraint, NULL);
    frameSize.width += 1;
	return frameSize;
}

- (CGSize)desiredLevelSize:(CGSize)aConstraint
				levelRange:(CFRange)aRange
			   frameSetter:(CTFramesetterRef)framesetter
{
	CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, aRange, NULL, aConstraint, NULL);
	return frameSize;
}

- (CGRect)fileLineFunctionTextRect:(CGRect)aBoundRect lineHeight:(CGFloat)aLineHeight
{
	CGRect r =	CGRectMake(CGRectGetMinX(aBoundRect) + (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_LEFT_PADDING),
						   CGRectGetMaxY(aBoundRect) - MSG_CELL_TOP_PADDING - aLineHeight,
						   CGRectGetWidth(aBoundRect) - (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_LATERAL_PADDING),
						   aLineHeight);
	
	return r;
}

- (CGRect)messageTextRect:(CGRect)aBoundRect fileFuncLineHeight:(CGFloat)aLineHeight
{
	CGRect r = CGRectMake(CGRectGetMinX(aBoundRect) + (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_LEFT_PADDING),
						  CGRectGetMinY(aBoundRect) + MSG_CELL_TOP_PADDING,
						  CGRectGetWidth(aBoundRect) - (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_LATERAL_PADDING),
						  CGRectGetHeight(aBoundRect) - MSG_CELL_VERTICAL_PADDING - aLineHeight);

	return r;
}

//------------------------------------------------------------------------------
#pragma mark - Text Attribute
//------------------------------------------------------------------------------
-(void)timestampAndDeltaAttribute:(CFMutableAttributedStringRef)aString
				   timestampRange:(CFRange)aTimestampRange
					   deltaRange:(CFRange)aDeltaRange
					 hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"\n\nts : %@",[[s attributedSubstringFromRange:NSMakeRange(aTimestampRange.location, aTimestampRange.length)] string]);
	MTLog(@"delta : %@",[[s attributedSubstringFromRange:NSMakeRange(aDeltaRange.location, aDeltaRange.length)] string]);
#endif

	//TODO:: get color, underline, bold, hightlight etc
	CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultFont];
	CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultParagraphStyle];
	
	//  Apply our font and line spacing attributes over the span
	CFAttributedStringSetAttribute(aString, aTimestampRange, kCTFontAttributeName, f);
	CFAttributedStringSetAttribute(aString, aTimestampRange, kCTParagraphStyleAttributeName, p);
}

- (void)threadIDAttribute:(CFMutableAttributedStringRef)aString
			  threadRange:(CFRange)aThreadRange
			 hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"thread : %@",[[s attributedSubstringFromRange:NSMakeRange(aThreadRange.location, aThreadRange.length)] string]);
#endif
	
	CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultFont];
	CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultThreadStyle];
	
	CFAttributedStringSetAttribute(aString, aThreadRange, kCTFontAttributeName, f);
	CFAttributedStringSetAttribute(aString, aThreadRange, kCTParagraphStyleAttributeName, p);
	CFAttributedStringSetAttribute(aString, aThreadRange, kCTForegroundColorAttributeName, _defaultGrayColor);
}


- (void)tagAttribute:(CFMutableAttributedStringRef)aString
			tagRange:(CFRange)aTagRange
		hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"tag : %@",[[s attributedSubstringFromRange:NSMakeRange(aTagRange.location, aTagRange.length)] string]);
	MTLog(@"level : %@",[[s attributedSubstringFromRange:NSMakeRange(aLevelRange.location, aLevelRange.length)] string]);
#endif

	CTFontRef tlf = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelFont];
	CTParagraphStyleRef tlp = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelStyle];
	
	CFAttributedStringSetAttribute(aString, aTagRange, kCTFontAttributeName, tlf);
	CFAttributedStringSetAttribute(aString, aTagRange, kCTParagraphStyleAttributeName, tlp);
	CFAttributedStringSetAttribute(aString, aTagRange, kCTForegroundColorAttributeName, _defaultWhiteColor);
}

- (void)levelAttribute:(CFMutableAttributedStringRef)aString
			levelRange:(CFRange)aLevelRange
		  hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"tag : %@",[[s attributedSubstringFromRange:NSMakeRange(aTagRange.location, aTagRange.length)] string]);
	MTLog(@"level : %@",[[s attributedSubstringFromRange:NSMakeRange(aLevelRange.location, aLevelRange.length)] string]);
#endif
	
	CTFontRef tlf = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelFont];
	CTParagraphStyleRef tlp = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelStyle];
	
	CFAttributedStringSetAttribute(aString, aLevelRange, kCTFontAttributeName, tlf);
	CFAttributedStringSetAttribute(aString, aLevelRange, kCTParagraphStyleAttributeName, tlp);
	CFAttributedStringSetAttribute(aString, aLevelRange, kCTForegroundColorAttributeName, _defaultWhiteColor);
}



- (void)fileLineFunctionAttribute:(CFMutableAttributedStringRef)aString
					  stringRange:(CFRange)aStringRange
					 hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"fileFunc : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultFileAndFunctionFont];
	CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultFileAndFunctionStyle];
	CFAttributedStringSetAttribute(aString, aStringRange, kCTFontAttributeName, f);
	CFAttributedStringSetAttribute(aString, aStringRange, kCTParagraphStyleAttributeName, p);
	CFAttributedStringSetAttribute(aString, aStringRange, kCTForegroundColorAttributeName, _defaultGrayColor);
	
	// not working *confirmed* :(
	//CFAttributedStringSetAttribute(aString, aStringRange, (CFStringRef)NSBackgroundColorAttributeName, _fileFuncBackgroundColor);
}

- (void)messageAttribute:(CFMutableAttributedStringRef)aString
			   truncated:(BOOL)isTruncated
			 messageType:(LoggerMessageType)aMessageType
			messageRange:(CFRange)aMessageRange
			   hintRange:(CFRange)aHintRange
			hightlighted:(BOOL)isHighlighted
{
#ifdef DEBUG_CT_STR_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"message : %@",[[s attributedSubstringFromRange:NSMakeRange(aMessageRange.location, aMessageRange.length)] string]);
	
	if(isTruncated)
	{
		MTLog(@"hint : %@",[[s attributedSubstringFromRange:NSMakeRange(aHintRange.location, aHintRange.length)] string]);
	}
#endif
	
	if(aMessageType == kMessageString){
		
		CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultFont];
		CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultParagraphStyle];
		
		CFAttributedStringSetAttribute(aString, aMessageRange, kCTFontAttributeName, f);
		CFAttributedStringSetAttribute(aString, aMessageRange, kCTParagraphStyleAttributeName, p);
				
	}else if(aMessageType == kMessageData){
		
		CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultMonospacedFont];
		CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultMonospacedStyle];

		CFAttributedStringSetAttribute(aString, aMessageRange, kCTFontAttributeName, f);
		CFAttributedStringSetAttribute(aString, aMessageRange, kCTParagraphStyleAttributeName, p);
		
	}
	
	if(isTruncated){
		CTFontRef f = [[LoggerTextStyleManager sharedStyleManager] defaultHintFont];
		CTParagraphStyleRef p = [[LoggerTextStyleManager sharedStyleManager] defaultParagraphStyle];

		CFAttributedStringSetAttribute(aString, aHintRange, kCTFontAttributeName, f);
		CFAttributedStringSetAttribute(aString, aHintRange, kCTParagraphStyleAttributeName, p);
		CFAttributedStringSetAttribute(aString, aHintRange, kCTForegroundColorAttributeName, _hintTextForegroundColor);
	}
}


//------------------------------------------------------------------------------
#pragma mark - CoreText Frame
//------------------------------------------------------------------------------
- (CTFrameRef)timestampAndDeltaText:(CGRect)aDrawRect
					  stringForRect:(CFMutableAttributedStringRef)aString
						stringRange:(CFRange)aStringRange
						frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"timestampAndDeltaText : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CGRect tr = CGRectInset(aDrawRect, 2, 2);

	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddRect(path, NULL, tr);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter, aStringRange, path, NULL);
	CGPathRelease(path);
	
	return frame;
}

- (CTFrameRef)threadIDText:(CGRect)aDrawRect
			 stringForRect:(CFMutableAttributedStringRef)aString
			   stringRange:(CFRange)aStringRange
			   frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"threadIDAndTagText : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CGPathRef path = CGPathCreateWithRect(aDrawRect,NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter,aStringRange, path, NULL);
	CGPathRelease(path);
	return frame;
}

- (CTFrameRef)tagText:(CGRect)aDrawRect
		stringForRect:(CFMutableAttributedStringRef)aString
		  stringRange:(CFRange)aStringRange
		  frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	MTLog(@"aDrawRect %@",NSStringFromCGRect(aDrawRect));
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"tag : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif

	CGPathRef path = CGPathCreateWithRect(aDrawRect,NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter,aStringRange, path, NULL);
	CGPathRelease(path);
	return frame;
}

- (CTFrameRef)LevelText:(CGRect)aDrawRect
		  stringForRect:(CFMutableAttributedStringRef)aString
			stringRange:(CFRange)aStringRange
			frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"threadIDAndTagText : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CGPathRef path = CGPathCreateWithRect(aDrawRect,NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter,aStringRange, path, NULL);
	CGPathRelease(path);
	return frame;
}


- (CTFrameRef)fileLineFunctionText:(CGRect)aDrawRect
					 stringForRect:(CFMutableAttributedStringRef)aString
					   stringRange:(CFRange)aStringRange
					   frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"fileLineFunctionText : %@",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CGPathRef path = CGPathCreateWithRect(aDrawRect,NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter, aStringRange, path, NULL);
	CGPathRelease(path);
	return frame;
}

- (CTFrameRef)messageText:(CGRect)aDrawRect
			stringForRect:(CFMutableAttributedStringRef)aString
			  stringRange:(CFRange)aStringRange
			  frameSetter:(CTFramesetterRef)aFrameSetter
{
#ifdef DEBUG_CT_FRAME_RANGE
	NSAttributedString *s = (NSAttributedString *)aString;
	MTLog(@"messageText : %@\n\n",[[s attributedSubstringFromRange:NSMakeRange(aStringRange.location, aStringRange.length)] string]);
#endif
	
	CGPathRef path = CGPathCreateWithRect(aDrawRect,NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(aFrameSetter,aStringRange, path, NULL);
	CGPathRelease(path);
	return frame;
}


//------------------------------------------------------------------------------
#pragma mark - Drawing Background
//------------------------------------------------------------------------------
- (void)drawTimestampAndDeltaInRect:(CGRect)aDrawRect
			   highlightedTextColor:(UIColor *)aHighlightedTextColor
{
	
}

- (void)drawThreadIDAndTagInRect:(CGRect)aDrawRect
			highlightedTextColor:(UIColor *)aHighlightedTextColor
{

	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextSaveGState(context);
	
	CGRect tagAndLevelRect = CGRectUnion(_tagHighlightRect, _levelHightlightRect);
	MakeRoundedPath(context, tagAndLevelRect, 2.0f);
	CGContextSetFillColorWithColor(context, _defaultTagColor);
	CGContextFillPath(context);
	
	if (CGRectGetWidth(_levelHightlightRect))
	{
		CGContextSaveGState(context);
		CGContextSetFillColorWithColor(context, _defaultLevelColor);
		CGContextClipToRect(context,_levelHightlightRect);
		MakeRoundedPath(context, tagAndLevelRect, 2.0f);
		CGContextFillPath(context);
		CGContextRestoreGState(context);
	}

	CGContextRestoreGState(context);
}

- (void)drawFileLineFunctionInRect:(CGRect)aDrawRect
			  highlightedTextColor:(UIColor *)highlightedTextColor
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);

	float fflh = [[self.messageData portraitFileFuncHeight] floatValue];
	
	CGRect d =
	(CGRect){{CGRectGetMinX(aDrawRect) + (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + BORDER_LINE_WIDTH),CGRectGetMaxY(aDrawRect)  - fflh},
		{CGRectGetWidth(aDrawRect) - (TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + BORDER_LINE_WIDTH),fflh}};
	
	CGContextSetFillColorWithColor(context, _fileFuncBackgroundColor);
	CGContextFillRect(context,d);
	
	CGContextRestoreGState(context);
}

- (void)drawMessageInRect:(CGRect)aDrawRect
	 highlightedTextColor:(UIColor *)aHighlightedTextColor
{
	if([self.messageData dataType] == kMessageImage)
	{
		if(_imageData != nil)
		{
			//TODO:: drawing UIImage takes too much CPU time. find a way to fix it.
			CGRect r = CGRectInset(aDrawRect, 0, 1);
			CGSize srcSize = [_imageData size];
			CGFloat ratio = fmaxf(1.0f, fmaxf(srcSize.width / CGRectGetWidth(r), srcSize.height / CGRectGetHeight(r)));
			CGSize newSize = CGSizeMake(floorf(srcSize.width / ratio), floorf(srcSize.height / ratio));
			//CGRect imageRect = (CGRect){{CGRectGetMinX(r),CGRectGetMinY(r) + CGRectGetHeight(r)},newSize};
			CGRect imageRect = (CGRect){{CGRectGetMinX(r),CGRectGetMinY(r)},newSize};
			[self.imageData drawInRect:imageRect];
			
			self.imageData = nil;
		}
	}
}

//------------------------------------------------------------------------------
#pragma mark - drawRect()
//------------------------------------------------------------------------------
- (void)drawMessageView:(CGRect)cellFrame
{
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// turn antialiasing off
	CGContextSetShouldAntialias(context, false);

	CGContextSetFillColorWithColor(context, _defaultWhiteColor);
	
	//@@TODO:: this single call represent 2% of CPU time. find a way to replace it.
	CGContextFillRect(context, cellFrame);
	
	// Draw separators
	CGContextSetLineWidth(context, BORDER_LINE_WIDTH);
	CGContextSetLineCap(context, kCGLineCapSquare);
	UIColor *cellSeparatorColor = GRAYCOLOR(0.8f);

#if 0
	if (highlighted)
		cellSeparatorColor = CGColorCreateGenericGray(1.0f, BORDER_LINE_WIDTH);
	else
		cellSeparatorColor = CGColorCreateGenericGray(0.80f, BORDER_LINE_WIDTH);
#endif

	CGContextSetStrokeColorWithColor(context, [cellSeparatorColor CGColor]);
	CGContextBeginPath(context);

	// top ceiling line
	CGContextMoveToPoint(context, CGRectGetMinX(cellFrame), floorf(CGRectGetMinY(cellFrame)));
	CGContextAddLineToPoint(context, CGRectGetMaxX(cellFrame), floorf(CGRectGetMinY(cellFrame)));
	
	// bottom floor line
	CGContextMoveToPoint(context, CGRectGetMinX(cellFrame), floorf(CGRectGetMaxY(cellFrame)));
	CGContextAddLineToPoint(context, CGRectGetMaxX(cellFrame), floorf(CGRectGetMaxY(cellFrame)));

	// timestamp/thread separator
	CGContextMoveToPoint(context, floorf(CGRectGetMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH), CGRectGetMinY(cellFrame));
	CGContextAddLineToPoint(context, floorf(CGRectGetMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH), floorf(CGRectGetMaxY(cellFrame)-1));
	
	// thread/message separator
	CGFloat threadColumnWidth = DEFAULT_THREAD_COLUMN_WIDTH;
	
	CGContextMoveToPoint(context, floorf(CGRectGetMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth), CGRectGetMinY(cellFrame));
	CGContextAddLineToPoint(context, floorf(CGRectGetMinX(cellFrame) + TIMESTAMP_COLUMN_WIDTH + threadColumnWidth), floorf(CGRectGetMaxY(cellFrame)-1));
	CGContextStrokePath(context);
    
	// restore antialiasing
	CGContextSetShouldAntialias(context, true);

	
	
	
	
	
	
	// Draw timestamp and time delta column
	[self
	 drawTimestampAndDeltaInRect:[self timestampAndDeltaRect:cellFrame]
	 highlightedTextColor:nil];

	// Draw thread ID and tag
	[self
	 drawThreadIDAndTagInRect:[self threadIDAndTagTextRect:cellFrame]
	 highlightedTextColor:nil];

	// Draw message
	float fflh = [[self.messageData portraitFileFuncHeight] floatValue];
	[self
	 drawMessageInRect:[self messageTextRect:cellFrame fileFuncLineHeight:fflh]
	 highlightedTextColor:nil];

	CGContextSaveGState(context);
	// flip context vertically
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	CGContextTranslateCTM(context, 0, self.bounds.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	
	
	// draw file and function
	if(!IS_NULL_STRING(self.messageData.fileFuncRepresentation))
	{
		[self drawFileLineFunctionInRect:cellFrame highlightedTextColor:nil];
	}
	
	// draw all text frames
	CFIndex count = CFArrayGetCount(self.textFrameContainer);
	for(CFIndex i = 0; i < count; i++){
		CTFrameRef tf = (CTFrameRef)CFArrayGetValueAtIndex(self.textFrameContainer, i);
		CTFrameDraw(tf, context);
	}
	CGContextRestoreGState(context);
}

@end
