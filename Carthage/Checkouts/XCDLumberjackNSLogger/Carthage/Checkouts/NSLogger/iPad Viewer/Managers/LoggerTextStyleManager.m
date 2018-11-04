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


#import "LoggerTextStyleManager.h"
#import "SynthesizeSingleton.h"
#import "NullStringCheck.h"

@interface LoggerTextStyleManager()
+(CGSize)_sizeForString:(NSString *)aString
			 constraint:(CGSize)aConstraint
				   font:(CTFontRef)aFont
				  style:(CTParagraphStyleRef)aStyle;
@end

@implementation LoggerTextStyleManager
SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(LoggerTextStyleManager,sharedStyleManager);

@synthesize defaultFont = _defaultFont;
@synthesize defaultParagraphStyle = _defaultParagraphStyle;

@synthesize defaultThreadStyle = _defaultThreadStyle;

@synthesize defaultTagAndLevelFont = _defaultTagAndLevelFont;
@synthesize defaultTagAndLevelStyle = _defaultTagAndLevelStyle;

@synthesize defaultFileAndFunctionFont = _defaultFileAndFunctionFont;
@synthesize defaultFileAndFunctionStyle = _defaultFileAndFunctionStyle;

@synthesize defaultMonospacedFont = _defaultMonospacedFont;
@synthesize defaultMonospacedStyle = _defaultMonospacedStyle;

@synthesize defaultHintFont = _defaultHintFont;


+(CGSize)_sizeForString:(NSString *)aString constraint:(CGSize)aConstraint font:(CTFontRef)aFont style:(CTParagraphStyleRef)aStyle
{
	
	// calcuate string drawable size
	CFRange textRange = CFRangeMake(0, aString.length);
	
	//  Create an empty mutable string big enough to hold our test
	CFMutableAttributedStringRef string = CFAttributedStringCreateMutable(kCFAllocatorDefault, aString.length);
	
	//  Inject our text into it
	CFAttributedStringReplaceString(string, CFRangeMake(0, 0), (CFStringRef)aString);
	
	//  Apply our font and line spacing attributes over the span
	CFAttributedStringSetAttribute(string, textRange, kCTFontAttributeName, aFont);
	CFAttributedStringSetAttribute(string, textRange, kCTParagraphStyleAttributeName, aStyle);
	
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
	CFRange fitRange;
	
	CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, textRange, NULL, aConstraint, &fitRange);
	
	CFRelease(framesetter);
	CFRelease(string);

	return frameSize;
}


+(CGSize)sizeForStringWithDefaultFont:(NSString *)aString constraint:(CGSize)aConstraint
{
	if(IS_NULL_STRING(aString))
		return CGSizeZero;
	
	CTFontRef font = [[LoggerTextStyleManager sharedStyleManager] defaultFont];
	CTParagraphStyleRef style = [[LoggerTextStyleManager sharedStyleManager] defaultParagraphStyle];
	return [LoggerTextStyleManager _sizeForString:aString constraint:aConstraint font:font style:style];
}

+(CGSize)sizeForStringWithDefaultTagAndLevelFont:(NSString *)aString constraint:(CGSize)aConstraint
{
	if(IS_NULL_STRING(aString))
		return CGSizeZero;

	CTFontRef font = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelFont];
	CTParagraphStyleRef style = [[LoggerTextStyleManager sharedStyleManager] defaultTagAndLevelStyle];
	return [LoggerTextStyleManager _sizeForString:aString constraint:aConstraint font:font style:style];
}

+(CGSize)sizeForStringWithDefaultFileAndFunctionFont:(NSString *)aString constraint:(CGSize)aConstraint
{
	if(IS_NULL_STRING(aString))
		return CGSizeZero;
	
	CTFontRef font = [[LoggerTextStyleManager sharedStyleManager] defaultFileAndFunctionFont];
	CTParagraphStyleRef style = [[LoggerTextStyleManager sharedStyleManager] defaultFileAndFunctionStyle];
	return [LoggerTextStyleManager _sizeForString:aString constraint:aConstraint font:font style:style];
}


+(CGSize)sizeForStringWithDefaultMonospacedFont:(NSString *)aString constraint:(CGSize)aConstraint
{
	if(IS_NULL_STRING(aString))
		return CGSizeZero;

	CTFontRef font = [[LoggerTextStyleManager sharedStyleManager] defaultMonospacedFont];
	CTParagraphStyleRef style = [[LoggerTextStyleManager sharedStyleManager] defaultMonospacedStyle];
	return [LoggerTextStyleManager _sizeForString:aString constraint:aConstraint font:font style:style];
}

+(CGSize)sizeforStringWithDefaultHintFont:(NSString *)aString constraint:(CGSize)aConstraint
{
	if(IS_NULL_STRING(aString))
		return CGSizeZero;

	CTFontRef font = [[LoggerTextStyleManager sharedStyleManager] defaultHintFont];
	CTParagraphStyleRef style = [[LoggerTextStyleManager sharedStyleManager] defaultParagraphStyle];
	return [LoggerTextStyleManager _sizeForString:aString constraint:aConstraint font:font style:style];
}



