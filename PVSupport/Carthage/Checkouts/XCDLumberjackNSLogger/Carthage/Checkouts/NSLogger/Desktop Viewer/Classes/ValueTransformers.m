/*
 * ValueTransformers.m
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
#import "ValueTransformers.h"

@implementation CanFilterSelectionBeDeletedValueTransformer

+ (void)load
{
	CanFilterSelectionBeDeletedValueTransformer *t = [[self alloc] init];
	[NSValueTransformer setValueTransformer:t forName:@"CanDeleteFilterSelection"];
	[t release];
}

+ (Class)transformedValueClass
{
	return [NSNumber class];
}

- (id)transformedValue:(id)value
{
	// check if the All Logs entry (the only one with UID 1) is in selection
	BOOL result = NO;
	NSArray *selection = (NSArray *)value;
	if ([selection count])
	{
		// the All Logs entry always has UID 1
		result = (([selection count] > 1) ||
				  ([[[selection lastObject] objectForKey:@"uid"] integerValue] != 1));
	}
	return [NSNumber numberWithBool:result];
}

@end

@implementation FilterColumnHeaderValueTransformer

+ (void)load
{
	FilterColumnHeaderValueTransformer *t = [[self alloc] init];
	[NSValueTransformer setValueTransformer:t forName:@"FilterColumnHeader"];
	[t release];
}

+ (Class)transformedValueClass
{
	return [NSString class];
}

- (id)transformedValue:(id)value
{
	return [NSString stringWithFormat:NSLocalizedString(@"Filters for “%@”", @""), value];
}
@end

@implementation BonjourServiceNameValueTransformer

+ (void)load
{
	BonjourServiceNameValueTransformer *t = [[self alloc] init];
	[NSValueTransformer setValueTransformer:t forName:@"TrimmedBonjourServiceName"];
	[t release];
}

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
