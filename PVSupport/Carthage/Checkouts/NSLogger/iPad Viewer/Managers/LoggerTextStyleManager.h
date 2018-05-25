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


#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import "LoggerConstModel.h"
#import "LoggerConstView.h"

@interface LoggerTextStyleManager : NSObject
+(instancetype)sharedStyleManager;

/*
 * https://developer.apple.com/library/mac/#documentation/Carbon/Reference/CoreText_Framework_Ref/_index.html
 *
 * Multicore Considerations: All individual functions in Core Text are thread safe.
 * Font objects (CTFont, CTFontDescriptor, and associated objects) can be used 
 * simultaneously by multiple operations, work queues, or threads. However, the
 * layout objects (CTTypesetter, CTFramesetter, CTRun, CTLine, CTFrame, and
 * associated objects) should be used in a single operation, work queue, or thread.
 *
 */
@property (nonatomic, readonly) __attribute__((NSObject)) CTFontRef				defaultFont;
@property (nonatomic, readonly) __attribute__((NSObject)) CTFontRef				defaultTagAndLevelFont;
@property (nonatomic, readonly) __attribute__((NSObject)) CTFontRef				defaultFileAndFunctionFont;
@property (nonatomic, readonly) __attribute__((NSObject)) CTFontRef				defaultMonospacedFont;
@property (nonatomic, readonly) __attribute__((NSObject)) CTFontRef				defaultHintFont;

/* 
 * CTParagraphStyleCreate
 *
 * Using this function is the easiest and most efficient way to create a 
 * paragraph style. Paragraph styles should be kept immutable for totally 
 * lock-free operation.
 *
 */
@property (nonatomic, readonly) __attribute__((NSObject)) CTParagraphStyleRef	defaultParagraphStyle;
@property (nonatomic, readonly) __attribute__((NSObject)) CTParagraphStyleRef	defaultThreadStyle;
@property (nonatomic, readonly) __attribute__((NSObject)) CTParagraphStyleRef	defaultTagAndLevelStyle;
@property (nonatomic, readonly) __attribute__((NSObject)) CTParagraphStyleRef	defaultFileAndFunctionStyle;
@property (nonatomic, readonly) __attribute__((NSObject)) CTParagraphStyleRef	defaultMonospacedStyle;

+(CGSize)sizeForStringWithDefaultFont:(NSString *)aString constraint:(CGSize)aConstraint;
+(CGSize)sizeForStringWithDefaultTagAndLevelFont:(NSString *)aString constraint:(CGSize)aConstraint;
+(CGSize)sizeForStringWithDefaultFileAndFunctionFont:(NSString *)aString constraint:(CGSize)aConstraint;
+(CGSize)sizeForStringWithDefaultMonospacedFont:(NSString *)aString constraint:(CGSize)aConstraint;
+(CGSize)sizeforStringWithDefaultHintFont:(NSString *)aString constraint:(CGSize)aConstraint;
@end