-(id)init
{
	self = [super init];
	if(self)
	{
		CTTextAlignment alignment = kCTTextAlignmentLeft;
		
		//-------------------------- default font ------------------------------
		// we're to use system default helvetica to get a cover for UTF-8 chars, emoji, and many more.
		_defaultFont =  CTFontCreateWithName(CFSTR("Helvetica"),DEFAULT_FONT_SIZE, NULL);
		
		//http://stackoverflow.com/questions/3374591/ctframesettersuggestframesizewithconstraints-sometimes-returns-incorrect-size
		//  When you create an attributed string the default paragraph style has a leading
		//  of 0.0. Create a paragraph style that will set the line adjustment equal to
		//  the leading value of the font.
		CGFloat defaultLeading = CTFontGetLeading(_defaultFont) + CTFontGetDescent(_defaultFont);
		
		// CTParagraphStyleSetting only takes CTParagraphStyle related parameters do not put anything else
		CTParagraphStyleSetting dfs[] = {
			{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof (CGFloat), &defaultLeading }
			,{kCTParagraphStyleSpecifierAlignment,sizeof(CTTextAlignment),&alignment}
		};

		_defaultParagraphStyle = CTParagraphStyleCreate(dfs, sizeof(dfs) / sizeof(dfs[0]));


		//------------------------ default thread style ------------------------
		CTLineBreakMode mlb = kCTLineBreakByTruncatingMiddle;
		CTParagraphStyleSetting dths[] = {
			{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof (CGFloat), &defaultLeading }
			,{kCTParagraphStyleSpecifierAlignment,sizeof(CTTextAlignment),&alignment}
			,{kCTParagraphStyleSpecifierLineBreakMode,sizeof(CTLineBreakMode),&mlb}
		};
		
		_defaultThreadStyle = CTParagraphStyleCreate(dths, sizeof(dths) / sizeof(dths[0]));
		
		//-------------------------- tag and level font ------------------------
		// in ios, no Lucida Sans. we're going with 'Telugu Sangman MN'
		CTFontRef tlfr = CTFontCreateWithName(CFSTR("TeluguSangamMN"), DEFAULT_TAG_LEVEL_SIZE, NULL);
		
		// Create a copy of the original font with the masked trait set to the
		// desired value. If the font family does not have the appropriate style,
		// this will return NULL.
		CTFontRef btlfr = CTFontCreateCopyWithSymbolicTraits(tlfr, 0.0, NULL, kCTFontBoldTrait,kCTFontBoldTrait);
		if(btlfr == NULL)
		{
			_defaultTagAndLevelFont = tlfr;
		}
		else
		{
			_defaultTagAndLevelFont = btlfr;
			CFRelease(tlfr);
		}
		

		CGFloat tagLevelLeading = CTFontGetLeading(_defaultTagAndLevelFont) + CTFontGetDescent(_defaultTagAndLevelFont);

		CTParagraphStyleSetting tls[] = {
			{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof (CGFloat), &tagLevelLeading }
			,{kCTParagraphStyleSpecifierAlignment,sizeof(CTTextAlignment),&alignment}
		};

		_defaultTagAndLevelStyle = CTParagraphStyleCreate(tls, sizeof(tls) / sizeof(tls[0]));

		//-------------------------- file and function -------------------------
		// set the desired trait to be bold, Mask off the bold trait to indicate
		// that CTFontSymbolicTraits is the only trait desired to be modified.
		_defaultFileAndFunctionFont = _defaultTagAndLevelFont;

		CTParagraphStyleSetting ffs[] = {
			{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof (CGFloat), &tagLevelLeading }
			,{kCTParagraphStyleSpecifierAlignment,sizeof(CTTextAlignment),&alignment}
			,{kCTParagraphStyleSpecifierLineBreakMode,sizeof(CTLineBreakMode),&mlb}
		};

		_defaultFileAndFunctionStyle = CTParagraphStyleCreate(ffs, sizeof(ffs) / sizeof(ffs[0]));
		
		//-------------------------- monospaced font ---------------------------
		// this is for binary, so we're to go with cusom font
		NSString *fontPath =
			[NSString stringWithFormat:@"%@/%@"
			 ,[[NSBundle mainBundle] bundlePath]
			 ,@"NSLoggerResource.bundle/fonts/Inconsolata.ttf"];
		
		CGDataProviderRef fontProvider = CGDataProviderCreateWithFilename([fontPath UTF8String]);
		CGFontRef cgFont = CGFontCreateWithDataProvider(fontProvider);
		_defaultMonospacedFont = CTFontCreateWithGraphicsFont(cgFont,DEFAULT_MONOSPACED_SIZE,NULL,NULL);
		
		CGFloat monospacedLeading = CTFontGetLeading(_defaultMonospacedFont) + CTFontGetDescent(_defaultMonospacedFont);
		
		CTParagraphStyleSetting mfs[] = {
			{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof (CGFloat), &monospacedLeading }
			,{kCTParagraphStyleSpecifierAlignment,sizeof(CTTextAlignment),&alignment}
		};

		_defaultMonospacedStyle = CTParagraphStyleCreate(mfs, sizeof(mfs) / sizeof(mfs[0]));
		
		CGDataProviderRelease(fontProvider);
		CFRelease(cgFont);

		//------------------------------- hint font ----------------------------
		CTFontRef hf = CTFontCreateCopyWithSymbolicTraits(_defaultFont, 0.0, NULL, kCTFontTraitItalic,kCTFontTraitItalic);
		if(hf != NULL){
			_defaultHintFont = hf;
		}else{
			_defaultHintFont = _defaultFont;
		}
		
	}
	return self;
}
@end
