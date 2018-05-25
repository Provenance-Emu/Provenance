/*
 * NSLoggerMacClientTestAppDelegate.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
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
#import "NSLoggerMacClientTestAppDelegate.h"
#import "LoggerClient.h"

#define TEST_BONJOUR_SETUP		0
#define TEST_CONSOLE_LOGGING	0
#define TEST_FILE_BUFFERING		0
#define TEST_DIRECT_CONNECTION	0
#define LOGGING_HOST			CFSTR("127.0.0.1")
#define LOGGING_PORT			50007

@implementation NSLoggerMacClientTestAppDelegate

@synthesize window;

- (void)awakeFromNib
{
	tagsArray = [[NSArray arrayWithObjects:@"main",@"audio",@"video",@"network",@"database",nil] retain];

#if TEST_CONSOLE_LOGGING
	LoggerSetOptions(NULL, kLoggerOption_LogToConsole);
#else
	LoggerSetOptions(NULL, kLoggerOption_BrowseBonjour | kLoggerOption_CaptureSystemConsole | kLoggerOption_BufferLogsUntilConnection);
 #if TEST_FILE_BUFFERING
	LoggerSetBufferFile(NULL, CFSTR("/tmp/NSLoggerTempData_MacOSX.rawnsloggerdata"));
 #endif
 #if TEST_DIRECT_CONNECTION
	LoggerSetViewerHost(NULL, LOGGING_HOST, LOGGING_PORT);
 #endif
#endif
#if TEST_BONJOUR_SETUP
	// test restricting bonjour lookup for a specific machine
	LoggerSetupBonjour(NULL, NULL, CFSTR("MyOwnComputerOny"));
#endif
}

- (void)windowWillClose:(NSNotification *)notification
{
	LoggerStop(NULL);
	[NSApp terminate:self];
}

- (IBAction)startStopLogging:(id)sender
{
	if (sendTimer == nil)
	{
		counter = 0;
		imagesCounter = 0;
		sendTimer = [[NSTimer scheduledTimerWithTimeInterval:0.20f
													  target:self
													selector:@selector(sendTimerFired:)
													userInfo:nil
													 repeats:YES] retain];
		[startStopButton setTitle:@"Stop Sending Logs"];
	}
	else
	{
		[sendTimer invalidate];
		[sendTimer release];
		sendTimer = nil;
		[startStopButton setTitle:@"Start Sending Logs"];
	}
}

- (void)sendTimerFired:(NSTimer *)timer
{
	static int image = 1;
	int phase = arc4random() % 10;
	if (phase != 1 && phase != 5)
	{
		NSMutableString *s = [NSMutableString stringWithFormat:@"test log message %d - Random characters follow: ", counter++];
		int nadd = 1 + arc4random() % 150;
		for (int i = 0; i < nadd; i++)
			[s appendFormat:@"%c", 32 + (arc4random() % 27)];
		int what = (arc4random() % 5);
		if (what == 0)
			LogMessage([tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, @"%@", s);
		else if (what == 1)
		{
			// log full origin info
			LogMessageF(__FILE__, __LINE__, __FUNCTION__, [tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, @"%@", s);
		}
		else if (what == 2)
		{
			// just log __FUNCTION__
			LogMessageF(NULL, 0, __FUNCTION__, [tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, @"%@", s);
		}
		else if (what == 3)
		{
			NSLog(@"Some message to NSLog %d", (int)arc4random());
		}
		else
		{
			// just log __FILE__ __LINE__
			LogMessageF(__FILE__, __LINE__, NULL, [tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, @"%@", s);
		}
	}
	else if (phase == 1)
	{
		unsigned char *buf = (unsigned char *)malloc(1024);
		int n = 1 + arc4random() % 1024;
		for (int i = 0; i < n; i++)
			buf[i] = (unsigned char)arc4random();
		NSData *d = [[NSData alloc] initWithBytesNoCopy:buf length:n];
		LogData(@"main", 1, d);
		[d release];
	}
	else if (phase == 5)
	{
		// nearly same code as iPhone example, could certainly be made shorter
		imagesCounter++;
		NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(100,100)];
		[img lockFocusFlipped:NO];
		CGContextRef ctx = (CGContextRef)([[NSGraphicsContext currentContext] graphicsPort]);
		CGFloat r = (CGFloat)(arc4random() % 256) / 255.0f;
		CGFloat g = (CGFloat)(arc4random() % 256) / 255.0f;
		CGFloat b = (CGFloat)(arc4random() % 256) / 255.0f;
		CGColorRef fillColor = CGColorCreateGenericRGB(r, g, b, 1.0f);
		CGContextSetFillColorWithColor(ctx, fillColor);
		CGColorRelease(fillColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, 100, 100));
		CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
		CGContextSelectFont(ctx, "Helvetica", 14.0, kCGEncodingMacRoman);
		CGColorRef white = CGColorCreateGenericGray(1.0f, 1.0f);
		CGContextSetShadowWithColor(ctx, CGSizeMake(1, 1), 1.0f, white);
		CGColorRelease(white);
		CGContextSetTextDrawingMode(ctx, kCGTextFill);
		CGColorRef black = CGColorCreateGenericGray(0.0f, 1.0f);
		CGContextSetFillColorWithColor(ctx, black);
		CGColorRelease(black);
		char buf[64];
		sprintf(buf, "Log Image %d", image++);
		CGContextShowTextAtPoint(ctx, 0, 50, buf, strlen(buf));
		[img unlockFocus];
		
		NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
		NSData *bitmapData = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
		[bitmapRep release];
		[img release];

		LogImageData(@"image", 0, 100, 100, bitmapData);
	}
	if (phase == 0)
	{
		[NSThread detachNewThreadSelector:@selector(sendLogFromAnotherThread:)
								 toTarget:self
							   withObject:[NSNumber numberWithInteger:counter++]];
	}
	[messagesCountLabel setStringValue:[NSString stringWithFormat:@"%d", counter]];
	[imagesCountLabel setStringValue:[NSString stringWithFormat:@"%d", imagesCounter]];
}

- (void)sendLogFromAnotherThread:(NSNumber *)counterNum
{
	LogMessage(@"transfers", 0, @"message %d from standalone thread", (int)[counterNum integerValue]);
}

@end
