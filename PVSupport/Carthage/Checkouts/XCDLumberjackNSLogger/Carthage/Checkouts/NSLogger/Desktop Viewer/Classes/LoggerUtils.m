/*
 * LoggerUtils.m
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
#import "LoggerUtils.h"

NSString *StringWithTimeDelta(struct timeval *td)
{
	if (td->tv_sec)
	{
		int hrs,mn,s,ms;
		hrs = td->tv_sec / 3600;
		mn = (td->tv_sec % 3600) / 60;
		s = td->tv_sec % 60;
		ms = td->tv_usec / 1000;
		if (hrs != 0)
			return [NSString stringWithFormat:@"+%dh %dmn %d.%03ds", hrs, mn, s, ms];
		if (mn != 0)
			return [NSString stringWithFormat:@"+%dmn %d.%03ds", mn, s, ms];
		if (s != 0)
		{
			if (ms != 0)
				return [NSString stringWithFormat:@"+%d.%03ds", s, ms];
			return [NSString stringWithFormat:@"+%ds", s];
		}
	}
	if (td->tv_usec == 0)
		return @"";

	// millisecond resolution
	if (td->tv_usec > 10 || (td->tv_usec % 1000) == 0)
		return [NSString stringWithFormat:@"+%dms", td->tv_usec / 1000];

	// microsecond resolution
	return [NSString stringWithFormat:@"+%d.%03dms", td->tv_usec / 1000, td->tv_usec % 1000];
}

CGColorRef CreateCGColorFromNSColor(NSColor * color)
{
    NSColor * rgbColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    CGFloat r, g, b, a;
    [rgbColor getRed:&r green:&g blue:&b alpha:&a];
    return CGColorCreateGenericRGB(r, g, b, a);
}

void MakeRoundedPath(CGContextRef ctx, CGRect r, CGFloat radius)
{
	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, CGRectGetMinX(r), CGRectGetMidY(r));
	CGContextAddArcToPoint(ctx, CGRectGetMinX(r), CGRectGetMinY(r), CGRectGetMidX(r), CGRectGetMinY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(r), CGRectGetMinY(r), CGRectGetMaxX(r), CGRectGetMidY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(r), CGRectGetMaxY(r), CGRectGetMidX(r), CGRectGetMaxY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMinX(r), CGRectGetMaxY(r), CGRectGetMinX(r), CGRectGetMidY(r), radius);
	CGContextClosePath(ctx);
}

static void OpenFileInXcodeWithKZLinkedConsole(NSString *fileName, NSUInteger lineNumber, void (^completionHandler)(NSString *filePath))
{
	static NSMutableSet *pendingFiles;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		pendingFiles = [NSMutableSet new];
	});
	
	NSDistributedNotificationCenter *distributedCenter = [NSDistributedNotificationCenter defaultCenter];
	[distributedCenter addObserverForName:@"pl.pixle.KZLinkedConsole.DidOpenFile" object:nil queue:nil usingBlock:^(NSNotification *notification) {
		[pendingFiles removeObject:fileName];
		completionHandler([notification.object description]);
	}];
	
	[pendingFiles addObject:fileName];
	[distributedCenter postNotificationName:@"pl.pixle.KZLinkedConsole.OpenFile" object:fileName userInfo:@{ @"Line": @(lineNumber) } deliverImmediately:YES];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if ([pendingFiles containsObject:fileName])
		{
			[pendingFiles removeObject:fileName];
			completionHandler(nil);
		}
	});
}

void OpenFileInXcode(NSString *fileName, NSUInteger lineNumber)
{
	// Try first with the KZLinkedConsole plugin because `xed --line` is terribly broken, see http://openradar.appspot.com/19529585
	OpenFileInXcodeWithKZLinkedConsole(fileName, lineNumber, ^(NSString *filePath) {
		if (filePath)
		{
			// KZLinkedConsole is installed and opened the file
			[[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dt.Xcode"].firstObject activateWithOptions:NSApplicationActivateIgnoringOtherApps];
		}
		else
		{
			// KZLinkedConsole is not installed or failed to open the file, fallback to xed
			@try
			{
				[NSTask launchedTaskWithLaunchPath:@"/usr/bin/xcrun" arguments:@[ @"xed", @"-l", @(lineNumber).description, fileName ]];
			}
			@catch (NSException *exception)
			{
				NSLog(@"Could not run xed: %@", exception);
			}
		}
	});
}
